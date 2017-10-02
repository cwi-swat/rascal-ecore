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
   eClassifiers: "eClassifiers"  ":"  "["  EClassifier*  "]" 
  |  nsURI: "nsURI"  ":"  Str 
  |  eSuperPackage: "eSuperPackage"  ":"  Ref[EPackage] 
  |  eFactoryInstance: "eFactoryInstance"  ":"  Ref[EFactory] 
  |  nsPrefix: "nsPrefix"  ":"  Str 
  | @inject ENamedElement_Field 
  |  eSubpackages: "eSubpackages"  ":"  "["  EPackage*  "]" 
  ;

syntax ENamedElement =
  @inject ETypedElement 
  | @inject ETypeParameter 
  | @inject EEnumLiteral 
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
   interface: "interface"  ":"  Bool 
  |  eOperations: "eOperations"  ":"  "["  EOperation*  "]" 
  |  abstract: "abstract"  ":"  Bool 
  | @inject EClassifier_Field 
  |  eSuperTypes: "eSuperTypes"  ":"  "["  Ref[EClass]*  "]" 
  |  eGenericSuperTypes: "eGenericSuperTypes"  ":"  "["  EGenericType*  "]" 
  |  eStructuralFeatures: "eStructuralFeatures"  ":"  "["  EStructuralFeature*  "]" 
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
   eTypeArguments: "eTypeArguments"  ":"  "["  EGenericType*  "]" 
  |  eClassifier: "eClassifier"  ":"  Ref[EClassifier] 
  |  eLowerBound: "eLowerBound"  ":"  EGenericType 
  |  eUpperBound: "eUpperBound"  ":"  EGenericType 
  |  eTypeParameter: "eTypeParameter"  ":"  Ref[ETypeParameter] 
  ;

syntax EStringToStringMapEntry =
  @Foldable EStringToStringMapEntry: "EStringToStringMapEntry"  "{"  EStringToStringMapEntry_Field*  "}" 
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
   key: "key"  ":"  Str 
  |  \value: "value"  ":"  Str 
  ;

syntax EClass =
  @Foldable EClass: "EClass"  "{"  EClass_Field*  "}" 
  ;

syntax EAttribute_Field =
   iD: "iD"  ":"  Bool 
  | @inject EStructuralFeature_Field 
  ;

syntax ETypedElement_Field =
   eGenericType: "eGenericType"  ":"  EGenericType 
  |  unique: "unique"  ":"  Bool 
  |  ordered: "ordered"  ":"  Bool 
  |  eType: "eType"  ":"  Ref[EClassifier] 
  |  lowerBound: "lowerBound"  ":"  Int 
  | @inject ENamedElement_Field 
  |  upperBound: "upperBound"  ":"  Int 
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
  @inject EParameter 
  | @inject EOperation 
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
  @inject ETypedElement_Field 
  |  derived: "derived"  ":"  Bool 
  |  volatile: "volatile"  ":"  Bool 
  |  eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  |  defaultValueLiteral: "defaultValueLiteral"  ":"  Str 
  |  unsettable: "unsettable"  ":"  Bool 
  |  transient: "transient"  ":"  Bool 
  |  changeable: "changeable"  ":"  Bool 
  ;

syntax EAnnotation_Field =
  @inject EModelElement_Field 
  |  eModelElement: "eModelElement"  ":"  Ref[EModelElement] 
  |  source: "source"  ":"  Str 
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
  @inject ENamedElement_Field 
  |  instanceTypeName: "instanceTypeName"  ":"  Str 
  |  eTypeParameters: "eTypeParameters"  ":"  "["  ETypeParameter*  "]" 
  |  ePackage: "ePackage"  ":"  Ref[EPackage] 
  |  instanceClassName: "instanceClassName"  ":"  Str 
  ;

syntax EEnum_Field =
  @inject EDataType_Field 
  |  eLiterals: "eLiterals"  ":"  "["  EEnumLiteral*  "]" 
  ;

syntax EFactory =
  @Foldable EFactory: "EFactory"  "{"  EFactory_Field*  "}" 
  ;

syntax ETypeParameter_Field =
  @inject ENamedElement_Field 
  |  eBounds: "eBounds"  ":"  "["  EGenericType*  "]" 
  ;

syntax EObject =
  @Foldable EObject: "EObject"  "{"  EObject_Field*  "}" 
  ;

syntax EDataType_Field =
  @inject EClassifier_Field 
  |  serializable: "serializable"  ":"  Bool 
  ;

syntax EEnumLiteral_Field =
   literal: "literal"  ":"  Str 
  | @inject ENamedElement_Field 
  |  \value: "value"  ":"  Int 
  |  instance: "instance"  ":"  "unsupported:EEnumerator" 
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