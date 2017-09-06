package lang.ecore;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EAttribute;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.rascalmpl.interpreter.TypeReifier;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;

/**
 * This class provide a load method to get an ADT from an EMF model
 */
public class IO {
	private IValueFactory vf;
	private TypeReifier tr;
	private TypeFactory tf;
	
	/**
	 * Counter used to make UIDs
	 */
	int COUNTER = 0;
	
	/**
	 * Store the UID of each referenced EObject 
	 */
	Map<EObject, Integer> eObjectToUid = new HashMap<>();
	
	public IO(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		this.tf = TypeFactory.getInstance();
	}
	
	public IValue load(IValue reifiedType, ISourceLocation loc) {
		TypeStore ts = new TypeStore();
		Type rt = tr.valueToType((IConstructor) reifiedType, ts);
		
		EObject root = loadModel(loc.getURI().toString());
		
		return visit(root, rt, ts);
	}

	private EObject loadModel(String uri) {
		ResourceSet rs = new ResourceSetImpl();
		rs.getResourceFactoryRegistry().getExtensionToFactoryMap()
			.put("*", new XMIResourceFactoryImpl());
		Resource res = rs.getResource(URI.createURI(uri), true);
		return res.getContents().get(0);
	}
	
	/**
	 * Build ADT while visiting EObject content
	 */
	private IValue visit(Object obj, Type type, TypeStore ts) {
		if (obj instanceof EObject) {
			EObject eObj = (EObject) obj;
			EClass eCls = eObj.eClass();

			// FIXME: Assuming that there's a unique constructor with the EClass' name
			Type t = ts.lookupConstructor(type, toFirstLowerCase(eCls.getName())).iterator().next();
			
			List<IValue> fields = new ArrayList<>();
			for (int i = 0; i < t.getArity(); i++) {
				// Rascal side
				String fieldName = t.getFieldName(i);
				Type fieldType = t.getFieldType(i);
				
				// EMF side
				EStructuralFeature feature = eCls.getEStructuralFeature(fieldName);
				Object featureValue = eObj.eGet(feature);

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
			keywords.put("uid", getOrCreateId(eObj));
			IValue[] arr = new IValue[fields.size()];
			return vf.constructor(t, fields.toArray(arr), keywords);
		}
		else {
			return makePrimitive(obj);
		}
	}
	
	
	/**
	 * Returns IValue for an EAttribute
	 */
	private IValue visitAttribute(EStructuralFeature ref, Object refValue, Type fieldType, TypeStore ts) {
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
					// TODO: Implement me
				}
			}
		} else {
			if (!ref.isRequired()) {              // !M && O = Opt[T]
				Type rt = ts.lookupAbstractDataType("Opt");
				Type t = ts.lookupConstructor(rt, "just", tf.tupleType(makePrimitive(refValue)));
				return vf.constructor(t);
			} else {                              // !M && !O = T
				return makePrimitive(refValue);
			}
		}

		return null;
	}
	
	/**
	 * Returns IValue for a containment EReference
	 */
	private IValue visitContainmentRef(EStructuralFeature ref, Object refValue, Type fieldType, TypeStore ts) {
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
					// TODO: Implement me
				}
			}
		} else {
			if (!ref.isRequired()) {              // !M && O = Opt[T]
				Type rt = ts.lookupAbstractDataType("Opt");
				Type t = ts.lookupConstructor(rt, "just", tf.tupleType(visit(refValue, fieldType, ts)));
				return vf.constructor(t);
			} else {                              // !M && !O = T
				Type t = ts.lookupConstructor(fieldType, toFirstLowerCase(fieldType.getName()), tf.tupleType(visit(refValue, fieldType, ts)));
				return vf.constructor(t);
			}
		}
		
		return null;
	}
	
	/**
	 * Returns IValue for an EReference
	 */
	private IValue visitReference(EReference ref, Object refValue, Type fieldType) {
		if (ref.isMany()) {
			List<EObject> refValues = (List<EObject>) refValue;
			List<IValue> valuesToRef = refValues.stream().map(elem -> makeRefTo(elem)).collect(Collectors.toList());
			IValue[] arr = new IValue[valuesToRef.size()];
			IValue[] valuesArray = valuesToRef.toArray(arr);

			if (ref.isUnique()) {
				if (ref.isOrdered()) {            // M & U & O = ?
					// TODO: Implement me
				} else {                          // M & U & !O = set[Ref[T]]
					return vf.set(valuesArray);
				}
			} else {
				if (ref.isOrdered()) {            // M & !U & O = list[Ref[T]]
					return vf.list(valuesArray);
				} else {                          // M & !U & !O = Map[Ref[T], int]
					// TODO: Implement me
				}
			}
		} else {
			return makeRefTo((EObject) refValue);
		}

		return null;
	}
	
	/**
	 * Return id(num)
	 */
	private IValue makeId(int num) {
		TypeStore ts = new TypeStore();
		Type idType = tf.abstractDataType(ts, "Id");
		Type id_int = tf.constructor(ts, idType, "id", tf.integerType());
		
		return vf.constructor(id_int, vf.integer(num));
	}
	
	/**
	 * Make unique Id for {@link obj}
	 */
	private IValue getOrCreateId(EObject obj) {
		Integer uid = eObjectToUid.get(obj);
		if (uid == null) {
			uid = COUNTER++;
			eObjectToUid.put(obj,uid);
		}
		return makeId(uid);
	}
	
	/**
	 * Return ref(id(Num)) or none() if {@link eObj} is null
	 */
	private IValue makeRefTo(EObject eObj) {
		TypeStore ts = new TypeStore();
		
		if (eObj == null) {
			Type optType = tf.abstractDataType(ts, "Opt");
			Type none = tf.constructor(ts, optType, "none");
			return vf.constructor(none, new IValue[0]);
		}
		
		Type idType = tf.abstractDataType(ts, "Id");
		Type refType = tf.abstractDataType(ts, "Ref");
		
		Type params = tf.tupleType(new Type[]{idType}, new String[]{"uid"});
		Type ref_id = tf.constructorFromTuple(ts, refType, "ref", params);
		
		return vf.constructor(ref_id, getOrCreateId(eObj));
	}
	
	/**
	 * Returns IValue for primitive type
	 */
	private IValue makePrimitive(Object obj) {
		if (obj instanceof Boolean) {
			return vf.bool((Boolean) obj);
		}
		else if (obj instanceof Byte) { // FIXME: Rascal's byte?
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
			return vf.integer((Short)obj);
		}
		else if (obj instanceof Float) { // FIXME: Rascal's float?
			return vf.real((Float)obj);
		}
		else if (obj instanceof String) {
			return vf.string((String) obj);
		}

		// FIXME: Enums?
		// FIXME: Datatypes?
		
		return null;
	}
	
	private String toFirstLowerCase(String s) {
		return s.substring(0, 1).toLowerCase() + s.substring(1);
	}
}
