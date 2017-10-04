package lang.ecore;

import java.net.URISyntaxException;
import java.util.ArrayList;
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
import org.eclipse.emf.ecore.util.EcoreUtil;
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

class Convert {

	private static TypeFactory tf = TypeFactory.getInstance();
	
	public static EObject value2obj(EPackage pkg, IConstructor model, TypeStore ts) {
		ModelBuilder builder = new ModelBuilder(pkg, ts);
		EObject obj = (EObject) model.accept(builder);
		for (EObject x: builder.fixes.keySet()) {
			builder.fixes.get(x).apply(x, builder.uids);
		}
		return obj;
	}
	
	public static void declareRefType(TypeStore ts) {
		// Cheat: build Ref  here (assuming Id is in there)
		Type idType = tf.abstractDataType(ts, "Id");
		tf.constructor(ts, idType, "id", tf.integerType(), "n");
		tf.constructor(ts, idType, "id", tf.sourceLocationType(), "uri");

		Type refType = tf.abstractDataType(ts, "Ref", tf.parameterType("T"));
		tf.constructor(ts, refType, "ref", ts.lookupAbstractDataType("Id"), "uid");
		tf.constructor(ts, refType, "null");

	}
	
	public static void declareMaybeType(TypeStore ts) {
		Type idType = tf.abstractDataType(ts, "Maybe", tf.parameterType("A"));
		tf.constructor(ts, idType, "just", tf.parameterType("A"), "val");
		tf.constructor(ts, idType, "nothing");
	}

	
	private static class ModelBuilder implements IValueVisitor<Object, RuntimeException> {
		private EPackage pkg;
		private Map<IConstructor, EObject> uids = new HashMap<>();
		private Map<EObject, Fix> fixes = new HashMap<>();
		private TypeStore ts;
		
		static class Fix {
			private EStructuralFeature field;
			private IConstructor id;

			Fix(EStructuralFeature field, IConstructor id) {
				this.field = field;
				this.id = id;
			}
			
			void apply(EObject owner, Map<IConstructor, EObject> uids) {
				owner.eSet(field, uids.get(id));
			}
			
		}
		
		
		private ModelBuilder(EPackage pkg, TypeStore ts) {
			this.pkg  = pkg;
			this.ts = ts;
		}

