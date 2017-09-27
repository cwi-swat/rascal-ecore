module lang::ecore::EcoreHUTN

extend lang::ecore::Base;


start syntax EPackage
  = "EPackage" "{" EPackageField* "}" ;

syntax EPackageField
  = "nsURI" ":" Str
  | "nsPrefix" ":" Str
  | "eClassifiers" ":" "[" EClassifier* "]"
  | "eSubpackages" ":" "[" EPackage* "]"
  | ENamedElementField
  ;

syntax EModelElement
  = ENamedElement
  | EAnnotation
  ;
  
syntax EModelElementField
  = "eAnnotations" ":" "[" EAnnotation* "]"
  ;

syntax ENamedElement
  = ETypedElement
  | EClassifier
  | EPackage
  | EEnumeLiteral
  | EDataType
  ;
  
syntax ENamedElementField
  = "name" ":" Str
  | EModelElementField
  ;
  
syntax ETypedElementField
  = "ordered" ":" Bool
  | "unique" ":" Bool
  | "lowerBound" ":" Int
  | "upperBound" ":" Int
  | "many" ":" Bool
  | "required" ":" Bool
  | "eType" ":" Ref[EClassifier]
  | ENamedElementField
  ;

syntax ETypedElement
  = EOperation
  | EParameter
  | EStructuralFeature
  ;

syntax EClassifier
  = EDataType
  | EClass
  ;
  
syntax EClassifierField
  = ENamedElementField
  ;  
  
syntax EClass
  = "EClass" "{" EClassField* "}"
  ;
  
syntax EClassField
  = "abstract" ":" Bool
  | "interface" ":" Bool
  | "eStructuralFeatures" ":" "[" EStructuralFeature* "]"
  | "eOperations" ":" "[" EOperation* "]"
  | "eSuperTypes" ":" "[" Ref[EClass]* "]"
  | EClassifierField
  ;
    
syntax EDataType
  = "EDataType" "{" EDataTypeField* "}"
  | EEnum
  ;

syntax EDataTypeField
  = "serializable" ":" Bool
  | EClassifierField
  ;
  
syntax EEnum
  = "EENum" "{" EENumField* "}"
  ;
  
syntax EEnumField
  = "eLiterals" ":" "[" EEnumLiteral* "]"
  | EDataTypeField;
  
syntax EEnumLiteral
  = "EEnumLiteral" "{" EEnumLiteralField* "}"
  ;
  
syntax EEnumLiteralField
  = "value" ":" Int
  | ENamedElementField
  ;    
  
syntax EStructuralFeature
  = EReference
  | EAttribute
  ;
  
syntax EStructuralFeatureField
  = "changeable" ":" Bool
  | "unsettable" ":" Bool
  | "derived" ":" Bool
  | ETypedElementField
  ;
  
syntax EReference
  = "EReference" "{" EReferenceField* "}"
  ;  
  
syntax EReferenceField
  = "containment" ":" Bool
  | "container" ":" Bool
  | "resolveProxies" ":" Bool
  | "eOpposite" ":" Ref[EReference]
  | "eReferenceType" ":" Ref[EClass]
  | EStructuralFeatureField
  ;

syntax EAttribute
  = "EAttribute" "{" EAttributeField* "}"
  ;

syntax EAttributeField
  = "iD" ":" Bool
  | EStructuralFeatureField
  ;  
  
syntax EOperation
  = "EOperation" "{" EOperationField* "}"
  ;
  
syntax EOperationField
  = ETypedElementField
  | "eExceptions" ":" "[" Ref[EClass] "]"
  | "eParameters" ":" "[" EParameter* "]"
  ;
  
syntax EParameter
  = "EParameter" "{" EParameterField* "}"
  ;
  
syntax EParameterField
  = ETypedElementField
  ;
  
syntax EAnnotation
  = "EAnnotation" "{" EAnnotationField* "}"
  ;
  
syntax EAnnotationField
  = "source" ":" String
  | "details" ":" EStringToMapEntry
  | EModelElementField
  ;
  
syntax EStringToMapEntry
  = "EStringToMapEntry" "{" EStringToMapEntryField* "}"
  ;
  
syntax EStringToMapEntryField
  = "key" ":" Str
  | "value" ":" Str
  ;
  
  
