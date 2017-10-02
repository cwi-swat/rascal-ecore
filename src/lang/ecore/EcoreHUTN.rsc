module lang::ecore::EcoreHUTN

extend lang::ecore::Base;
import util::IDE;
import ParseTree;


syntax EOperation_Field =
   eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  |  eGenericExceptions: "eGenericExceptions"  ":"  "["  EGenericType*  "]" 
  |  eTypeParameters: "eTypeParameters"  ":"  "["  ETypeParameter*  "]" 
  |  eParameters: "eParameters"  ":"  "["  EParameter*  "]" 
  | @inject ETypedElement_Field 
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
  @inject ETypeParameter 
  | @inject ETypedElement 
  | @inject EEnumLiteral 
  | @inject EClassifier 
  | @inject EPackage 
  ;

syntax ETypeParameter =
   ETypeParameter: "ETypeParameter"  "{"  ETypeParameter_Field*  "}" 
  ;

syntax EGenericType =
   EGenericType: "EGenericType"  "{"  EGenericType_Field*  "}" 
  ;

syntax EClass_Field =
   eGenericSuperTypes: "eGenericSuperTypes"  ":"  "["  EGenericType*  "]" 
  |  eOperations: "eOperations"  ":"  "["  EOperation*  "]" 
  |  interface: "interface"  ":"  Bool 
  |  abstract: "abstract"  ":"  Bool 
  |  eStructuralFeatures: "eStructuralFeatures"  ":"  "["  EStructuralFeature*  "]" 
  | @inject EClassifier_Field 
  |  eSuperTypes: "eSuperTypes"  ":"  "["  Ref[EClass]*  "]" 
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
   EOperation: "EOperation"  "{"  EOperation_Field*  "}" 
  ;

syntax EGenericType_Field =
   eUpperBound: "eUpperBound"  ":"  EGenericType 
  |  eClassifier: "eClassifier"  ":"  Ref[EClassifier] 
  |  eLowerBound: "eLowerBound"  ":"  EGenericType 
  |  eTypeArguments: "eTypeArguments"  ":"  "["  EGenericType*  "]" 
  |  eTypeParameter: "eTypeParameter"  ":"  Ref[ETypeParameter] 
  ;

syntax EStringToStringMapEntry =
   EStringToStringMapEntry: "EStringToStringMapEntry"  "{"  EStringToStringMapEntry_Field*  "}" 
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
   key: "key"  ":"  Str 
  |  \value: "value"  ":"  Str 
  ;

syntax EClass =
   EClass: "EClass"  "{"  EClass_Field*  "}" 
  ;

syntax EAttribute_Field =
   iD: "iD"  ":"  Bool 
  | @inject EStructuralFeature_Field 
  ;

syntax ETypedElement_Field =
   unique: "unique"  ":"  Bool 
  |  ordered: "ordered"  ":"  Bool 
  |  eType: "eType"  ":"  Ref[EClassifier] 
  |  lowerBound: "lowerBound"  ":"  Int 
  | @inject ENamedElement_Field 
  |  upperBound: "upperBound"  ":"  Int 
  |  eGenericType: "eGenericType"  ":"  EGenericType 
  ;

syntax EAnnotation =
   EAnnotation: "EAnnotation"  "{"  EAnnotation_Field*  "}" 
  ;

syntax EStructuralFeature =
  @inject EAttribute 
  | @inject EReference 
  ;

syntax EAttribute =
   EAttribute: "EAttribute"  "{"  EAttribute_Field*  "}" 
  ;

start syntax EPackage =
   EPackage: "EPackage"  "{"  EPackage_Field*  "}" 
  ;

syntax ETypedElement =
  @inject EStructuralFeature 
  | @inject EOperation 
  | @inject EParameter 
  ;

syntax EEnumLiteral =
   EEnumLiteral: "EEnumLiteral"  "{"  EEnumLiteral_Field*  "}" 
  ;

syntax EDataType =
   EDataType: "EDataType"  "{"  EDataType_Field*  "}" 
  | @inject EEnum 
  ;

syntax EStructuralFeature_Field =
   unsettable: "unsettable"  ":"  Bool 
  |  derived: "derived"  ":"  Bool 
  |  volatile: "volatile"  ":"  Bool 
  |  eContainingClass: "eContainingClass"  ":"  Ref[EClass] 
  |  defaultValueLiteral: "defaultValueLiteral"  ":"  Str 
  | @inject ETypedElement_Field 
  |  transient: "transient"  ":"  Bool 
  |  changeable: "changeable"  ":"  Bool 
  ;

syntax EAnnotation_Field =
   details: "details"  ":"  "["  EStringToStringMapEntry*  "]" 
  |  eModelElement: "eModelElement"  ":"  Ref[EModelElement] 
  |  source: "source"  ":"  Str 
  | @inject EModelElement_Field 
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
   instanceTypeName: "instanceTypeName"  ":"  Str 
  | @inject ENamedElement_Field 
  |  eTypeParameters: "eTypeParameters"  ":"  "["  ETypeParameter*  "]" 
  |  ePackage: "ePackage"  ":"  Ref[EPackage] 
  |  instanceClassName: "instanceClassName"  ":"  Str 
  ;

syntax EEnum_Field =
  @inject EDataType_Field 
  |  eLiterals: "eLiterals"  ":"  "["  EEnumLiteral*  "]" 
  ;

syntax EFactory =
   EFactory: "EFactory"  "{"  EFactory_Field*  "}" 
  ;

syntax ETypeParameter_Field =
   eBounds: "eBounds"  ":"  "["  EGenericType*  "]" 
  | @inject ENamedElement_Field 
  ;

syntax EObject =
   EObject: "EObject"  "{"  EObject_Field*  "}" 
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
   EParameter: "EParameter"  "{"  EParameter_Field*  "}" 
  ;

syntax EEnum =
   EEnum: "EEnum"  "{"  EEnum_Field*  "}" 
  ;

syntax EClassifier =
  @inject EDataType 
  | @inject EClass 
  ;

syntax EReference =
   EReference: "EReference"  "{"  EReference_Field*  "}" 
  ;

void main() {
  registerLanguage("ecore", "ecore.hutn", start[EPackage](str src, loc org) {
    return parse(#start[EPackage], src, org);
  });
}