		@Override
		public Object visitConstructor(IConstructor o) throws RuntimeException {
			
			if (isRef(o)) {
				// in later resolve phase
				return null;
			}
			
			if (o.getType().isSubtypeOf(ts.lookupAbstractDataType("Maybe"))) {
				if (o.getConstructorType().getName().equals("just")) {
					return o.get(0).accept(this);
				}
				return null;
			}
			
			o = uninject(o, ts);
			String clsName = o.getName();
			EClass eCls = (EClass) pkg.getEClassifier(clsName);
			
			if (eCls == null) {
				throw RuntimeExceptionFactory.illegalArgument(null, null);
			}
			
			
			// Create corresponding concept
			EFactory fact = pkg.getEFactoryInstance();
			EObject newObj = fact.create(eCls);
			
			IWithKeywordParameters<? extends IConstructor> c = o.asWithKeywordParameters();
			
			if (c.hasParameter("uid")) {
				IConstructor cUid = (IConstructor) c.getParameter("uid");
				uids.put(cUid, newObj);
			}
			
			int i = 0;
			for (IValue v : o.getChildren()) {
				String fieldName = o.getChildrenTypes().getFieldName(i);
				EStructuralFeature toSet = eCls.getEStructuralFeature(fieldName);
				if (v.getType().isAbstractData() && isRef((IConstructor)v)) {
					fixes.put(newObj, new Fix(toSet, (IConstructor)((IConstructor)v).get("uid")));
				}
				else {
					Object newVal = v.accept(this);
					if (newVal != null) {
						newObj.eSet(toSet, newVal);
					}
				}
				i++;
			}
			
			for (Map.Entry<String, IValue> e: c.getParameters().entrySet()) {
				String fieldName = e.getKey();
				if (fieldName.equals("uid")) {
					continue;
				}
				IValue v = e.getValue();
				EStructuralFeature toSet = eCls.getEStructuralFeature(fieldName);
				if (v.getType().isAbstractData() && isRef((IConstructor)v)) {
					fixes.put(newObj, new Fix(toSet, (IConstructor)((IConstructor)v).asWithKeywordParameters().getParameter("uid")));
				}
				else {
					Object newVal = v.accept(this);
					if (newVal != null) {
						newObj.eSet(toSet, newVal);
					}
				}
			}
			
			return newObj;
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

	private static boolean isRef(IConstructor o) {
		return "ref".equals(o.getName()) && "Ref".equals(o.getType().getName());
	}
	
	
	/**
	 * Build ADT while visiting EObject content
	 */
	public static IValue obj2value(Object obj, Type type, IValueFactory vf, TypeStore ts, ISourceLocation src) {
		//ctx.getStdErr().println("Visiting object " + obj + " (" + type + ")");

		if (obj instanceof EObject) {
			EObject eObj = (EObject) obj;
			EClass eCls = eObj.eClass();

			// FIXME: Assuming that there's a unique constructor with the EClass' name
			// INDEED: we now have multiple ones...
			Type t = null; 
			boolean maybe = false;
			if (type.isSubtypeOf(ts.lookupAbstractDataType("Maybe"))) {
				type = type.getTypeParameters().getFieldType(0);
				maybe = true;
			}
			for (Type candidate: ts.lookupAlternatives(ts.lookupAbstractDataType(eCls.getName()))) {
				if (ts.getKeywordParameters(candidate).containsKey("_inject")) {
					continue;
				}
				t = candidate;
				break;
			}
			if (t == null) {
				throw RuntimeExceptionFactory.io(vf.string("No constructor for " + eCls + " "
						+ type), null, null);
			}
			
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
						fields.add(inject(t.getFieldType(i), ts, vf, visitContainmentRef(ref, featureValue, fieldType, vf, ts, src)));
					}
					else {
						fields.add(visitReference(ref, featureValue, fieldType, vf, ts, src));
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

				
				if (fieldName.equals("uid") || fieldName.equals("pkgURI")) {
					continue;
				}
				
				// EMF side
				EStructuralFeature feature = eCls.getEStructuralFeature(fieldName);
				
				//System.out.println("Looking for " + fieldName + " in " + eCls.getName());
				Object featureValue = eObj.eGet(feature);
				
				if (!eObj.eIsSet(feature)) {
					continue;
				}

				if (feature instanceof EReference) {
					// Then featureValue is an EObject
					EReference ref = (EReference) feature;
					if (ref.isContainment()) {
						IValue x = visitContainmentRef(ref, featureValue, fieldType, vf, ts, src);
						if (x != null) {
							keywords.put(fieldName, x);
						}
					}
					else {
						IValue x = visitReference(ref, featureValue, fieldType, vf, ts, src);
						if (x != null) {
							keywords.put(fieldName, x);
						}
					}
				}
				else if (feature instanceof EAttribute) {
					// Then featureValue is a primitive type
					EAttribute att = (EAttribute) feature;
					IValue x = visitAttribute(att, featureValue, fieldType, vf, ts);
					if (x != null) {
						keywords.put(fieldName, x);
					}
				}
			}
			
			keywords.put("uid", getIdFor(eObj, vf, ts, src));
			IValue[] arr = new IValue[fields.size()];
			
			IValue arg = inject(type, ts, vf, vf.constructor(t, fields.toArray(arr), keywords));
			if (maybe && arg != null) {
				return vf.constructor(ts.lookupConstructor(ts.lookupAbstractDataType("Maybe"), "just", tf.tupleType(arg)), arg);
			}
			if (maybe && arg == null) {
				return vf.constructor(ts.lookupConstructor(ts.lookupAbstractDataType("Maybe"), "nothing", tf.tupleEmpty()));
			}
			if (arg == null) {
				System.out.println("BLA");
			}
			return arg;
		}

		return makePrimitive(obj, type, vf);
	}
	
	private static IConstructor uninject(IConstructor c, TypeStore ts) {
		if (ts.getKeywordParameters(c.getConstructorType()).containsKey("_inject")) {
			return uninject((IConstructor)c.get(0), ts);
		}
		return c;
	}
	
