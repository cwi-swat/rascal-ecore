module lang::ecore::Ecore2ADT

import lang::ecore::Ecore3;
import lang::ecore::Refs;
import lang::ecore::IO;
import IO;
import ValueIO;
import Type;
import List;
import String;
import analysis::graphs::Graph;

// TODO: annotations

//writeEcoreADTModule("lang::ecore::Ecore3", |project://rascal-ecore/src/lang/ecore/Ecore3.rsc|, ec);

void writeEcoreEcore() {
  ec = load(#EPackage, |file:///Users/tvdstorm/CWI/rascal-ecore/src/lang/ecore/Ecore.ecore|);
  writeEcoreADTModule("lang::ecore::Ecore3", |project://rascal-ecore/src/lang/ecore/Ecore4.rsc|, ec);
}

void writeEcoreADTModule(str moduleName, loc l, EPackage pkg) 
  = writeFile(l, "module <moduleName>
                 '
                 'import util::Maybe;
                 'import lang::ecore::Refs;
                 '
                 '<ecore2rsc(flattenInheritance(newRealm(), pkg))>");

str ecore2rsc(EPackage pkg) 
  = intercalate("\n\n", [ choice2rsc(defs[s]) | Symbol s <- orderADTs(defs) ])
  when 
    defs := package2definitions(pkg);

list[Symbol] orderADTs(map[Symbol, Production] defs) {
  deps = { <s1, s2> | s1 <- defs, /s2:adt(str x, _) := defs[s1], x != "Ref", x != "Id", x != "Maybe" };
  return reverse(order(deps));
}


str choice2rsc(choice(Symbol a, set[Production] alts)) 
  = "data <a.name>\n  = <intercalate("\n  | ", [ prod2rsc(p) | Production p <- alts ])>
    '  ;";

str prod2rsc(cons(label(str c, _), [label(str x, adt(str sub, []))], 
      [*subs, label("uid", adt("Id", [])), label("_inject", \bool())], _))
  = "<c>(<intercalate("\n      , ", args)>)"
  when fieldName(sub) == x,
    args := [
      "<sub> <x>",
      *[ default4sub(s, x) | s <- subs ],
      "Id uid = <x>.uid",
      "bool _inject = true"
    ];

str default4sub(label(str fld, Symbol s), str kid)
  = "<sym2rsc(s)> <fld> = <kid>.<fld>";

default str prod2rsc(cons(label(str c, _), list[Symbol] ps, list[Symbol] kws, _))
  = "<c>(<intercalate("\n      , ", args)>)"
  when
    list[str] args := [ param2rsc(p) | p <- ps ] + [ kwp2rsc(k) | k <- kws ];
    
str param2rsc(label(str name, Symbol s)) = "<sym2rsc(s)> <name>";

str kwp2rsc(label(str name, Symbol s)) = "<sym2rsc(s)> <name> = <default4sym(s)>";

str sym2rsc(\int()) = "int";

str sym2rsc(\bool()) = "bool";

str sym2rsc(\real()) = "real";

str sym2rsc(\str()) = "str";

str sym2rsc(\datetime()) = "datetime";

str sym2rsc(\list(Symbol s)) = "list[<sym2rsc(s)>]";

str sym2rsc(\tuple(list[Symbol] ss)) = "tuple[<intercalate(", ", [ sym2rsc(s) | s <- ss])>]";

str sym2rsc(label(str n, Symbol s)) = "<sym2rsc(s)> <n>";

str sym2rsc(adt(str n, list[Symbol] ps)) 
  = "<n><ps != [] ? "[" + intercalate(", ", [ sym2rsc(p) | p <- ps ]) + "]" : "">";
  
str default4sym(\int()) = "0";

str default4sym(\bool()) = "false";

str default4sym(\real()) = "0.0";

str default4sym(\str()) = "\"\"";

str default4sym(\datetime()) = "$2017-09-27T23:23:51.343+00:00$"; // ???

str default4sym(\list(Symbol s)) = "[]";

str default4sym(\label(str _, Symbol s)) = default4sym(s);

str default4sym(\tuple(list[Symbol] ss)) 
  = "\<<intercalate(", ", [ default4sym(s) | s <- ss])>\>";

str default4sym(adt("Ref", list[Symbol] ps)) 
  = "null()";

str default4sym(adt("Id", list[Symbol] ps)) 
  = "noId()";

str default4sym(adt("Maybe", list[Symbol] ps)) 
  = "nothing()";

str default4sym(adt(str x, list[Symbol] ps))  { throw "No default for ADT <x> we don\'t know"; }



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

Symbol type2symbol(Ref[EClassifier] typeRef, EPackage pkg, bool xref, bool req, bool many) 
  = classifier2symbol(lookup(pkg, #EClassifier, typeRef), xref, req, many);
  
Symbol classifier2symbol(EClassifier(EDataType(name = str name)), bool xref, bool req, bool many) = prim2symbol(name);

Symbol classifier2symbol(EClassifier(EClass(name = str name)), bool xref, bool req, bool many) 
  = xref ? adt("Ref", [adt(name, [])]) : ((req || many) ? adt(name, []) : adt("Maybe", [adt(name, [])]));

Symbol classifier2symbol(EClassifier(EEnum(name = str name)), bool xref, bool req, bool many) = adt(name, []);

Symbol prim2symbol("EBigDecimal") = \real();
Symbol prim2symbol("EDouble") = \real();
Symbol prim2symbol("EFloat") = \real();
Symbol prim2symbol("EBigInteger") = \int();
Symbol prim2symbol("EByte") = \int();
Symbol prim2symbol("EShort") = \int();
Symbol prim2symbol("EInt") = \int();
Symbol prim2symbol("ELong") = \int();
Symbol prim2symbol("EBoolean") = \bool();
Symbol prim2symbol("EString") = \str();
Symbol prim2symbol("EDate") = \datetime();
Symbol prim2symbol("EEnumerator") = \tuple([label("literal", \str()), label("name", \str()), label("\\value", \int())]);
default Symbol prim2symbol(str d) { throw "Unsupported primitive <d>"; }


Symbol feature2symbol(EAttribute f, EClass c, EPackage pkg, bool req) {
  Symbol t = type2symbol(f.eType, pkg, f has containment ==> !f.containment, req, isMany(f));
  return isMany(f) ? \list(t) : t;
}

Symbol feature2symbol(EReference f, EClass c, EPackage pkg, bool req) {
  Symbol t = type2symbol(f.eType, pkg, f has containment ==> !f.containment, req, isMany(f));
  return isMany(f) ? \list(t) : t;
}

Symbol feature2arg(EStructuralFeature(EAttribute f), EClass c, EPackage pkg, bool req) 
  = label(fieldName(f.name), feature2symbol(f, c, pkg, req));

Symbol feature2arg(EStructuralFeature(EReference f), EClass c, EPackage pkg, bool req) 
  = label(fieldName(f.name), feature2symbol(f, c, pkg, req));


bool isRequired(EStructuralFeature(EAttribute f)) = (f.lowerBound == 1 && f.upperBound >= 1);
bool isRequired(EStructuralFeature(EReference f)) = (f.lowerBound == 1 && f.upperBound >= 1);

bool isDerived(EStructuralFeature(EAttribute f)) = f.derived;
bool isDerived(EStructuralFeature(EReference f)) = f.derived;

bool isMany(EAttribute f) = f.upperBound > 1 || f.upperBound == -1;
bool isMany(EReference f) = f.upperBound > 1 || f.upperBound == -1;


Production class2prod(EClass class, EPackage pkg) {
  // assumes flattened inheritance
  
  ps =  [ feature2arg(f, class, pkg, true) | f <- class.eStructuralFeatures, isRequired(f), !isDerived(f) ];
  kws = [ feature2arg(f, class, pkg, false) | f <- class.eStructuralFeatures, !isRequired(f), !isDerived(f) ]
    + [ label("uid", adt("Id", [])) ];
  return cons(label(class.name, adt(class.name, [])), ps, kws, {});
}

Production classifier2choice(EClassifier(EClass class), EPackage pkg) {
  Symbol a = adt(class.name, []);
  set[Production] alts = { class2prod(class, pkg) | !class.abstract }
    + { cons(label(class.name, a), [label(fieldName(sub.name), adt(sub.name, []))], 
          [ feature2arg(f, sub, pkg, true)  | f <- sub.eStructuralFeatures, !isDerived(f) ]
          + [label("uid", adt("Id", [])), label("_inject", \bool())]
          , {})  
          | EClass sub <- directSubclassesOf(class, pkg) };
  return choice(a, alts);
}

str fieldName(str x) = "\\<uncapitalize(x)>";

Production classifier2choice(EClassifier(EDataType(EEnum enum)), EPackage pkg) {
  Symbol a = adt(enum.name, []);
  set[Production] alts = { cons(label(el.name, a), [], [], {}) | el <- enum.eLiterals };
  return choice(a, alts);
}

map[Symbol, Production] package2definitions(EPackage pkg) 
  = ( p.def: p | EClassifier c <- pkg.eClassifiers, EClassifier(EDataType _) !:= c, p := classifier2choice(c, pkg) );
  


//void flattenSamples() {
//  ecores = |file:///Users/tvdstorm/CWI/rascal-ecore/src/lang/ecore/samples|.ls;
//  for (loc e <- ecores) {
//    try {
//      EPackage pkg = load(#EPackage, e);
//      println("Successfully loaded <e>");
//      flattenInheritance(newRealm(), pkg);
//      println("Successfully flattenend <e>");
//    }
//    catch value x: {
//      println("Exception: <x> for <e>"); 
//    }
//  }
//}
