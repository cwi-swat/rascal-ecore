package lang.ecore;

import java.io.IOException;
import java.io.PrintWriter;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.stream.Collectors;

import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.Platform;
import org.eclipse.emf.common.command.Command;
import org.eclipse.emf.common.command.CompoundCommand;
import org.eclipse.emf.common.util.BasicEList;
import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EAttribute;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EFactory;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.eclipse.emf.edit.command.AddCommand;
import org.eclipse.emf.edit.command.DeleteCommand;
import org.eclipse.emf.edit.command.RemoveCommand;
import org.eclipse.emf.edit.command.SetCommand;
import org.eclipse.emf.edit.domain.EditingDomain;
import org.rascalmpl.debug.IRascalMonitor;
import org.rascalmpl.eclipse.nature.ProjectEvaluatorFactory;
import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.IEvaluator;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.NullRascalMonitor;
import org.rascalmpl.interpreter.TypeReifier;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.RascalTypeFactory;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.uri.URIResourceResolver;
import org.rascalmpl.uri.URIUtil;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.IAnnotatable;
import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IDateTime;
import io.usethesource.vallang.IExternalValue;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.INode;
import io.usethesource.vallang.IRational;
import io.usethesource.vallang.IReal;
import io.usethesource.vallang.ISet;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.IWithKeywordParameters;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;
import io.usethesource.vallang.visitors.IValueVisitor;
import io.usethesource.vallang.visitors.NullVisitor;

/**
 * This class provide a load method to get an ADT from an EMF model
 */
public class IO {
	private final IValueFactory vf;
	private final TypeReifier tr;
	private static final TypeFactory tf = TypeFactory.getInstance();
	
	@SuppressWarnings("unused")
	private IEvaluatorContext ctx;
	
	/*
	 * Public Rascal interface
	 */
	
	public IO(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap()
			.put("*", new XMIResourceFactoryImpl());
	}
	
	public IMap patchOnDisk(ITuple patch, ISourceLocation uri, IEvaluatorContext ctx) {
		this.ctx = ctx;
		
		Map<IConstructor, EObject> cache = new HashMap<>();
		Set<IConstructor> newIds = new HashSet<>();

		EObject root = loadModel(uri);

		EObject newRoot = patch(root, patch, cache, newIds);
		
		saveModel(newRoot, uri);
		
		return rekeyMap(cache, newIds);
	}
	
	
	public IValue load(IValue reifiedType, ISourceLocation uri, IEvaluatorContext ctx) {
		this.ctx = ctx;

		TypeStore ts = new TypeStore(); // start afresh

		Type rt = tr.valueToType((IConstructor) reifiedType, ts);

		// Cheat: build Ref  here (assuming Id is in there)
		Type refType = tf.abstractDataType(ts, "Ref", tf.parameterType("T"));
		tf.constructor(ts, refType, "ref", ts.lookupAbstractDataType("Id"), "uid");
		tf.constructor(ts, refType, "null");
		
		EObject root = loadModel(uri);
		
		return obj2value(root, rt, vf, ts);
	}
	
	public void save(INode model, ISourceLocation pkgUri, ISourceLocation uri) {
		EPackage pkg = EPackage.Registry.INSTANCE.getEPackage(pkgUri.getURI().toString());

		ModelBuilder builder = new ModelBuilder(pkg);
		EObject root = (EObject) model.accept(builder);

		// FIXME: Actually, when encountering a ref(id(_)) in the tree,
		// it should be possible to get the type it refers to,
		// create a placeholder object for it, and later fill the
		// structural features when encountering the real object.
		// Thus, getting rid of the second traversal.
		
		CrossRefResolver resolver = new CrossRefResolver(builder.getUids());
		model.accept(resolver);
		
		saveModel(root, uri);
	}

	/*
	 * For calling rascal from the EMF side
	 */
	
	
	private static Map<String, Evaluator> bundleEvals = new HashMap<>();

	// The signature of the `function` should be
	// Patch (Loader[&T] load);

