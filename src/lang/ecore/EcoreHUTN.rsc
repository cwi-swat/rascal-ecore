module lang::ecore::EcoreHUTN

extend lang::ecore::Base;
import util::IDE;
import ParseTree;


syntax EOperation_Field =
   eTypeParameters: "eTypeParameters"  ":"  "["  ETypeParameter*  "]" 
  |  eGenericExceptions: "eGenericExceptions"  ":"  "["  EGenericType*  "]" 
  |  eParameters: "eParameters"  ":"  "["  EParameter*  "]" 
  | @inject ETypedElement_Field 
  |  eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  |  eExceptions: "eExceptions"  ":"  "["  Ref[EClassifier]*  "]" 
  ;

syntax EPackage_Field =
   nsURI: "nsURI"  ":"  Str 
  |  eClassifiers: "eClassifiers"  ":"  "["  EClassifier*  "]" 
  |  eSuperPackage: "eSuperPackage"  ":"  Ref[EPackage] 
  |  eFactoryInstance: "eFactoryInstance"  ":"  Ref[EFactory] 
  |  nsPrefix: "nsPrefix"  ":"  Str 
  | @inject ENamedElement_Field 
  |  eSubpackages: "eSubpackages"  ":"  "["  EPackage*  "]" 
  ;

syntax ENamedElement =
  @inject EEnumLiteral 
  | @inject ETypeParameter 
  | @inject ETypedElement 
  | @inject EClassifier 
  | @inject EPackage 
  ;

syntax ETypeParameter =
  @Foldable ETypeParameter: "ETypeParameter"  "{"  ETypeParameter_Field*  "}" 
  ;

syntax EGenericType =
  @Foldable EGenericType: "EGenericType"  "{"  EGenericType_Field*  "}" 
  ;

syntax EClass_Field =
   eStructuralFeatures: "eStructuralFeatures"  ":"  "["  EStructuralFeature*  "]" 
  |  eOperations: "eOperations"  ":"  "["  EOperation*  "]" 
  |  interface: "interface"  ":"  Bool 
  |  abstract: "abstract"  ":"  Bool 
  |  eGenericSuperTypes: "eGenericSuperTypes"  ":"  "["  EGenericType*  "]" 
  | @inject EClassifier_Field 
  |  eSuperTypes: "eSuperTypes"  ":"  "["  Ref[EClass]*  "]" 
  ;

syntax EFactory_Field =
  @inject EModelElement_Field 
  |  ePackage: "ePackage"  ":"  Ref[EPackage] 
  ;

syntax ENamedElement_Field =
   name: "name"  ":"  Str 
  | @inject EModelElement_Field 
  ;

syntax EOperation =
  @Foldable EOperation: "EOperation"  "{"  EOperation_Field*  "}" 
  ;

syntax EGenericType_Field =
   eTypeParameter: "eTypeParameter"  ":"  Ref[ETypeParameter] 
  |  eClassifier: "eClassifier"  ":"  Ref[EClassifier] 
  |  eLowerBound: "eLowerBound"  ":"  EGenericType 
  |  eUpperBound: "eUpperBound"  ":"  EGenericType 
  |  eTypeArguments: "eTypeArguments"  ":"  "["  EGenericType*  "]" 
  ;

syntax EStringToStringMapEntry =
  @Foldable EStringToStringMapEntry: "EStringToStringMapEntry"  "{"  EStringToStringMapEntry_Field*  "}" 
  ;

syntax EModelElement =
  @inject EAnnotation 
  | @inject ENamedElement 
  | @inject EFactory 
  ;

syntax EParameter_Field =
  @inject ETypedElement_Field 
  |  eOperation: "eOperation"  ":"  Ref[EOperation] 
  ;

syntax EObject_Field =
  ...
  ;

syntax EModelElement_Field =
   eAnnotations: "eAnnotations"  ":"  "["  EAnnotation*  "]" 
  ;

syntax EStringToStringMapEntry_Field =
   \value: "value"  ":"  Str 
  |  key: "key"  ":"  Str 
  ;

syntax EClass =
  @Foldable EClass: "EClass"  "{"  EClass_Field*  "}" 
  ;

syntax EAttribute_Field =
   iD: "iD"  ":"  Bool 
  | @inject EStructuralFeature_Field 
  ;

