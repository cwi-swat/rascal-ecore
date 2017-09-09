module lang::ecore::Examples

import lang::ecore::Refs;
import lang::ecore::Diff;
import lang::ecore::Ecore;

EPackage addFinalState(EPackage fsm) {
  r = newRealm();
  if (/st:eClass("State", _, _) := fsm) {
    c = r.new(#EClassifier, eClass("FinalState", false, false, eSuperTypes=[referTo(#EClassifier, st)]));
    fsm.eClassifiers += [c];
  }
  return fsm;
}