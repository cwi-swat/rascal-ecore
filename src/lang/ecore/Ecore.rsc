module lang::ecore::Ecore

// source: http://download.eclipse.org/modeling/emf/emf/javadoc/2.9.0/org/eclipse/emf/ecore/package-summary.html

extend lang::ecore::Refs;

data EPackage(Id uid = noId(), loc pkgURI = |http://www.eclipse.org/emf/2002/Ecore|)
  = EPackage(
      str name,  // from ENamedElement
      str nsURI, 
      str nsPrefix, 
      list[EAnnotation] eAnnotations = [], // from EModelElement
      list[EClassifier] eClassifiers = [],
      list[EPackage] eSubpackages = []); 


data EAnnotation(Id uid = noId())
  = EAnnotation(
      str source,
      //map[str, str] details,
      list[EStringToStringMapEntry] details = [],
      list[EAnnotation] eAnnotations = []); 

data EStringToStringMapEntry
  = EStringToStringMapEntry(str key, str \value);

data EClassifier(Id uid = noId())
  = EClass(
      str name, 
      //str instanceClassName,
      bool abstract,
      bool interface,
      list[Ref[EClassifier]] eSuperTypes = [], 
      list[EStructuralFeature] eStructuralFeatures = [],
      list[EOperation] eOperations = [],
      list[EAnnotation] eAnnotations = [])
      
  | EDataType(
      str name, 
      //str instanceClassName,
      bool serializable = true,
      list[EAnnotation] eAnnotations = [])
      
  | EEnum(
      str name, 
      bool serializable = true,
      list[EEnumLiteral] eLiterals = [],
      list[EAnnotation] eAnnotations = []);

data EEnumLiteral(Id uid = noId())
  = EEnumLiteral(
      str name, 
      str literal, 
      int \value, 
      list[EAnnotation] eAnnotations = []);

data EJavaClass(Id uid = noId())
  = EJavaClass(str name);

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
  = EReference(
      str name, 
      Ref[EClassifier] eType, 
      bool containment,
      bool container,
      bool resolveProxies = true,
      Ref[EStructuralFeature] eOpposite = null(),
      list[Ref[EStructuralFeature]] eKeys = [])
      
  | EAttribute(
      str name,       
      Ref[EClassifier] eType, 
      bool iD = false)
  ;


data EOperation(Id uid = noId())
  = EOperation(
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
  = EParameter(
      str name, 
      Ref[EClassifier] eType,
      bool ordered = true,
      bool unique = true,
      int lowerBound = 0,
      int upperBound = 1,
      bool many = false,
      bool required = false);