	private static IValue inject(Type type, TypeStore ts, IValueFactory vf, IValue x) {
		/*
		 * Example:
		 * x maybe EClass(...)
		 * but type maybe EClassifier
		 * so need to create EClassifier(x);
		 */
		
		for (Type cons: ts.lookupAlternatives(type)) {
			if (cons == ((IConstructor)x).getConstructorType()) {
				return x;
			}
			if (cons.getArity() == 0) {
				continue;
			}
			if (ts.getKeywordParameters(cons).containsKey("_inject") && cons.getFieldType(0) == x.getType()) {
				// found it;
				return vf.constructor(cons, x);
			}
			else {
				IValue injected = inject(cons.getFieldType(0), ts, vf, x);
				if (injected != null) {
					return injected;
				}
			}
		}
		return null;
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
	private static IValue visitContainmentRef(EStructuralFeature ref, Object refValue, Type fieldType, IValueFactory vf, TypeStore ts, ISourceLocation src) {
		//ctx.getStdErr().println("Visiting containment ref " + ref.getName() + " to " + refValue + " (" + fieldType + ")");

		//System.out.println("visitCont("+ref.getName()+","+refValue+","+fieldType+")");
		
		if (ref.isMany()) {
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> obj2value(elem, elemType, vf, ts, src)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			IValue[] valuesArray = values.toArray(arr);
			return vf.list(values.toArray(valuesArray));
		} else {
			IValue val = obj2value(refValue, fieldType, vf, ts, src);
			if (val == null) {
				System.out.println("");
			}
			return val;
//			Type t = ts.lookupConstructor(fieldType, fieldType.getName(), tf.tupleType(val));
//			return vf.constructor(t, val);
		}
		
	}
	
	/**
	 * Returns IValue for an EReference
	 */
	@SuppressWarnings("unchecked")
	private static IValue visitReference(EReference ref, Object refValue, Type fieldType, IValueFactory vf, TypeStore ts, ISourceLocation src) {
		//ctx.getStdErr().println("Visiting reference ref " + ref.getName() + " to " + refValue + " (" + fieldType + ")");
		
		//System.out.println("visitRef("+ref.getName()+","+refValue+","+fieldType+")");
		if (ref.isMany()) {
			List<EObject> refValues = (List<EObject>) refValue;
			List<IValue> valuesToRef = refValues.stream().map(elem -> makeRefTo(elem, vf, ts, src)).collect(Collectors.toList());
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
			IValue x = makeRefTo((EObject) refValue, vf, ts, src);
			//ctx.getStdErr().println("The ref is: " + x);
			return x;
		}

	}
	
	/**
	 * Retrieve an unique id for an EObject.
	 * In our case, its URI.
	 * TODO: refactor this to be reusable in patch.
	 */
	private static IValue getIdFor(EObject obj, IValueFactory vf, TypeStore ts, ISourceLocation src) {
		//ctx.getStdErr().println("Making id for " + obj);
		
		Type idType = ts.lookupAbstractDataType("Id");
		Type idCons = ts.lookupConstructor(idType, "id", tf.tupleType(tf.sourceLocationType()));
		URI eUri = EcoreUtil.getURI(obj);
		
		try {
			java.net.URI uriId = URIUtil.create(src.getScheme(), src.getAuthority(), src.getPath(), src.getQuery(), eUri.fragment());
			return vf.constructor(idCons, vf.sourceLocation(uriId));
		} catch (URISyntaxException e) {
			throw RuntimeExceptionFactory.malformedURI(eUri.toString(), null, null);
		}
		
	}
	
	/**
	 * Return ref(id(Num)) or null() if {@link eObj} is null
	 */
	private static IValue makeRefTo(EObject eObj, IValueFactory vf, TypeStore ts, ISourceLocation src) {
		//ctx.getStdErr().println("Making ref to " + eObj);
		Type genRefType = ts.lookupAbstractDataType("Ref");
		
		if (eObj == null) {
			Type nullCons = ts.lookupConstructor(genRefType, "null", tf.tupleEmpty());
			return vf.constructor(nullCons);
		}
		
		
		Type idType = ts.lookupAbstractDataType("Id");
		Type refCons = ts.lookupConstructor(genRefType,  "ref", tf.tupleType(idType));
		IValue id = getIdFor(eObj, vf, ts, src);
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

	
}
