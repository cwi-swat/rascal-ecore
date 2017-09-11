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
import io.usethesource.vallang.visitors.NullVisitor;

class Convert {

	private static TypeFactory tf = TypeFactory.getInstance();
	
	static class ModelBuilder implements IValueVisitor<Object, RuntimeException> {
		private EPackage pkg;
		private Map<IConstructor, EObject> uids = new HashMap<>();

		public ModelBuilder(EPackage pkg) {
			this.pkg  = pkg;
		}

		public Map<IConstructor, EObject> getUids() {
			return uids;
		}
		
		@Override
		public Object visitConstructor(IConstructor o) throws RuntimeException {
			String clsName = o.getName();
			EClass eCls = (EClass) pkg.getEClassifier(clsName);
			
			if (eCls != null) { // Create corresponding concept
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
					Object newVal = v.accept(this);
					newObj.eSet(toSet, newVal);
					i++;
				}
				
				for (Map.Entry<String, IValue> e: c.getParameters().entrySet()) {
					String fieldName = e.getKey();
					if (fieldName.equals("src") || fieldName.equals("uid")) {
						continue;
					}
					EStructuralFeature toSet = eCls.getEStructuralFeature(fieldName);
					Object newVal = e.getValue().accept(this);
					newObj.eSet(toSet, newVal);
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

	static class CrossRefResolver extends NullVisitor<Void, RuntimeException> {
		private Map<IValue, EObject> uids;

		public CrossRefResolver(Map<IValue, EObject> uids) {
			this.uids = uids;
		}
		
		@Override
		public Void visitConstructor(IConstructor o) throws RuntimeException {
			IWithKeywordParameters<? extends IConstructor> c = o.asWithKeywordParameters();
			
			if (c.hasParameter("uid")) {
				IConstructor cUid = (IConstructor) c.getParameter("uid");
				EObject me = uids.get(cUid);
				
				int i = 0;
				for (IValue child : o.getChildren()) {
					String fieldName = o.getChildrenTypes().getFieldName(i);
					EStructuralFeature toSet = me.eClass().getEStructuralFeature(fieldName);
					if (child instanceof IConstructor) {
						IConstructor childCons = (IConstructor) child;
						if (isRef(childCons)) {
							IConstructor id = (IConstructor) childCons.get(0);
							EObject resolved = lookup(id);
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

		private EObject lookup(IConstructor uid) {
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
	static IValue obj2value(Object obj, Type type, IValueFactory vf, TypeStore ts) {
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

				if (fieldName.equals("uid") || fieldName.equals("src") || fieldName.equals("pkgURI")) {
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
	
}
