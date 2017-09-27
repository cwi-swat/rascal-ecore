module lang::ecore::Ecore2

// source: http://download.eclipse.org/modeling/emf/emf/javadoc/2.9.0/org/eclipse/emf/ecore/package-summary.html

extend lang::ecore::Refs;

// root
data EPackage(loc pkgURI = |http://www.eclipse.org/emf/2002/Ecore|)
  = EPackage(
      str name,  // from ENamedElement
      str nsURI, 
      str nsPrefix, 
      list[EAnnotation] eAnnotations = [], // from EModelElement
      list[EClassifier] eClassifiers = [],
      list[EPackage] eSubpackages = [],
      Id uid = noId()); 



data EModelElement
  = EModelElement(ENamedElement eNamedElement, Id uid = eNamedElement.uid)
  | EModelElement(EAnnotation eAnnotation, Id uid = eAnnotation.uid)
  ;
  
  
data ENamedElement
  = ENamedElement(EPackage ePackage, Id uid = ePackage.uid)
  | ENamedElement(EClassifier eClassifier, Id uid = eClassifier.uid)
  | ENamedElement(EEnumLiteral eEnumLiteral, Id uid = eEnumLiteral.uid)
  | ENamedElement(ETypedElement eTypedElement, Id uid = eTypedElement.uid)
  ;
  
data ETypedElement
  = ETypedElement(EStructuralFeature eStructuralFeature, Id uid = eStructuralFeature.uid)
  | ETypedElement(EOperation eOperation, Id uid = eOperation.uid)
  | ETypedElement(EParameter eParameter, Id uid = eParameter.uid)
  ;
  
data EClassifier
  = EClassifier(EClass eClass, Id uid = eClass.uid)
  | EClassifier(EDataType eDataType, Id uid = eDataType.uid)
  ;
  
data EStructuralFeature
  = EStructuralFeature(EAttribute eAttribute, Id uid = eAttribute.uid)
  | EStructuralFeature(EReference eReference, Id uid = eReference.uid)
  ;
  


data EAnnotation
  = EAnnotation(
      str source,
      list[EStringToStringMapEntry] details = [],
      list[EAnnotation] eAnnotations = [],
      Id uid = noId()); 

data EStringToStringMapEntry
  = EStringToStringMapEntry(str key, str \value, Id uid = noId());

data EClass
  = EClass(
      str name, 
      bool abstract,
      bool interface,
      list[Ref[EClass]] eSuperTypes = [], 
      list[EStructuralFeature] eStructuralFeatures = [],
      list[EOperation] eOperations = [],
      list[EAnnotation] eAnnotations = [],
      Id uid = noId())
  ;
  
data EDataType
  = EDataType(
      str name, 
      bool serializable = true,
      list[EAnnotation] eAnnotations = [],
      Id uid = noId())
   | EDataType(EEnum eEnum, Id uid = eEnum.uid)
   ;
   
data EEnum      
   = EEnum(
      str name, 
      bool serializable = true,
      list[EEnumLiteral] eLiterals = [],
      list[EAnnotation] eAnnotations = [],
      Id uid = noId());

data EEnumLiteral
  = EEnumLiteral(
      str name, 
      str literal, 
      int \value, 
      list[EAnnotation] eAnnotations = [],
      Id uid = noId());

data EReference
  = EReference(
      str name, 
      Ref[EClassifier] eType, 
      bool containment,
      bool container,
      bool resolveProxies = true,
      Ref[EReference] eOpposite = null(),
	  bool ordered = true,
	  bool unique = true,
	  int lowerBound = 0,
	  int upperBound = 1,
	  bool many = false,
	  bool required = false,
	  bool changeable = true, 
	  bool volatile = false,
	  bool transient = false,
	  str defaultValueLiteral = "",
	  bool unsettable = false,
	  bool derived = false,
	  Id uid = noId());
      
data EAttribute
  = EAttribute(
      str name,       
      Ref[EClassifier] eType,
      bool iD = false, 
	  bool ordered = true,
	  bool unique = true,
	  int lowerBound = 0,
	  int upperBound = 1,
	  bool many = false,
	  bool required = false,
	  bool changeable = true, 
	  bool volatile = false,
	  bool transient = false,
	  str defaultValueLiteral = "",
	  bool unsettable = false,
	  bool derived = false,
	  Id uid = noId())
  ;


data EOperation
  = EOperation(
      str name,
      Ref[EClassifier] eType,
      list[EParameter] eParameters = [],
      list[EClassifier] eExceptions = [],
      bool ordered = true,
      bool unique = true,
      int lowerBound = 0,
      int upperBound = 1,
      bool many = false,
      bool required = false,
      Id uid = noId());

data EParameter(Id uid = noId())
  = EParameter(
      str name, 
      Ref[EClassifier] eType,
      list[EParameter] eParameters = [],
      list[EClassifier] eExceptions = [],
      bool ordered = true,
      bool unique = true,
      int lowerBound = 0,
      int upperBound = 1,
      bool many = false,
      bool required = false,
      Id uid = noId());

