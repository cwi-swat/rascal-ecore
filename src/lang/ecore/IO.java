package lang.ecore;

import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.stream.Collectors;

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
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.TypeReifier;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.uri.URIUtil;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IDateTime;
import io.usethesource.vallang.IExternalValue;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
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
	private final TypeFactory tf = TypeFactory.getInstance();
	private TypeStore ts;
	private IEvaluatorContext ctx;
	
	
	public IO(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap()
			.put("*", new XMIResourceFactoryImpl());
	}

	public IValue load(IValue reifiedType, ISourceLocation uri, IEvaluatorContext ctx) {
		this.ctx = ctx;
		this.ts = new TypeStore(); // start afresh

		
		Type rt = tr.valueToType((IConstructor) reifiedType, ts);

		// Cheat: build Ref here
		// (until TypeReification issue is resolved with generic ADTs)
		// data Ref[&T]
		//	  = ref(Id uid)
		//	  	  | null()
		//	  	  ;
		
		Type refType = tf.abstractDataType(ts, "Ref", tf.parameterType("T"));
		tf.constructor(ts, refType, "ref", ts.lookupAbstractDataType("Id"), "uid");
		tf.constructor(ts, refType, "null");

		if (!(uri.getScheme().equals("file") || uri.getScheme().equals("http"))) {
			throw RuntimeExceptionFactory.schemeNotSupported(uri, null, null);
		}

		EObject root = loadModel(uri.getURI().toString());
		
		return visit(root, rt, ts);
	}

	public void save(INode model, ISourceLocation pkgUri, ISourceLocation uri) {
		ResourceSet rs = new ResourceSetImpl();
		Resource res = rs.createResource(URI.createURI(uri.getURI().toString()));
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
		
		try {
			res.getContents().add(root);
			res.save(Collections.EMPTY_MAP);
		} catch (Exception e) {
			e.printStackTrace();
		}
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
			throw new UnsupportedOperationException();
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
		
		private String toFirstUpperCase(String s) {
			return s.substring(0, 1).toUpperCase() + s.substring(1);
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

	private EObject loadModel(String uri) {
		ResourceSet rs = new ResourceSetImpl();
		Resource res = rs.getResource(URI.createURI(uri), true);
		return res.getContents().get(0);
	}
	
	/**
	 * Build ADT while visiting EObject content
	 */
	private IValue visit(Object obj, Type type, TypeStore ts) {
		System.out.println("visit("+obj+","+type+")");
		if (obj instanceof EObject) {
			EObject eObj = (EObject) obj;
			EClass eCls = eObj.eClass();

			// FIXME: Assuming that there's a unique constructor with the EClass' name
			Type t = ts.lookupConstructor(type, toFirstLowerCase(eCls.getName())).iterator().next();
			Map<String, Type> kws = ts.getKeywordParameters(t);
			
			List<IValue> fields = new ArrayList<>();
			System.out.println("Fields of " + t + " = " + t.getFieldTypes());
			for (int i = 0; i < t.getArity(); i++) {
				// Rascal side
				String fieldName = t.getFieldName(i);
				Type fieldType = t.getFieldType(i);
				
				// EMF side
				EStructuralFeature feature = eCls.getEStructuralFeature(fieldName);
				Object featureValue = eObj.eGet(feature);
				
				System.out.println("For " + fieldName + ": found " + feature);

				if (feature instanceof EReference) {
					// Then featureValue is an EObject
					EReference ref = (EReference) feature;
					if (ref.isContainment()) {
						fields.add(visitContainmentRef(ref, featureValue, fieldType, ts));
					}
					else {
						fields.add(visitReference(ref, featureValue, fieldType));
					}
				}
				else if (feature instanceof EAttribute) {
					// Then featureValue is a primitive type
					EAttribute att = (EAttribute) feature;
					fields.add(visitAttribute(att, featureValue, fieldType, ts));
				}
			}
			
			Map<String,IValue> keywords = new HashMap<>();
			
			for (Entry<String, Type> e : kws.entrySet()) {
				// Rascal side
				String fieldName = e.getKey();
				Type fieldType = e.getValue();

				if (fieldName.equals("uid"))
					continue;
				
				// EMF side
				EStructuralFeature feature = eCls.getEStructuralFeature(fieldName);
				
				System.out.println("Looking for " + fieldName + " in " + eCls.getName());
				Object featureValue = eObj.eGet(feature);
				
				if (!eObj.eIsSet(feature))
					continue;
				
				System.out.println("For kw " + fieldName + ": found " + feature);

				if (feature instanceof EReference) {
					// Then featureValue is an EObject
					EReference ref = (EReference) feature;
					if (ref.isContainment()) {
//						fields.add(visitContainmentRef(ref, featureValue, fieldType, ts));
						IValue x = visitContainmentRef(ref, featureValue, fieldType, ts);
						if (x != null)
							keywords.put(fieldName, x);
					}
					else {
//						fields.add(visitReference(ref, featureValue, fieldType));
						IValue x = visitReference(ref, featureValue, fieldType);
						if (x != null)
							keywords.put(fieldName, x);
					}
				}
				else if (feature instanceof EAttribute) {
					// Then featureValue is a primitive type
					EAttribute att = (EAttribute) feature;
//					fields.add();
					IValue x = visitAttribute(att, featureValue, fieldType, ts);
					if (x != null)
						keywords.put(fieldName, x);
				}
			}
			
			keywords.put("uid", getIdFor(eObj));
			IValue[] arr = new IValue[fields.size()];
			for (IValue v : fields) {
				System.out.println("\tv="+v);
			}
//			for (IValue kw : keywords) {
//				System.out.println(\tkw="+kw");
//			}
			return vf.constructor(t, fields.toArray(arr), keywords);
		}
		else {
			return makePrimitive(obj);
		}
	}
	
	
	/**
	 * Returns IValue for an EAttribute
	 */
	@SuppressWarnings("unchecked")
	private IValue visitAttribute(EStructuralFeature ref, Object refValue, Type fieldType, TypeStore ts) {
		System.out.println("visitAttr("+ref.getName()+","+refValue+","+fieldType+")");
		if (ref.isMany()) {
			List<Object> refValues = (List<Object>) refValue;
			List<IValue> values = refValues.stream().map(elem -> makePrimitive(refValue)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			IValue[] valuesArray = values.toArray(arr);

			if (ref.isUnique()) {
				if (ref.isOrdered()) {            // M & U & O = ?
					return vf.list(valuesArray);
				} else {                          // M & U & !O = Set[T]
					return vf.set(valuesArray);
				}
			} else {
				if (ref.isOrdered()) {            // M & !U & O = list[T]
					return vf.list(valuesArray);
				} else {                          // M & !U & !O = map[T, int]
					throw RuntimeExceptionFactory.illegalArgument(vf.string(ref.toString()), null, null);
				}
			}
		} else {
				return makePrimitive(refValue);
		}

	}
	
	/**
	 * Returns IValue for a containment EReference
	 */
	@SuppressWarnings("unchecked")
	private IValue visitContainmentRef(EStructuralFeature ref, Object refValue, Type fieldType, TypeStore ts) {
		System.out.println("visitCont("+ref.getName()+","+refValue+","+fieldType+")");
		if (ref.isMany()) {
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> visit(elem, elemType, ts)).collect(Collectors.toList());
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
					throw RuntimeExceptionFactory.illegalArgument(vf.string(ref.toString()), null, null);
				}
			}
		} else {
			if (!ref.isRequired()) {              // !M && O = Opt[T]
				Type rt = ts.lookupAbstractDataType("Opt");
				System.out.println("rt="+rt);
				Type t = ts.lookupConstructor(rt, "just", tf.tupleType(visit(refValue, fieldType, ts)));
				return vf.constructor(t);
			} else {                              // !M && !O = T
				Type t = ts.lookupConstructor(fieldType, toFirstLowerCase(fieldType.getName()), tf.tupleType(visit(refValue, fieldType, ts)));
				return vf.constructor(t);
			}
		}
		
	}
	
	/**
	 * Returns IValue for an EReference
	 */
	@SuppressWarnings("unchecked")
	private IValue visitReference(EReference ref, Object refValue, Type fieldType) {
		System.out.println("visitRef("+ref.getName()+","+refValue+","+fieldType+")");
		if (ref.isMany()) {
			List<EObject> refValues = (List<EObject>) refValue;
			List<IValue> valuesToRef = refValues.stream().map(elem -> makeRefTo(elem)).collect(Collectors.toList());
			IValue[] arr = new IValue[valuesToRef.size()];
			IValue[] valuesArray = valuesToRef.toArray(arr);

			if (ref.isUnique()) {
				if (ref.isOrdered()) {            // M & U & O = ?
					throw RuntimeExceptionFactory.illegalArgument(vf.string(ref.toString()), null, null);
				} else {                          // M & U & !O = set[Ref[T]]
					return vf.set(valuesArray);
				}
			} else {
				if (ref.isOrdered()) {            // M & !U & O = list[Ref[T]]
					return vf.list(valuesArray);
				} else {                          // M & !U & !O = Map[Ref[T], int]
					throw RuntimeExceptionFactory.illegalArgument(vf.string(ref.toString()), null, null);
				}
			}
		} else {
			return makeRefTo((EObject) refValue);
		}

	}
	
	/**
	 * Retrieve an unique id for an EObject.
	 * In our case, its URI.
	 */
	private IValue getIdFor(EObject obj) {
		Type idType = ts.lookupAbstractDataType("Id");
		Type idCons = ts.lookupConstructor(idType, "id", tf.tupleType(tf.sourceLocationType()));
		URI eUri = EcoreUtil.getURI(obj);
		
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
	private IValue makeRefTo(EObject eObj) {
		Type genRefType = ts.lookupAbstractDataType("Ref");
		
		if (eObj == null) {
			Type nullCons = ts.lookupConstructor(genRefType, "null", tf.tupleEmpty());
			return vf.constructor(nullCons);
		}
		
		
		Type idType = ts.lookupAbstractDataType("Id");
		Type refCons = ts.lookupConstructor(genRefType,  "ref", tf.tupleType(idType));
		return vf.constructor(refCons, getIdFor(eObj));
	}
	
	/**
	 * Returns IValue for primitive type
	 */
	private IValue makePrimitive(Object obj) {
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
		
		
		throw RuntimeExceptionFactory.illegalArgument(vf.string(obj.toString()), null, null);
	}
	
	private static String toFirstLowerCase(String s) {
		return s.substring(0, 1).toLowerCase() + s.substring(1);
	}
}
