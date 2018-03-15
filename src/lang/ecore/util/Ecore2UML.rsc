module lang::ecore::util::Ecore2UML

import salix::lib::UML;

import lang::ecore::Ecore;
import lang::ecore::EcoreUtil;
import lang::ecore::Refs;
import salix::App;
import salix::Core;
import salix::HTML;

import IO;

App[EPackage] ecoreApp(EPackage pkg) 
  = app(EPackage() { return pkg; }, 
      view, update, |http://localhost:9120/index.html|, |project://salix/src|); 
    
EPackage update(Msg msg, EPackage m) = m;


private void view(EPackage m) {
  div(() {
    h2("Meta model <m.name>");
    div(uml2svgNode(ecore2plantUML(m)));
  });
}

private str ecore2plantUML(EPackage m) {
  str s = "@startuml\n";

  for (EClassifier(EClass sub) <- m.eClassifiers) {
    if (sub.abstract) {
      s += "abstract ";
    }
    s += "class <sub.name> {\n";
    for (EStructuralFeature(EAttribute attr) <- sub.eStructuralFeatures, attr.eType != null(),
        !attr.transient, !attr.derived) {
      s += "  <attr.name>: <lookupClassifier(m, attr.eType).name>\n";
    }
    s += "}\n";
    s += "hide <sub.name> methods\n";
    
    for (EStructuralFeature(EReference ref) <- sub.eStructuralFeatures, 
         !ref.transient, !ref.derived) {
      s += "<sub.name> <ref.containment ? "*" : "">--<ref.containment ? "" : "\>"> <lookupClassifier(m, ref.eType).name> : <ref.name>\n";
    }
    
  }
  
  for (EClassifier(EDataType(EEnum enum)) <- m.eClassifiers) {
    s += "enum <enum.name> {\n";
    for (EEnumLiteral c <- enum.eLiterals) {
      s += "<c.name>\n";
    }
    s += "}\n";
  }
  
  
  for (EClassifier(EClass sub) <- m.eClassifiers) {
    for (Ref[EClass] r <- sub.eSuperTypes, EClass sup := lookup(m, #EClass, r)) {
      s += "<sup.name> \<|-- <sub.name>\n";
    }
  }
  
  
  s += "@enduml\n";
  return s;
}
