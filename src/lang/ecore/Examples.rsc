module lang::ecore::Examples

import lang::ecore::Refs;
import lang::ecore::Diff;
import lang::ecore::Ecore;
import lang::ecore::IO;
import Node;
import IO;

EPackage addFinalState(EPackage fsm) {
  r = newRealm();
  if (/st:EClass("State", _, _) := fsm) {
    c = r.new(#EClassifier, EClass("FinalState", false, false, eSuperTypes=[referTo(#EClassifier, st)]));
    fsm.eClassifiers += [c];
    c2 = r.new(#EClassifier, EClass("Bla", false, false));
    fsm.eClassifiers = [c2] + fsm.eClassifiers; 
  }
  return fsm;
}

private str myFSMecore = "\<?xml version=\"1.0\" encoding=\"ASCII\"?\>
\<ecore:EPackage xmi:version=\"2.0\" xmlns:xmi=\"http://www.omg.org/XMI\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
    xmlns:ecore=\"http://www.eclipse.org/emf/2002/Ecore\" name=\"myFSMAnother\" nsURI=\"http://www.example.org/myFSMAnother\" nsPrefix=\"myFSMAnother\"\>
  \<eClassifiers xsi:type=\"ecore:EClass\" name=\"Machine\"\>
    \<eStructuralFeatures xsi:type=\"ecore:EReference\" name=\"state\" upperBound=\"-1\"
        eType=\"#//State\" containment=\"true\"/\>
  \</eClassifiers\>
  \<eClassifiers xsi:type=\"ecore:EClass\" name=\"State\"\>
    \<eStructuralFeatures xsi:type=\"ecore:EReference\" name=\"trans\" upperBound=\"-1\"
        eType=\"#//Trans\" containment=\"true\"/\>
  \</eClassifiers\>
  \<eClassifiers xsi:type=\"ecore:EClass\" name=\"Trans\"\>
    \<eStructuralFeatures xsi:type=\"ecore:EReference\" name=\"state\" lowerBound=\"1\" eType=\"#//State\"/\>
  \</eClassifiers\>
\</ecore:EPackage\>";

void smokeIt(str project = "rascal-ecore") {
  uri = |project://<project>/myFSMAnother.ecore|;
  // start afresh:
  writeFile(uri, myFSMecore);
  fsm = load(#EPackage, uri);
  println("====== FSM 1 ======");
  iprintln(fsm);
  
  fsm2 = addFinalState(fsm);
  println("\n====== FSM + bla and final ======");
  iprintln(fsm2);
  
  p = diff(#EPackage, fsm, fsm2);
  println("\n====== diff between fsm1 and fsm2 ======");
  iprintln(p);
  
  
  save(fsm2, uri);
  
  fsm3 = load(#EPackage, uri);
  println("\n====== FSM 3 (saved) ======");
  iprintln(fsm3);
  
  p2 = diff(#EPackage, fsm2, fsm3);
  println("\n====== Diff between fsm2 and fsm3 (should be empty) ======");
  iprintln(p2);
  
}