syntax ETypedElement_Field =
   upperBound: "upperBound"  ":"  Int 
  |  unique: "unique"  ":"  Bool 
  |  ordered: "ordered"  ":"  Bool 
  |  eType: "eType"  ":"  Ref[EClassifier] 
  |  lowerBound: "lowerBound"  ":"  Int 
  | @inject ENamedElement_Field 
  |  eGenericType: "eGenericType"  ":"  EGenericType 
  ;

syntax EAnnotation =
  @Foldable EAnnotation: "EAnnotation"  "{"  EAnnotation_Field*  "}" 
  ;

syntax EStructuralFeature =
  @inject EReference 
  | @inject EAttribute 
  ;

syntax EAttribute =
  @Foldable EAttribute: "EAttribute"  "{"  EAttribute_Field*  "}" 
  ;

start syntax EPackage =
  @Foldable EPackage: "EPackage"  "{"  EPackage_Field*  "}" 
  ;

syntax ETypedElement =
  @inject EOperation 
  | @inject EParameter 
  | @inject EStructuralFeature 
  ;

syntax EEnumLiteral =
  @Foldable EEnumLiteral: "EEnumLiteral"  "{"  EEnumLiteral_Field*  "}" 
  ;

syntax EDataType =
  @Foldable EDataType: "EDataType"  "{"  EDataType_Field*  "}" 
  | @inject EEnum 
  ;

syntax EStructuralFeature_Field =
   derived: "derived"  ":"  Bool 
  |  volatile: "volatile"  ":"  Bool 
  |  eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  |  defaultValueLiteral: "defaultValueLiteral"  ":"  Str 
  |  unsettable: "unsettable"  ":"  Bool 
  | @inject ETypedElement_Field 
  |  transient: "transient"  ":"  Bool 
  |  changeable: "changeable"  ":"  Bool 
  ;

syntax EAnnotation_Field =
   eModelElement: "eModelElement"  ":"  Ref[EModelElement] 
  |  source: "source"  ":"  Str 
  | @inject EModelElement_Field 
  |  details: "details"  ":"  "["  EStringToStringMapEntry*  "]" 
  |  references: "references"  ":"  "["  Ref[EObject]*  "]" 
  |  contents: "contents"  ":"  "["  EObject*  "]" 
  ;

syntax EReference_Field =
   eKeys: "eKeys"  ":"  "["  Ref[EAttribute]*  "]" 
  |  containment: "containment"  ":"  Bool 
  | @inject EStructuralFeature_Field 
  |  resolveProxies: "resolveProxies"  ":"  Bool 
  |  eOpposite: "eOpposite"  ":"  Ref[EReference] 
  ;

syntax EClassifier_Field =
   ePackage: "ePackage"  ":"  Ref[EPackage] 
  |  eTypeParameters: "eTypeParameters"  ":"  "["  ETypeParameter*  "]" 
  |  instanceClassName: "instanceClassName"  ":"  Str 
  | @inject ENamedElement_Field 
  |  instanceTypeName: "instanceTypeName"  ":"  Str 
  ;

syntax EEnum_Field =
   eLiterals: "eLiterals"  ":"  "["  EEnumLiteral*  "]" 
  | @inject EDataType_Field 
  ;

syntax EFactory =
  @Foldable EFactory: "EFactory"  "{"  EFactory_Field*  "}" 
  ;

syntax ETypeParameter_Field =
   eBounds: "eBounds"  ":"  "["  EGenericType*  "]" 
  | @inject ENamedElement_Field 
  ;

syntax EObject =
  @Foldable EObject: "EObject"  "{"  EObject_Field*  "}" 
  ;

syntax EDataType_Field =
  @inject EClassifier_Field 
  |  serializable: "serializable"  ":"  Bool 
  ;

syntax EEnumLiteral_Field =
  @inject ENamedElement_Field 
  |  \value: "value"  ":"  Int 
  |  instance: "instance"  ":"  "unsupported:EEnumerator" 
  |  literal: "literal"  ":"  Str 
  |  eEnum: "eEnum"  ":"  Ref[EEnum] 
  ;

syntax EParameter =
  @Foldable EParameter: "EParameter"  "{"  EParameter_Field*  "}" 
  ;

syntax EEnum =
  @Foldable EEnum: "EEnum"  "{"  EEnum_Field*  "}" 
  ;

syntax EClassifier =
  @inject EClass 
  | @inject EDataType 
  ;

syntax EReference =
  @Foldable EReference: "EReference"  "{"  EReference_Field*  "}" 
  ;

void main() {
  registerLanguage("ecore", "ecore.hutn", start[EPackage](str src, loc org) {
    return parse(#start[EPackage], src, org);
  });
}