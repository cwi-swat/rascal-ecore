module lang::ecore::Ecore

// source: http://download.eclipse.org/modeling/emf/emf/javadoc/2.9.0/org/eclipse/emf/ecore/package-summary.html

// somehow needed to get Ref[X] instead of Ref[&T]
extend lang::ecore::Refs;

data EPackage(Id uid = noId())
  = ePackage(
      str name,  // from ENamedElement
      str nsURI, 
      str nsPrefix, 
      list[EAnnotation] eAnnotations = [], // from EModelElement
      list[EClassifier] eClassifiers = [],
      list[EPackage] eSubpackages = []); 


data EAnnotation(Id uid = noId())
  = eAnnotation(
      str source,
      //map[str, str] details,
      list[EStringToStringMapEntry] details = [],
      list[EAnnotation] eAnnotations = []); 

data EStringToStringMapEntry
  = eStringToStringMapEntry(str key, str \value);

data EClassifier(Id uid = noId())
  = eClass(
      str name, 
      //str instanceClassName,
      bool abstract,
      bool interface,
      list[Ref[EClassifier]] eSuperTypes = [], 
      list[EStructuralFeature] eStructuralFeatures = [],
      list[EOperation] eOperations = [],
      list[EAnnotation] eAnnotations = [])
      
  | eDataType(
      str name, 
      //str instanceClassName,
      bool serializable = true,
      list[EAnnotation] eAnnotations = [])
      
  | eEnum(
      str name, 
      bool serializable = true,
      list[EEnumLiteral] eLiterals = [],
      list[EAnnotation] eAnnotations = []);

data EEnumLiteral(Id uid = noId())
  = eEnumLiteral(
      str name, 
      str literal, 
      int \value, 
      list[EAnnotation] eAnnotations = []);

data EJavaClass(Id uid = noId())
  = eJavaClass(str name);

data EStructuralFeature(
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
  = eReference(
      str name, 
      Ref[EClassifier] eType, 
      bool containment,
      bool container,
      bool resolveProxies = true,
      Ref[EStructuralFeature] eOpposite = null(),
      list[Ref[EStructuralFeature]] eKeys = [])
      
  | eAttribute(
      str name,       
      Ref[EClassifier] eType, 
      bool iD = false)
  ;


data EOperation(Id uid = noId())
  = eOperation(
      str name,
      Ref[EClassifier] eType,
      bool ordered = true,
      bool unique = true,
      int lowerBound = 0,
      int upperBound = 1,
      bool many = false,
      bool required = false,
      list[EParameter] eParameters = [],
      list[EClassifier] eExceptions = []);

data EParameter(Id uid = noId())
  = eParameter(
      str name, 
      Ref[EClassifier] eType,
      bool ordered = true,
      bool unique = true,
      int lowerBound = 0,
      int upperBound = 1,
      bool many = false,
      bool required = false);