	public static CompoundCommand runRascal(String bundleId, EditingDomain domain, EObject obj, String module, String function) {
		if (!(bundleEvals.containsKey(bundleId))) {
			GlobalEnvironment heap = new GlobalEnvironment();
		    Evaluator eval = new Evaluator(ValueFactoryFactory.getValueFactory(), new PrintWriter(System.err), new PrintWriter(System.out), 
		    		new ModuleEnvironment("$emfbridge$", heap), heap);
		    ProjectEvaluatorFactory.getInstance().initializeBundleEvaluator(Platform.getBundle(bundleId), eval);
			bundleEvals.put(bundleId, eval);
		}
		Evaluator eval = bundleEvals.get(bundleId);
		IRascalMonitor mon = new NullRascalMonitor();
		eval.doImport(mon, module);
		ITuple patch = (ITuple) eval.call(function, new IValue[] { new ObtainModelClosure(obj, eval) });
		
		return patch(domain, obj, patch);
	}
	
	@SuppressWarnings("unchecked")
	private static CompoundCommand patch(EditingDomain domain, EObject root, ITuple patch) {
		EPackage pkg = root.eClass().getEPackage();
		EFactory fact = pkg.getEFactoryInstance();
		List<Command> cmds = new ArrayList<>();
		Map<IConstructor, EObject> cache = new HashMap<>();
		
		for (IValue v: (IList)patch.get(1)) {
			ITuple idEdit = (ITuple)v;
			IConstructor id = (IConstructor) idEdit.get(0);
			IConstructor edit = (IConstructor) idEdit.get(1);
			if (edit.getName().equals("create")) {
				// TODO: we actually create the new objects during patch, not while doing the commands...
				String clsName = toFirstUpperCase(((IString)edit.get("class")).getValue());
				EClass eCls = (EClass) pkg.getEClassifier(clsName);
				EObject obj = fact.create(eCls);
				cache.put(id, obj);
			}
			else {
				EObject obj = lookup(root, id, cache);
				String fieldName = ((IString)edit.get("field")).getValue();
				EStructuralFeature field = obj.eClass().getEStructuralFeature(fieldName);

				if (edit.getName().equals("destroy")) {
					cmds.add(DeleteCommand.create(domain, obj));
				}
				else if (edit.getName().equals("put")) {
					Object val = value2obj(edit.get("val"), root, cache);
					cmds.add(SetCommand.create(domain, obj, field, val));
				}
				else if (edit.getName().equals("unset")) {
					cmds.add(SetCommand.create(domain, obj, field, null));
				}
				else {
					List<Object> lst = (List<Object>)obj.eGet(field);
					int pos = ((IInteger)edit.get("pos")).intValue();
					
					if (edit.getName().equals("ins")) {
						cmds.add(AddCommand.create(domain, obj, field, value2obj(edit.get("val"), root, cache), pos));
					}
					else if (edit.getName().equals("del")) {
						cmds.add(RemoveCommand.create(domain, obj, field, lst.get(pos)));
					}
					else {
						throw RuntimeExceptionFactory.illegalArgument(edit, null, null);
					}
				}
			}
		}
		return new CompoundCommand(cmds);
	}
	
	private static class ObtainModelClosure extends Result<ICallableValue> implements ICallableValue{
		
		private IEvaluator<Result<IValue>> eval;
		private EObject model;
		
		private static final Type myType;
		
		static {
			RascalTypeFactory rtf = RascalTypeFactory.getInstance();
			Type param = tf.parameterType("T", tf.nodeType());
			myType = rtf.functionType(param, tf.tupleType(rtf.reifiedType(param)), tf.tupleEmpty());
		}

		public ObtainModelClosure(EObject model, IEvaluator<Result<IValue>> eval) {
			super(myType, null, eval);
			this.value = this;
			this.model = model;
			this.eval = eval;
		}
		
		@Override
		public boolean mayHaveKeywordParameters() {
			return false;
		}
		
		@Override
		public boolean isEqual(IValue arg0) {
			return false;
		}
		
		@Override
		public boolean isAnnotatable() {
			return false;
		}
		
