module lang::ecore::EcoreUtil

import lang::ecore::Ecore;
import lang::ecore::Refs;

EPackage flattenInheritance(Realm realm, EPackage mm) {
  EClass flattenClass(EClass t) {
    supers = [ flattenClass(lookup(mm, #EClass, sup)) | sup <- t.eSuperTypes ]; 
    t.eStructuralFeatures  
      = [ EStructuralFeature(realm.new(#EAttribute, f)) | s <- supers, EStructuralFeature(EAttribute f) <- s.eStructuralFeatures ]
      + [ EStructuralFeature(realm.new(#EReference, f)) | s <- supers, EStructuralFeature(EReference f) <- s.eStructuralFeatures ]
      + t.eStructuralFeatures; 
   return t;
 }
 
 EClassifier flatten(EClassifier(EClass c)) = EClassifier(flattenClass(c));
 default EClassifier flatten(EClassifier c) = c; 

 mm.eClassifiers = [ flatten(c) | EClassifier c <- mm.eClassifiers ];
 return mm;
}

list[EClass] directSubclassesOf(EClass class, EPackage pkg) 
  = [ sub | EClassifier(EClass sub) <- pkg.eClassifiers, sup <- sub.eSuperTypes, lookup(pkg, #EClass, sup) == class ];

bool isRequired(EStructuralFeature f) = f.lowerBound >= 1;

bool isMany(EStructuralFeature f) = f.upperBound > 1 || f.upperBound == -1;

