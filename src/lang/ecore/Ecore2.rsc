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
  = EModelElement(ENamedElement eNamedElement)
  | EModelElement(EAnnotation eAnnotation)
  ;
  
  
data ENamedElement
  = ENamedElement(EPackage ePackage)
  | ENamedElement(EClassifier eClassifier)
  | ENamedElement(EEnumLiteral eEnumerLiteral)
  | ENamedElement(ETypedElement eTypedElement)
  ;
  
data ETypedElement
  = ETypedElement(EStructuralFeature eStructuralFeature)
  | ETypedElement(EOperation eOperation)
  | ETypedElement(EParameter eParameter)
  ;
  
data EClassifier
  = EClassifier(EClass eClass)
  | EClassifier(EDataType eDataType)
  ;
  
data EStructuralFeature
  = EStructuralFeature(EAttribute eAttribute)
  | EStructuralFeature(EReference eReference)
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
   | EDataType(EEnum eEnum)
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
      bool required = false);

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