		@Override
		public IWithKeywordParameters<? extends IValue> asWithKeywordParameters() {
			return null;
		}
		
		@Override
		public IAnnotatable<? extends IValue> asAnnotatable() {
			return null;
		}
		
		@Override
		public <T, E extends Throwable> T accept(IValueVisitor<T, E> visit) throws E {
			return visit.visitExternal(this);
		}
		
		@Override
		public Type getType() {
			return myType;
		}
		
		@Override
		public IConstructor encodeAsConstructor() {
			return null;
		}
		
		@Override
		public boolean isStatic() {
			return false;
		}
		
		@Override
		public boolean hasVarArgs() {
			return false;
		}
		
		@Override
		public boolean hasKeywordArguments() {
			return false;
		}
		
		@Override
		public IEvaluator<Result<IValue>> getEval() {
			return eval;
		}
		
		@Override
		public int getArity() {
			return 1;
		}
		
		@Override
		public ICallableValue cloneInto(Environment arg0) {
			return null;
		}
		
		@Override
		public Result<IValue> call(IRascalMonitor arg0, Type[] arg1, IValue[] arg2, Map<String, IValue> arg3) {
			return call(arg1, arg2, arg3);
		}
		
		@Override
		public Result<IValue> call(Type[] arg0, IValue[] args, Map<String, IValue> kws) {
			IValue reifiedType = args[0];
			TypeStore ts = new TypeStore(); // start afresh

			IValueFactory values = getEval().getValueFactory();
			Type rt = new TypeReifier(values).valueToType((IConstructor) reifiedType, ts);

			// TODO: this duplicates load...
			Type refType = tf.abstractDataType(ts, "Ref", tf.parameterType("T"));
			tf.constructor(ts, refType, "ref", ts.lookupAbstractDataType("Id"), "uid");
			tf.constructor(ts, refType, "null");
			
			IValue val = obj2value(model, rt, values, ts);
			return ResultFactory.makeResult(rt, val, getEval());
		}

	}
	
	
	private IMap rekeyMap(Map<IConstructor, EObject> cache, Set<IConstructor> newIds) {
		IMapWriter w = vf.mapWriter();
		for (IConstructor newId: newIds) {
			URI eUri = EcoreUtil.getURI(cache.get(newId));
			try {
				java.net.URI uriId = URIUtil.create(eUri.scheme(), eUri.authority(), eUri.path(), eUri.query(), eUri.fragment());
				w.put((IInteger)newId.get("n"), vf.sourceLocation(uriId));
			} catch (URISyntaxException e) {
				throw RuntimeExceptionFactory.malformedURI(eUri.toString(), null, null);
			}
		}
		return w.done();
	}
	
	private void saveModel(EObject model, ISourceLocation uri) {
		ResourceSet rs = new ResourceSetImpl();
		IResource resource = URIResourceResolver.getResource(uri);
		java.net.URI eclipseURI = resource.getRawLocationURI();

		Resource res = rs.createResource(URI.createURI(eclipseURI.toString()));
		res.getContents().add(model);
		try {
			res.save(Collections.EMPTY_MAP);
		} catch (IOException e) {
			throw RuntimeExceptionFactory.io(vf.string(e.getMessage()), null, null);
		}
	}
	
