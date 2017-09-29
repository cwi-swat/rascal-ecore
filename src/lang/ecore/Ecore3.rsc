module lang::ecore::Ecore3

import util::Maybe;
import lang::ecore::Refs;

@eAnnotation=("abstract": "dynamic")
data EClass
  = EClass(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , str \instanceClassName = ""
      , str \instanceTypeName = ""
      , Ref[EPackage] \ePackage = null()
      , list[ETypeParameter] \eTypeParameters = []
      , bool \abstract = false
      , bool \interface = false
      , list[Ref[EClass]] \eSuperTypes = []
      , list[EOperation] \eOperations = []
      , list[EStructuralFeature] \eStructuralFeatures = []
      , list[EGenericType] \eGenericSuperTypes = []
      , Id uid = noId())
  ;

data ETypeParameter
  = ETypeParameter(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , list[EGenericType] \eBounds = []
      , Id uid = noId())
  ;

data ENamedElement
  = ENamedElement(EEnumLiteral \eEnumLiteral, Id uid = \eEnumLiteral.uid, bool _inject = true)
  | ENamedElement(ETypeParameter \eTypeParameter, Id uid = \eTypeParameter.uid, bool _inject = true)
  | ENamedElement(EPackage \ePackage, Id uid = \ePackage.uid, bool _inject = true)
  | ENamedElement(EClassifier \eClassifier, Id uid = \eClassifier.uid, bool _inject = true)
  | ENamedElement(ETypedElement \eTypedElement, Id uid = \eTypedElement.uid, bool _inject = true)
  ;

data EGenericType
  = EGenericType(Maybe[EGenericType] \eUpperBound = nothing()
      , list[EGenericType] \eTypeArguments = []
      , Maybe[EGenericType] \eLowerBound = nothing()
      , Ref[ETypeParameter] \eTypeParameter = null()
      , Ref[EClassifier] \eClassifier = null()
      , Id uid = noId())
  ;

data EOperation
  = EOperation(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , Ref[EClassifier] \eType = null()
      , Maybe[EGenericType] \eGenericType = nothing()
      , Ref[EClass] \eContainingClass = null()
      , list[ETypeParameter] \eTypeParameters = []
      , list[EParameter] \eParameters = []
      , list[Ref[EClassifier]] \eExceptions = []
      , list[EGenericType] \eGenericExceptions = []
      , Id uid = noId())
  ;

data EPackage
  = EPackage(Ref[EFactory] \eFactoryInstance
      , list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , str \nsURI = ""
      , str \nsPrefix = ""
      , list[EClassifier] \eClassifiers = []
      , list[EPackage] \eSubpackages = []
      , Ref[EPackage] \eSuperPackage = null()
      , Id uid = noId())
  ;

data EFactory
  = EFactory(Ref[EPackage] \ePackage
      , list[EAnnotation] \eAnnotations = []
      , Id uid = noId())
  ;

data EModelElement
  = EModelElement(EFactory \eFactory, Id uid = \eFactory.uid, bool _inject = true)
  | EModelElement(ENamedElement \eNamedElement, Id uid = \eNamedElement.uid, bool _inject = true)
  | EModelElement(EAnnotation \eAnnotation, Id uid = \eAnnotation.uid, bool _inject = true)
  ;

data EStringToStringMapEntry
  = EStringToStringMapEntry(str \key = ""
      , str \value = ""
      , Id uid = noId())
  ;

data ETypedElement
  = ETypedElement(EStructuralFeature \eStructuralFeature, Id uid = \eStructuralFeature.uid, bool _inject = true)
  | ETypedElement(EParameter \eParameter, Id uid = \eParameter.uid, bool _inject = true)
  | ETypedElement(EOperation \eOperation, Id uid = \eOperation.uid, bool _inject = true)
  ;

data EAttribute
  = EAttribute(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , Ref[EClassifier] \eType = null()
      , Maybe[EGenericType] \eGenericType = nothing()
      , bool \changeable = false
      , bool \volatile = false
      , bool \transient = false
      , str \defaultValueLiteral = ""
      , bool \unsettable = false
      , bool \derived = false
      , Ref[EClass] \eContainingClass = null()
      , bool \iD = false
      , Id uid = noId())
  ;

data EAnnotation
  = EAnnotation(list[EAnnotation] \eAnnotations = []
      , str \source = ""
      , list[EStringToStringMapEntry] \details = []
      , Ref[EModelElement] \eModelElement = null()
      , list[EObject] \contents = []
      , list[Ref[EObject]] \references = []
      , Id uid = noId())
  ;

data EStructuralFeature
  = EStructuralFeature(EAttribute \eAttribute, Id uid = \eAttribute.uid, bool _inject = true)
  | EStructuralFeature(EReference \eReference, Id uid = \eReference.uid, bool _inject = true)
  ;

data EDataType
  = EDataType(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , str \instanceClassName = ""
      , str \instanceTypeName = ""
      , Ref[EPackage] \ePackage = null()
      , list[ETypeParameter] \eTypeParameters = []
      , bool \serializable = false
      , Id uid = noId())
  | EDataType(EEnum \eEnum, Id uid = \eEnum.uid, bool _inject = true)
  ;

data EEnumLiteral
  = EEnumLiteral(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , int \value = 0
      , tuple[str literal, str name, int \value] \instance = <"", "", 0>
      , str \literal = ""
      , Ref[EEnum] \eEnum = null()
      , Id uid = noId())
  ;

data EClassifier
  = EClassifier(EClass \eClass, Id uid = \eClass.uid, bool _inject = true)
  | EClassifier(EDataType \eDataType, Id uid = \eDataType.uid, bool _inject = true)
  ;

data EReference
  = EReference(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , Ref[EClassifier] \eType = null()
      , Maybe[EGenericType] \eGenericType = nothing()
      , bool \changeable = false
      , bool \volatile = false
      , bool \transient = false
      , str \defaultValueLiteral = ""
      , bool \unsettable = false
      , bool \derived = false
      , Ref[EClass] \eContainingClass = null()
      , bool \containment = false
      , bool \resolveProxies = false
      , Ref[EReference] \eOpposite = null()
      , list[Ref[EAttribute]] \eKeys = []
      , Id uid = noId())
  ;

data EEnum
  = EEnum(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , str \instanceClassName = ""
      , str \instanceTypeName = ""
      , Ref[EPackage] \ePackage = null()
      , list[ETypeParameter] \eTypeParameters = []
      , bool \serializable = false
      , list[EEnumLiteral] \eLiterals = []
      , Id uid = noId())
  ;

data EParameter
  = EParameter(list[EAnnotation] \eAnnotations = []
      , str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , Ref[EClassifier] \eType = null()
      , Maybe[EGenericType] \eGenericType = nothing()
      , Ref[EOperation] \eOperation = null()
      , Id uid = noId())
  ;

data EObject
  = EObject(Id uid = noId())
  ;