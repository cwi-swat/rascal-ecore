module lang::ecore::EcoreHUTN

extend lang::ecore::Base;
import util::IDE;
import ParseTree;


syntax EOperation_Field =
   eExceptions: "eExceptions"  ":"  "["  Ref[EClassifier]*  "]" 
  |  eGenericExceptions: "eGenericExceptions"  ":"  "["  EGenericType*  "]" 
  |  eTypeParameters: "eTypeParameters"  ":"  "["  ETypeParameter*  "]" 
  |  eParameters: "eParameters"  ":"  "["  EParameter*  "]" 
  | @inject ETypedElement_Field 
  |  eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  ;

syntax EPackage_Field =
  @inject ENamedElement_Field 
  |  nsURI: "nsURI"  ":"  Str 
  |  eClassifiers: "eClassifiers"  ":"  "["  EClassifier*  "]" 
  |  eSuperPackage: "eSuperPackage"  ":"  Ref[EPackage] 
  |  eFactoryInstance: "eFactoryInstance"  ":"  Ref[EFactory] 
  |  nsPrefix: "nsPrefix"  ":"  Str 
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
  @Foldable ETypeParameter: "ETypeParameter"  Str name  "{"  ETypeParameter_Field* fields  "}" 
  ;

syntax EGenericType =
  @Foldable EGenericType: "EGenericType"  "{"  EGenericType_Field* fields  "}" 
  ;

syntax EClass_Field =
   eOperations: "eOperations"  ":"  "["  EOperation*  "]" 
  |  interface: "interface"  ":"  Bool 
  |  abstract: "abstract"  ":"  Bool 
  | @inject EClassifier_Field 
  |  eSuperTypes: "eSuperTypes"  ":"  "["  Ref[EClass]*  "]" 
  |  eGenericSuperTypes: "eGenericSuperTypes"  ":"  "["  EGenericType*  "]" 
  |  eStructuralFeatures: "eStructuralFeatures"  ":"  "["  EStructuralFeature*  "]" 
  ;

syntax EFactory_Field =
   ePackage: "ePackage"  ":"  Ref[EPackage] 
  | @inject EModelElement_Field 
  ;

syntax ENamedElement_Field =
  @inject EModelElement_Field 
  |  name: "name"  ":"  Str 
  ;

syntax EOperation =
  @Foldable EOperation: "EOperation"  Str name  "{"  EOperation_Field* fields  "}" 
  ;

syntax EGenericType_Field =
   eUpperBound: "eUpperBound"  ":"  EGenericType 
  |  eClassifier: "eClassifier"  ":"  Ref[EClassifier] 
  |  eLowerBound: "eLowerBound"  ":"  EGenericType 
  |  eTypeArguments: "eTypeArguments"  ":"  "["  EGenericType*  "]" 
  |  eTypeParameter: "eTypeParameter"  ":"  Ref[ETypeParameter] 
  ;

syntax EStringToStringMapEntry =
  @Foldable EStringToStringMapEntry: "EStringToStringMapEntry"  "{"  EStringToStringMapEntry_Field* fields  "}" 
  ;

syntax EModelElement =
  @inject ENamedElement 
  | @inject EFactory 
  | @inject EAnnotation 
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
  @Foldable EClass: "EClass"  Str name  "{"  EClass_Field* fields  "}" 
  ;

syntax EAttribute_Field =
  @inject EStructuralFeature_Field 
  |  iD: "iD"  ":"  Bool 
  ;

syntax ETypedElement_Field =
  @inject ENamedElement_Field 
  |  unique: "unique"  ":"  Bool 
  |  ordered: "ordered"  ":"  Bool 
  |  eType: "eType"  ":"  Ref[EClassifier] 
  |  lowerBound: "lowerBound"  ":"  Int 
  |  upperBound: "upperBound"  ":"  Int 
  |  eGenericType: "eGenericType"  ":"  EGenericType 
  ;

syntax EAnnotation =
  @Foldable EAnnotation: "EAnnotation"  "{"  EAnnotation_Field* fields  "}" 
  ;

syntax EStructuralFeature =
  @inject EAttribute 
  | @inject EReference 
  ;

syntax EAttribute =
  @Foldable EAttribute: "EAttribute"  Str name  "{"  EAttribute_Field* fields  "}" 
  ;

start syntax EPackage =
  @Foldable EPackage: "EPackage"  Str name  "{"  EPackage_Field* fields  "}" 
  ;

syntax ETypedElement =
  @inject EParameter 
  | @inject EOperation 
  | @inject EStructuralFeature 
  ;

syntax EEnumLiteral =
  @Foldable EEnumLiteral: "EEnumLiteral"  Str name  "{"  EEnumLiteral_Field* fields  "}" 
  ;

syntax EDataType =
  @Foldable EDataType: "EDataType"  Str name  "{"  EDataType_Field* fields  "}" 
  | @inject EEnum 
  ;

syntax EStructuralFeature_Field =
   eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  |  derived: "derived"  ":"  Bool 
  |  volatile: "volatile"  ":"  Bool 
  |  defaultValueLiteral: "defaultValueLiteral"  ":"  Str 
  |  unsettable: "unsettable"  ":"  Bool 
  | @inject ETypedElement_Field 
  |  transient: "transient"  ":"  Bool 
  |  changeable: "changeable"  ":"  Bool 
  ;

syntax EAnnotation_Field =
   source: "source"  ":"  Str 
  |  eModelElement: "eModelElement"  ":"  Ref[EModelElement] 
  | @inject EModelElement_Field 
  |  details: "details"  ":"  "["  EStringToStringMapEntry*  "]" 
  |  references: "references"  ":"  "["  Ref[EObject]*  "]" 
  |  contents: "contents"  ":"  "["  EObject*  "]" 
  ;

syntax EReference_Field =
  @inject EStructuralFeature_Field 
  |  containment: "containment"  ":"  Bool 
  |  eKeys: "eKeys"  ":"  "["  Ref[EAttribute]*  "]" 
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
  @inject EDataType_Field 
  |  eLiterals: "eLiterals"  ":"  "["  EEnumLiteral*  "]" 
  ;

syntax EFactory =
  @Foldable EFactory: "EFactory"  "{"  EFactory_Field* fields  "}" 
  ;

syntax ETypeParameter_Field =
   eBounds: "eBounds"  ":"  "["  EGenericType*  "]" 
  | @inject ENamedElement_Field 
  ;

syntax EObject =
  @Foldable EObject: "EObject"  "{"  EObject_Field* fields  "}" 
  ;

syntax EDataType_Field =
  @inject EClassifier_Field 
  |  serializable: "serializable"  ":"  Bool 
  ;

syntax EEnumLiteral_Field =
   eEnum: "eEnum"  ":"  Ref[EEnum] 
  | @inject ENamedElement_Field 
  |  \value: "value"  ":"  Int 
  |  instance: "instance"  ":"  "unsupported:EEnumerator" 
  |  literal: "literal"  ":"  Str 
  ;

syntax EParameter =
  @Foldable EParameter: "EParameter"  Str name  "{"  EParameter_Field* fields  "}" 
  ;

syntax EEnum =
  @Foldable EEnum: "EEnum"  Str name  "{"  EEnum_Field* fields  "}" 
  ;

syntax EClassifier =
  @inject EClass 
  | @inject EDataType 
  ;

syntax EReference =
  @Foldable EReference: "EReference"  Str name  "{"  EReference_Field* fields  "}" 
  ;

void main() {
  registerLanguage("ecore", "ecore_hutn", start[EPackage](str src, loc org) {
    return parse(#start[EPackage], src, org);
  });
}