	@SuppressWarnings("unchecked")
	/*
	 *  patch object root according to `patch`.
	 *  fill cache (mapping ids to EObjects) and newIds in the process
	 *  return the new root
	 */
	private static EObject patch(EObject root, ITuple patch, Map<IConstructor, EObject> cache, Set<IConstructor> newIds) {
		EPackage pkg = root.eClass().getEPackage();
		EFactory fact = pkg.getEFactoryInstance();
		
		for (IValue v: (IList)patch.get(1)) {
			ITuple idEdit = (ITuple)v;
			IConstructor id = (IConstructor) idEdit.get(0);
			IConstructor edit = (IConstructor) idEdit.get(1);
			if (edit.getName().equals("create")) {
				String clsName = toFirstUpperCase(((IString)edit.get("class")).getValue());
				EClass eCls = (EClass) pkg.getEClassifier(clsName);
				EObject obj = fact.create(eCls);
				cache.put(id, obj);
				newIds.add(id);
			}
			else {
				EObject obj = lookup(root, id, cache);
				String fieldName = ((IString)edit.get("field")).getValue();
				EStructuralFeature field = obj.eClass().getEStructuralFeature(fieldName);

				if (edit.getName().equals("destroy")) {
					// this deletes obj from all containers and references to it
					// but that's ok, because deletes are always at the end. 
					EcoreUtil.delete(obj);
				}
				else if (edit.getName().equals("put")) {
					Object val = value2obj(edit.get("val"), root, cache);
					obj.eSet(field, val);
				}
				else if (edit.getName().equals("unset")) {
					obj.eUnset(field);
				}
				else {
					List<Object> lst = (List<Object>)obj.eGet(field);
					int pos = ((IInteger)edit.get("pos")).intValue();
					
					if (edit.getName().equals("ins")) {
						lst.add(pos, value2obj(edit.get("val"), root, cache));
					}
					else if (edit.getName().equals("del")) {
						lst.remove(pos);
					}
					else {
						throw RuntimeExceptionFactory.illegalArgument(edit, null, null);
					}
				}
			}
		}
		
		return lookup(root, (IConstructor)patch.get(0), cache);
	}

	private static Object value2obj(IValue v, EObject root, Map<IConstructor, EObject> cache) {
		// todo: should check against actual Id type.
		Type type = v.getType();
		if (type.isAbstractData() && ((IConstructor)v).getName().equals("id")) {
			return lookup(root, (IConstructor)v, cache);
		}
		if (type.isInteger()) {
			return ((IInteger)v).intValue();
		}
		if (type.isString()) {
			return ((IString)v).getValue();
		}
		if (type.isReal()) {
			return ((IReal)v).floatValue();
		}
		if (type.isBool()) {
			return ((IBool)v).getValue();
		}
		throw RuntimeExceptionFactory.illegalArgument(v, null, null);
	}
	
	private static EObject lookup(EObject root, IConstructor id, Map<IConstructor, EObject> cache) {
		if (cache.containsKey(id)) {
			return cache.get(id);
		}
		// created things always are in the cache, so we can assume
		// loc ids in this case.
		String fragment = ((ISourceLocation)id.get(0)).getFragment();
		EObject obj = null;
		if (fragment.equals("/")) { // not sure why it has to be this way.
			obj = root;
		}
		else {
			// same here.
			obj = EcoreUtil.getEObject(root, fragment.substring(2));
		}
		cache.put(id, obj);
		return obj;
	}
	
	
	private static EObject loadModel(ISourceLocation uri) {
		IResource resource = URIResourceResolver.getResource(uri);
		java.net.URI eclipseURI = resource.getRawLocationURI();

		ResourceSet rs = new ResourceSetImpl();
		Resource res = rs.getResource(URI.createURI(eclipseURI.toString()), true);
		return res.getContents().get(0);
	}


	private static class ModelBuilder implements IValueVisitor<Object, RuntimeException> {
		private EPackage pkg;
		private Map<IValue, EObject> uids = new HashMap<>();

		public ModelBuilder(EPackage pkg) {
			this.pkg  = pkg;
		}

		public Map<IValue, EObject> getUids() {
			return uids;
		}
		
		@Override
		public Object visitConstructor(IConstructor o) throws RuntimeException {
			String clsName = toFirstUpperCase(o.getName());
			EClass eCls = (EClass) pkg.getEClassifier(clsName);
			
			if (eCls != null) { // Create corresponding concept
				EFactory fact = pkg.getEFactoryInstance();
				EObject newObj = fact.create(eCls);
				IWithKeywordParameters<? extends IConstructor> c = o.asWithKeywordParameters();
				
				if (c.hasParameter("uid")) {
					IConstructor cUid = (IConstructor) c.getParameter("uid");
					ISourceLocation uid = (ISourceLocation) cUid.get(0);
					uids.put(uid, newObj);
				}
				
				int i = 0;
				for (IValue v : o.getChildren()) {
					String fieldName = o.getChildrenTypes().getFieldName(i);
					EStructuralFeature toSet = eCls.getEStructuralFeature(fieldName);
					Object newVal = v.accept(this);
					newObj.eSet(toSet, newVal);
					i++;
				}
				
				return newObj;
			}
			
			// Don't handle Ref[T] for now, they'll be resolved later
			
			return null;
		}
		
