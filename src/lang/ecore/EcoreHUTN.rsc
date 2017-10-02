module lang::ecore::EcoreHUTN

extend lang::ecore::Base;


syntax EOperation_Field =
   eParameters: "eParameters"  ":"  "["  EParameter*  "]" 
  |  eGenericExceptions: "eGenericExceptions"  ":"  "["  EGenericType*  "]" 
  |  eTypeParameters: "eTypeParameters"  ":"  "["  ETypeParameter*  "]" 
  |  eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  |  eExceptions: "eExceptions"  ":"  "["  Ref[EClassifier]*  "]" 
  ;

syntax EPackage_Field =
   nsURI: "nsURI"  ":"  Str 
  |  eClassifiers: "eClassifiers"  ":"  "["  EClassifier*  "]" 
  |  eSuperPackage: "eSuperPackage"  ":"  Ref[EPackage] 
  |  eFactoryInstance: "eFactoryInstance"  ":"  Ref[EFactory] 
  |  nsPrefix: "nsPrefix"  ":"  Str 
  |  eSubpackages: "eSubpackages"  ":"  "["  EPackage*  "]" 
  ;

syntax EAttribute_Field =
   iD: "iD"  ":"  Bool 
  ;

syntax ENamedElement =
  @inject EPackage: EPackage 
  | @inject ETypedElement: ETypedElement 
  | @inject EEnumLiteral: EEnumLiteral 
  | @inject ETypeParameter: ETypeParameter 
  | @inject EClassifier: EClassifier 
  ;

syntax ETypeParameter =
   ETypeParameter: "ETypeParameter"  "{"  ETypeParameter_Field*  "}" 
  ;

syntax EGenericType =
   EGenericType: "EGenericType"  "{"  EGenericType_Field*  "}" 
  ;

syntax EAnnotation_Field =
   source: "source"  ":"  Str 
  |  eModelElement: "eModelElement"  ":"  Ref[EModelElement] 
  |  details: "details"  ":"  "["  EStringToStringMapEntry*  "]" 
  |  references: "references"  ":"  "["  Ref[EObject]*  "]" 
  |  contents: "contents"  ":"  "["  EObject*  "]" 
  ;

syntax EClass_Field =
   abstract: "abstract"  ":"  Bool 
  |  eOperations: "eOperations"  ":"  "["  EOperation*  "]" 
  |  interface: "interface"  ":"  Bool 
  |  eSuperTypes: "eSuperTypes"  ":"  "["  Ref[EClass]*  "]" 
  |  eGenericSuperTypes: "eGenericSuperTypes"  ":"  "["  EGenericType*  "]" 
  |  eStructuralFeatures: "eStructuralFeatures"  ":"  "["  EStructuralFeature*  "]" 
  ;

syntax EFactory_Field =
   ePackage: "ePackage"  ":"  Ref[EPackage] 
  ;

syntax EOperation =
   EOperation: "EOperation"  "{"  EOperation_Field*  "}" 
  ;

syntax EGenericType_Field =
   eTypeArguments: "eTypeArguments"  ":"  "["  EGenericType*  "]" 
  |  eClassifier: "eClassifier"  ":"  Ref[EClassifier] 
  |  eLowerBound: "eLowerBound"  ":"  EGenericType 
  |  eUpperBound: "eUpperBound"  ":"  EGenericType 
  |  eTypeParameter: "eTypeParameter"  ":"  Ref[ETypeParameter] 
  ;

syntax EStringToStringMapEntry =
   EStringToStringMapEntry: "EStringToStringMapEntry"  "{"  EStringToStringMapEntry_Field*  "}" 
  ;

syntax EModelElement =
  @inject ENamedElement: ENamedElement 
  | @inject EFactory: EFactory 
  | @inject EAnnotation: EAnnotation 
  ;

syntax EParameter_Field =
   eOperation: "eOperation"  ":"  Ref[EOperation] 
  ;

syntax EObject_Field =
  ...
  ;

syntax EStringToStringMapEntry_Field =
   key: "key"  ":"  Str 
  |  \value: "value"  ":"  Str 
  ;

syntax EClass =
   EClass: "EClass"  "{"  EClass_Field*  "}" 
  ;

syntax EAnnotation =
   EAnnotation: "EAnnotation"  "{"  EAnnotation_Field*  "}" 
  ;

syntax EStructuralFeature =
  @inject EReference: EReference 
  | @inject EAttribute: EAttribute 
  ;

syntax EAttribute =
   EAttribute: "EAttribute"  "{"  EAttribute_Field*  "}" 
  ;

start syntax EPackage =
   EPackage: "EPackage"  "{"  EPackage_Field*  "}" 
  ;

syntax ETypedElement =
  @inject EStructuralFeature: EStructuralFeature 
  | @inject EParameter: EParameter 
  | @inject EOperation: EOperation 
  ;

syntax EEnumLiteral =
   EEnumLiteral: "EEnumLiteral"  "{"  EEnumLiteral_Field*  "}" 
  ;

syntax EDataType =
  @inject EEnum: EEnum 
  |  EDataType: "EDataType"  "{"  EDataType_Field*  "}" 
  ;

syntax EReference_Field =
   eOpposite: "eOpposite"  ":"  Ref[EReference] 
  |  containment: "containment"  ":"  Bool 
  |  eKeys: "eKeys"  ":"  "["  Ref[EAttribute]*  "]" 
  |  resolveProxies: "resolveProxies"  ":"  Bool 
  ;

syntax EEnum_Field =
   eLiterals: "eLiterals"  ":"  "["  EEnumLiteral*  "]" 
  ;

syntax EFactory =
   EFactory: "EFactory"  "{"  EFactory_Field*  "}" 
  ;

syntax ETypeParameter_Field =
   eBounds: "eBounds"  ":"  "["  EGenericType*  "]" 
  ;

syntax EObject =
   EObject: "EObject"  "{"  EObject_Field*  "}" 
  ;

syntax EDataType_Field =
   serializable: "serializable"  ":"  Bool 
  | @inject EEnum_Field: EEnum_Field 
  ;

syntax EEnumLiteral_Field =
   literal: "literal"  ":"  Str 
  |  \value: "value"  ":"  Int 
  |  instance: "instance"  ":"  "unsupported:EEnumerator" 
  |  eEnum: "eEnum"  ":"  Ref[EEnum] 
  ;

syntax EParameter =
   EParameter: "EParameter"  "{"  EParameter_Field*  "}" 
  ;

syntax EEnum =
   EEnum: "EEnum"  "{"  EEnum_Field*  "}" 
  ;

syntax EClassifier =
  @inject EDataType: EDataType 
  | @inject EClass: EClass 
  ;

syntax EReference =
   EReference: "EReference"  "{"  EReference_Field*  "}" 
  ;
