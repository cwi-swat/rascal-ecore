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
	Map<EObject,Integer> eObjectToUid = new HashMap<>();
	
	public IO(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		this.tf = TypeFactory.getInstance();
	}
	
	public IValue load(IValue reifiedType, ISourceLocation loc) {
		TypeStore ts = new TypeStore();
		Type rt = tr.valueToType((IConstructor)reifiedType, ts);
		
		EObject root = loadModel(loc.getURI().toString());
		
		return visit(root, rt, ts);
	}

	public EObject loadModel(String uri) {
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
		
		if(obj instanceof EObject) {
			EObject eObj = (EObject) obj;
			EClass eCls = eObj.eClass();
			Type t = ts.lookupConstructor(type, toFirstLowerCase(eCls.getName())).iterator().next();
			
			List<IValue> fields = new ArrayList<>();
			for(int i = 0; i < t.getArity(); i++) {
				//Rascal side
				String fieldName = t.getFieldName(i);
				Type fieldType = t.getFieldType(i);
				
				//EMF side
				EStructuralFeature feature = eCls.getEStructuralFeature(fieldName);
				Object featureValue = eObj.eGet(feature);
				
				if(feature instanceof EReference) {
					EReference ref = (EReference) feature;
					if(ref.isContainment()) {
						fields.add(visitContainmentRef(ref,featureValue, fieldType,ts));
					}
					else {
						fields.add(visitReference(ref,(EObject) featureValue, fieldType));
					}
				}
				else if(feature instanceof EAttribute) {
					EAttribute att = (EAttribute) feature;
					fields.add(visitAttribute(att,featureValue, fieldType,ts));
				}
			}
			
			Map<String,IValue> keywords = new HashMap<>();
			keywords.put("uid", getOrCreateId(eObj));
			IValue[] arr = new IValue[fields.size()];
			return vf.constructor(t,fields.toArray(arr),keywords);
		}
		else {
			return makePrimitive(obj);
		}
	}
	
	
	/**
	 * Build ADT by visiting an EAttribute
	 */
	private IValue visitAttribute(EStructuralFeature ref, Object refValue, Type fieldType, TypeStore ts) {
		
		if(ref.isMany() && ref.isUnique() && ref.isOrdered()) {
			// return ?
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> visit(elem,elemType,ts)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			return vf.list(values.toArray(arr));
		}

		if (ref.isMany() && ref.isUnique() && !ref.isOrdered()) {
			// return set[T]
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> visit(elem,elemType,ts)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			return vf.set(values.toArray(arr));
		}

		if (ref.isMany() && !ref.isUnique() && ref.isOrdered()) {
			// return list[T]
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> visit(elem,elemType,ts)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			return vf.list(values.toArray(arr));
		}

		if (ref.isMany() && !ref.isUnique() && !ref.isOrdered()) {
			// return map[T,int]
			//TODO: vf.map(arg0, arg1)
		}
		
		if(!ref.isRequired() && !ref.isMany()) {
			// return Opt[T]
			Type rt = ts.lookupAbstractDataType("Opt");
			Type t = ts.lookupConstructor(rt, "just", tf.tupleType(visit(refValue,fieldType,ts)));
			return vf.constructor(t);
		}
		
		if(ref.isRequired() && !ref.isMany()) {
			// return T
			return makePrimitive(refValue);
		}
		
		return null;
	}
	
	/**
	 * Build an ADT by visiting a containment EReference
	 */
	private IValue visitContainmentRef(EStructuralFeature ref, Object refValue, Type fieldType, TypeStore ts) {
		
		if(ref.isMany() && ref.isUnique() && ref.isOrdered()) {
			// return ?
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> visit(elem,elemType,ts)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			return vf.list(values.toArray(arr));
		}

		if (ref.isMany() && ref.isUnique() && !ref.isOrdered()) {
			// return set[T]
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> visit(elem,elemType,ts)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			return vf.set(values.toArray(arr));
		}

		if (ref.isMany() && !ref.isUnique() && ref.isOrdered()) {
			// return list[T]
			List<Object> refValues = (List<Object>) refValue;
			Type elemType = fieldType.getElementType();
			List<IValue> values = refValues.stream().map(elem -> visit(elem,elemType,ts)).collect(Collectors.toList());
			IValue[] arr = new IValue[values.size()];
			return vf.list(values.toArray(arr));
		}

		if (ref.isMany() && !ref.isUnique() && !ref.isOrdered()) {
			// return map[T,int]
			//TODO: vf.map(arg0, arg1)
		}
		
		if(!ref.isRequired() && !ref.isMany()) {
			// return Opt[T]
			Type rt = ts.lookupAbstractDataType("Opt");
			Type t = ts.lookupConstructor(rt, "just", tf.tupleType(visit(refValue,fieldType,ts)));
			return vf.constructor(t);
		}
		
		if(ref.isRequired() && !ref.isMany()) {
			// return T
			Type t = ts.lookupConstructor(fieldType, toFirstLowerCase(fieldType.getName()), tf.tupleType(visit(refValue,fieldType,ts)));
			return vf.constructor(t);
		}
		
		return null;
	}
	
	/**
	 * Build an ADT by visting an EReference
	 */
	private IValue visitReference(EReference ref, EObject refValue, Type fieldType) {
		
		if(ref.isMany() && ref.isUnique() && !ref.isOrdered()) {
			// return set[Ref[T]]
			List<EObject> refValues = (List<EObject>) refValue;
			List<IValue> valuesToRef = refValues.stream().map(elem -> makeRefTo(elem)).collect(Collectors.toList());
			IValue[] arr = new IValue[valuesToRef.size()];
			return vf.set(valuesToRef.toArray(arr));
		}

		if (ref.isMany() && !ref.isUnique() && ref.isOrdered()) {
			// return list[Ref[T]]
			List<EObject> refValues = (List<EObject>) refValue;
			List<IValue> valuesToRef = refValues.stream().map(elem -> makeRefTo(elem)).collect(Collectors.toList());
			IValue[] arr = new IValue[valuesToRef.size()];
			return vf.list(valuesToRef.toArray(arr));
		}

		if (ref.isMany() && !ref.isUnique() && !ref.isOrdered()) {
			// return map[Ref[T],int]
			//TODO:
		}

		if (!ref.isMany()) {
			// return Ref[T]
			return makeRefTo(refValue);
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
		
		return vf.constructor(id_int,vf.integer(num));
	}
	
	/**
	 * Make unique Id for {@link obj}
	 */
	private IValue getOrCreateId(EObject obj) {
		Integer uid = eObjectToUid.get(obj);
		if(uid == null) {
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
		
		if(eObj ==  null) {
			Type optType = tf.abstractDataType(ts, "Opt");
			Type none = tf.constructor(ts, optType, "none");
			return vf.constructor(none,new IValue[0]);
		}
		
		Type idType = tf.abstractDataType(ts, "Id");
		Type refType = tf.abstractDataType(ts, "Ref");
		
		Type params = tf.tupleType(new Type[]{idType}, new String[]{"uid"});
		Type ref_id = tf.constructorFromTuple(ts, refType, "ref", params);
		
		return vf.constructor(ref_id, getOrCreateId(eObj));
	}
	
	/**
	 * Return ADT for primitive
	 */
	private IValue makePrimitive(Object obj) {
		
		if(obj instanceof Boolean) {
			return vf.bool((boolean) obj);
		}
		else if(obj instanceof Byte) {
			//FIXME
		}
		else if(obj instanceof Character) {
			//FIXME:
			//vf.string(((Character)obj).toString());
		}
		else if(obj instanceof Double) {
			return vf.real((String) obj);
		}
		else if(obj instanceof Integer) {
			return vf.integer((String) obj);
		}
		else if(obj instanceof Long) {
			return vf.integer((String) obj);
		}
		else if(obj instanceof Short) {
			return vf.integer((int)obj);
		}
		else if(obj instanceof Float) {
			return vf.real((double)obj);
		}
		else if(obj instanceof String) {
			return vf.string((String) obj);
		}
		//FIXME: manage enum
		
		return null;
	}
	
	private String toFirstLowerCase(String s) {
		char c[] = s.toCharArray();
		c[0] = Character.toLowerCase(c[0]);
		return new String(c);
	}
}