		@Override
		public Object visitNode(INode o) throws RuntimeException {
			o.forEach(val -> val.accept(this));
			return null;
		}
		
		@Override
		public Object visitList(IList o) throws RuntimeException {
			EList<Object> l = new BasicEList<>();
			o.forEach(e ->
				l.add(e.accept(this))
			);
			return l;
		}
		
		@Override
		public Object visitString(IString o) throws RuntimeException {
			return o.getValue();
		}

		@Override
		public Object visitBoolean(IBool o) throws RuntimeException {
			return o.getValue();
		}

		@Override
		public Object visitDateTime(IDateTime o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitExternal(IExternalValue o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitInteger(IInteger o) throws RuntimeException {
			return o.intValue();
		}

		@Override
		public Object visitListRelation(IList o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitMap(IMap o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitRational(IRational o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitReal(IReal o) throws RuntimeException {
			return o.floatValue();
		}

		@Override
		public Object visitRelation(ISet o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitSet(ISet o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitSourceLocation(ISourceLocation o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}

		@Override
		public Object visitTuple(ITuple o) throws RuntimeException {
			throw new UnsupportedOperationException();
		}
		
	}

	private static class CrossRefResolver extends NullVisitor<Void, RuntimeException> {
		private Map<IValue, EObject> uids;

		public CrossRefResolver(Map<IValue, EObject> uids) {
			this.uids = uids;
		}
		
		@Override
		public Void visitConstructor(IConstructor o) throws RuntimeException {
			IWithKeywordParameters<? extends IConstructor> c = o.asWithKeywordParameters();
			
			if (c.hasParameter("uid")) {
				IConstructor cUid = (IConstructor) c.getParameter("uid");
				ISourceLocation uid = (ISourceLocation) cUid.get(0);
				EObject me = uids.get(uid);
				
				int i = 0;
				for (IValue child : o.getChildren()) {
					String fieldName = o.getChildrenTypes().getFieldName(i);
					EStructuralFeature toSet = me.eClass().getEStructuralFeature(fieldName);
					if (child instanceof IConstructor) {
						IConstructor childCons = (IConstructor) child;
						if (isRef(childCons)) {
							IConstructor id = (IConstructor) childCons.get(0);
							ISourceLocation refUid = (ISourceLocation) id.get(0);
							EObject resolved = lookup(refUid);
							me.eSet(toSet, resolved);
						}
					}
					
					child.accept(this);
					i++;
				}
			}

			return null;
		}

		private boolean isRef(IConstructor o) {
			return "ref".equals(o.getName()) && "Ref".equals(o.getType().getName());
		}

		private EObject lookup(ISourceLocation uid) {
			return uids.get(uid);
		}
		
		@Override
		public Void visitNode(INode o) throws RuntimeException {
			o.forEach(val -> val.accept(this));
			return null;
		}
		
		@Override
		public Void visitList(IList o) throws RuntimeException {
			o.forEach(e -> e.accept(this));
			return null;
		}
	}

	
	/**
	 * Build ADT while visiting EObject content
	 */
	private static IValue obj2value(Object obj, Type type, IValueFactory vf, TypeStore ts) {
		//ctx.getStdErr().println("Visiting object " + obj + " (" + type + ")");

		if (obj instanceof EObject) {
			EObject eObj = (EObject) obj;
			EClass eCls = eObj.eClass();

			// FIXME: Assuming that there's a unique constructor with the EClass' name
			Type t = ts.lookupConstructor(type, eCls.getName()).iterator().next();
			
			List<IValue> fields = new ArrayList<>();
			for (int i = 0; i < t.getArity(); i++) {
				// Rascal side
				String fieldName = t.getFieldName(i);
				Type fieldType = t.getFieldType(i);
				
				// EMF side
				EStructuralFeature feature = eCls.getEStructuralFeature(fieldName);
				Object featureValue = eObj.eGet(feature);
				
				//System.out.println("For " + fieldName + ": found " + feature);

				if (feature instanceof EReference) {
					// Then featureValue is an EObject
					EReference ref = (EReference) feature;
					if (ref.isContainment()) {
						fields.add(visitContainmentRef(ref, featureValue, fieldType, vf, ts));
					}
					else {
						fields.add(visitReference(ref, featureValue, fieldType, vf, ts));
					}
				}
				else if (feature instanceof EAttribute) {
					// Then featureValue is a primitive type
					EAttribute att = (EAttribute) feature;
					fields.add(visitAttribute(att, featureValue, fieldType, vf, ts));
				}
				else {
					throw RuntimeExceptionFactory.illegalArgument(vf.string(feature.toString()), null, null);
				}
			}
			
			Map<String,IValue> keywords = new HashMap<>();
			Map<String, Type> kws = ts.getKeywordParameters(t);
			for (Entry<String, Type> e : kws.entrySet()) {
				// Rascal side
				String fieldName = e.getKey();
				Type fieldType = e.getValue();

				if (fieldName.equals("uid") || fieldName.equals("src")) {
					continue;
				}
				
				// EMF side
				EStructuralFeature feature = eCls.getEStructuralFeature(fieldName);
				
				//System.out.println("Looking for " + fieldName + " in " + eCls.getName());
				Object featureValue = eObj.eGet(feature);
				
				if (!eObj.eIsSet(feature)) {
					continue;
				}
				
				//System.out.println("For kw " + fieldName + ": found " + feature);

				if (feature instanceof EReference) {
					// Then featureValue is an EObject
					EReference ref = (EReference) feature;
					if (ref.isContainment()) {
//						fields.add(visitContainmentRef(ref, featureValue, fieldType, ts));
						IValue x = visitContainmentRef(ref, featureValue, fieldType, vf, ts);
						if (x != null) {
							keywords.put(fieldName, x);
						}
					}
					else {
//						fields.add(visitReference(ref, featureValue, fieldType));
						IValue x = visitReference(ref, featureValue, fieldType, vf, ts);
						if (x != null) {
							keywords.put(fieldName, x);
						}
					}
				}
				else if (feature instanceof EAttribute) {
					// Then featureValue is a primitive type
					EAttribute att = (EAttribute) feature;
//					fields.add();
					IValue x = visitAttribute(att, featureValue, fieldType, vf, ts);
					if (x != null) {
						keywords.put(fieldName, x);
					}
				}
			}
			
			keywords.put("uid", getIdFor(eObj, vf, ts));
			IValue[] arr = new IValue[fields.size()];
			return vf.constructor(t, fields.toArray(arr), keywords);
		}

		return makePrimitive(obj, type, vf);
	}
	
	
	/**
	 * Returns IValue for an EAttribute
	 */
	@SuppressWarnings("unchecked")
	private static IValue visitAttribute(EStructuralFeature ref, Object refValue, Type fieldType, IValueFactory vf, TypeStore ts) {

		if (ref.isMany()) {
			List<Object> refValues = (List<Object>) refValue;
			List<IValue> values = refValues.stream().map(elem -> makePrimitive(refValue, fieldType, vf)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			IValue[] valuesArray = values.toArray(arr);

			if (ref.isUnique()) {
				if (ref.isOrdered()) {            // M & U & O = ?
					return vf.list(valuesArray);
				}
				return vf.set(valuesArray); // M & U & !O = Set[T]
			} 
			
			if (ref.isOrdered()) {            // M & !U & O = list[T]
				return vf.list(valuesArray);
			}                           
			// M & !U & !O = map[T, int]
			throw RuntimeExceptionFactory.illegalArgument(vf.string("Multiset: " + ref.toString()), null, null);
		}
		
		return makePrimitive(refValue, fieldType, vf);

	}
	
	/**
	 * Returns IValue for a containment EReference
	 */
	@SuppressWarnings("unchecked")
	private static IValue visitContainmentRef(EStructuralFeature ref, Object refValue, Type fieldType, IValueFactory vf, TypeStore ts) {
		//ctx.getStdErr().println("Visiting containment ref " + ref.getName() + " to " + refValue + " (" + fieldType + ")");

		//System.out.println("visitCont("+ref.getName()+","+refValue+","+fieldType+")");
		
		if (ref.isMany()) {
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> obj2value(elem, elemType, vf, ts)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			IValue[] valuesArray = values.toArray(arr);
			
			if (ref.isUnique()) {
				if (ref.isOrdered()) {            // M & U & O = ?
					return vf.list(values.toArray(valuesArray));
				} else {                          // M & U & !O = set[T]
					return vf.set(values.toArray(valuesArray));
				}
			} else {
				if (ref.isOrdered()) {            // M & !U & O = list[T]
					return vf.list(values.toArray(valuesArray));
				} else {                          // M & !U & !O = map[T, int]
					throw RuntimeExceptionFactory.illegalArgument(vf.string("Multiset: " + ref.toString()), null, null);
				}
			}
		} else {
			if (!ref.isRequired()) {              // !M && O = Opt[T]
				Type rt = ts.lookupAbstractDataType("Opt");
				//System.out.println("rt="+rt);
				Type t = ts.lookupConstructor(rt, "just", tf.tupleType(obj2value(refValue, fieldType, vf, ts)));
				return vf.constructor(t);
			} else {                              // !M && !O = T
				Type t = ts.lookupConstructor(fieldType, fieldType.getName(), tf.tupleType(obj2value(refValue, fieldType, vf, ts)));
				return vf.constructor(t);
			}
		}
		
	}
	
	/**
	 * Returns IValue for an EReference
	 */
	@SuppressWarnings("unchecked")
	private static IValue visitReference(EReference ref, Object refValue, Type fieldType, IValueFactory vf, TypeStore ts) {
		//ctx.getStdErr().println("Visiting reference ref " + ref.getName() + " to " + refValue + " (" + fieldType + ")");
		
		//System.out.println("visitRef("+ref.getName()+","+refValue+","+fieldType+")");
		if (ref.isMany()) {
			List<EObject> refValues = (List<EObject>) refValue;
			List<IValue> valuesToRef = refValues.stream().map(elem -> makeRefTo(elem, vf, ts)).collect(Collectors.toList());
			//ctx.getStdErr().println("The list is: " + valuesToRef);
			IValue[] arr = new IValue[valuesToRef.size()];
			IValue[] valuesArray = valuesToRef.toArray(arr);

			if (ref.isUnique()) {
				//ctx.getStdErr().println("Unique!");
				if (ref.isOrdered()) {            // M & U & O = ?
					//ctx.getStdErr().println("Ordered!");
					// why no value in the exception???
					//throw RuntimeExceptionFactory.illegalArgument(vf.string("Unique ordered: " + ref.toString()), null, null);
					return vf.list(valuesArray);
				} else {                          // M & U & !O = set[Ref[T]]
					//for (IValue x: valuesArray) {
						//ctx.getStdErr().println("The set element is: " + x);
					//}
					return vf.set(valuesArray);
				}
			} else {
				//ctx.getStdErr().println("Non-Unique!");
				if (ref.isOrdered()) {            // M & !U & O = list[Ref[T]]
					//ctx.getStdErr().println("Ordered!");
					//for (IValue x: valuesArray) {
						//ctx.getStdErr().println("The list element is: " + x);
					//}
					return vf.list(valuesArray);
				} else {                          // M & !U & !O = Map[Ref[T], int]
					//throw RuntimeExceptionFactory.illegalArgument(vf.string("Multiset: " + ref.toString()), null, null);
					return vf.list(valuesArray);
				}
			}
		} else {
			IValue x = makeRefTo((EObject) refValue, vf, ts);
			//ctx.getStdErr().println("The ref is: " + x);
			return x;
		}

	}
	
	/**
	 * Retrieve an unique id for an EObject.
	 * In our case, its URI.
	 * TODO: refactor this to be reusable in patch.
	 */
	private static IValue getIdFor(EObject obj, IValueFactory vf, TypeStore ts) {
		//ctx.getStdErr().println("Making id for " + obj);
		
		Type idType = ts.lookupAbstractDataType("Id");
		Type idCons = ts.lookupConstructor(idType, "id", tf.tupleType(tf.sourceLocationType()));
		URI eUri = EcoreUtil.getURI(obj);
		//ctx.getStdErr().println("EURI: " + eUri);
		//ctx.getStdErr().println("fragment: " + eUri.fragment());
		//Object frag = EcoreUtil.getRelativeURIFragmentPath(this.root, obj);
		//ctx.getStdErr().println("frag: " + frag);
		
		try {
			java.net.URI uriId = URIUtil.create(eUri.scheme(), eUri.authority(), eUri.path(), eUri.query(), eUri.fragment());
			return vf.constructor(idCons, vf.sourceLocation(uriId));
		} catch (URISyntaxException e) {
			throw RuntimeExceptionFactory.malformedURI(eUri.toString(), null, null);
		}
		
	}
	
	/**
	 * Return ref(id(Num)) or null() if {@link eObj} is null
	 */
	private static IValue makeRefTo(EObject eObj, IValueFactory vf, TypeStore ts) {
		//ctx.getStdErr().println("Making ref to " + eObj);
		Type genRefType = ts.lookupAbstractDataType("Ref");
		
		if (eObj == null) {
			Type nullCons = ts.lookupConstructor(genRefType, "null", tf.tupleEmpty());
			return vf.constructor(nullCons);
		}
		
		
		Type idType = ts.lookupAbstractDataType("Id");
		Type refCons = ts.lookupConstructor(genRefType,  "ref", tf.tupleType(idType));
		IValue id = getIdFor(eObj, vf, ts);
		//ctx.getStdErr().println("Id = " + id);
		return vf.constructor(refCons, id);
	}
	
	/**
	 * Returns IValue for primitive type
	 */
	private static IValue makePrimitive(Object obj, Type fieldType, IValueFactory vf) {
		if (obj == null) {
			if (fieldType.isBool()) {
				return vf.bool(false);
			}
			if (fieldType.isInteger()) {
				return vf.integer(0);
			}
			if (fieldType.isReal()) {
				return vf.real(0.0);
			}
			if (fieldType.isString()) {
				return vf.string("");
			}
			throw RuntimeExceptionFactory.illegalArgument(vf.string("null"), null, null);
		}
		
		if (obj instanceof Boolean) {
			return vf.bool((Boolean) obj);
		}
		else if (obj instanceof Byte) { // FIXME: Rascal's byte?
			return vf.integer((Byte) obj);
		}
		else if (obj instanceof Character) { // FIXME: Rascal's char?
			return vf.string(Character.toString((Character) obj));
		}
		else if (obj instanceof Double) { // FIXME: Rascal's double?
			return vf.real((Double) obj);
		}
		else if (obj instanceof Integer) {
			return vf.integer((Integer) obj);
		}
		else if (obj instanceof Long) { // FIXME: Rascal's long?
			return vf.integer((Long) obj);
		}
		else if (obj instanceof Short) { // FIXME: Rascal's short?
			return vf.integer((Short) obj);
		}
		else if (obj instanceof Float) { // FIXME: Rascal's float?
			return vf.real((Float) obj);
		}
		else if (obj instanceof String) {
			return vf.string((String) obj);
		}
		// FIXME: Enums?
		// FIXME: Datatypes?
		
		
		throw RuntimeExceptionFactory.illegalArgument(vf.string("Unsupported prim: " + obj.toString()), null, null);
	}
	
	private static String toFirstLowerCase(String s) {
		return s.substring(0, 1).toLowerCase() + s.substring(1);
	}
	
	private static String toFirstUpperCase(String s) {
		return s.substring(0, 1).toUpperCase() + s.substring(1);
	}

}
