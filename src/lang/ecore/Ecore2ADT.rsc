module lang::ecore::Ecore2ADT

import lang::ecore::Ecore;
import lang::ecore::Refs;
import lang::ecore::IO;
import IO;
import Type;
import List;
import String;


str ecore2rsc(EPackage pkg) 
  = intercalate("\n\n", [ choice2rsc(defs[s]) | Symbol s <- defs ])
  when 
    defs := package2definitions(pkg);

str choice2rsc(choice(Symbol a, set[Production] alts)) 
  = "data <a.name>\n  = <intercalate("\n  | ", [ prod2rsc(p) | Production p <- alts ])>
    '  ;";

str prod2rsc(cons(label(str c, _), [label(str x, adt(str sub, []))], [label("uid", adt("Id", []))], _))
  = "<c>(<sub> <x>, Id uid = <x>.uid)"
  when fieldName(sub) == x;

default str prod2rsc(cons(label(str c, _), list[Symbol] ps, list[Symbol] kws, _))
  = "<c>(<intercalate(", ", args)>)"
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
  EClassifier flatten(EClassifier t) {
    if (!(t is EClass)) { 
      return t;
    }
    supers = [ flatten(lookup(mm, #EClassifier, sup)) | sup <- t.eSuperTypes ]; 
    t.eStructuralFeatures = [ realm.new(#EStructuralFeature, f) | s <- supers, f <- s.eStructuralFeatures ] 
          + t.eStructuralFeatures; 
   return t;
 }
 
 mm.eClassifiers = [ flatten(c) | c <- mm.eClassifiers ];
 return mm;
}

list[EClassifier] directSubclassesOf(EClassifier class, EPackage pkg) 
  = [ sub | sub:EClass(_, _, _) <- pkg.eClassifiers, sup <- sub.eSuperTypes, lookup(pkg, #EClassifier, sup) == class ];

Symbol type2symbol(Ref[EClassifier] typeRef, EPackage pkg, bool xref, bool req, bool many) 
  = classifier2symbol(lookup(pkg, #EClassifier, typeRef), xref, req, many);
  
Symbol classifier2symbol(EDataType(str name), bool xref, bool req, bool many) = prim2symbol(name);

Symbol classifier2symbol(EClass(str name, _, _), bool xref, bool req, bool many) 
  = xref ? adt("Ref", [adt(name, [])]) : ((req || many) ? adt(name, []) : adt("Maybe", [adt(name, [])]));

Symbol classifier2symbol(EEnum(str name, _, _), bool xref, bool req, bool many) = adt(name, []);

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
Symbol prim2symbol("EEnumerator") = \tuple([label("literal", \str()), label("name", \str()), label("value", \int())]);
default Symbol prim2symbol(str d) { throw "Unsupported primitive <d>"; }


Symbol feature2symbol(EStructuralFeature f, EClassifier c, EPackage pkg, bool req) {
  Symbol t = type2symbol(f.eType, pkg, f has containment ==> !f.containment, req, f.many);
  return f.many ? \list(t) : t;
}

Symbol feature2arg(EStructuralFeature f, EClassifier c, EPackage pkg, bool req) 
  = label(fieldName(f.name), feature2symbol(f, c, pkg, req));

Production class2prod(EClassifier class, EPackage pkg) {
  // assumes flattened inheritance
  // TODO: if containment, and !(lowerBound ==1  && upperBound==1) than need Opt.
  
  bool isRequired(EStructuralFeature f) = (f.lowerBound == 1 && f.upperBound >= 1);
  
  ps =  [ feature2arg(f, class, pkg, true) | f <- class.eStructuralFeatures, isRequired(f), !f.derived ];
  kws = [ feature2arg(f, class, pkg, false) | f <- class.eStructuralFeatures, !isRequired(f), !f.derived ]
    + [ label("uid", adt("Id", [])) ];
  return cons(label(class.name, adt(class.name, [])), ps, kws, {});
}

Production classifier2choice(EClassifier class, EPackage pkg) {
  Symbol a = adt(class.name, []);
  set[Production] alts = { class2prod(class, pkg) | !class.abstract }
    + { cons(label(class.name, a), [label(fieldName(sub.name), adt(sub.name, []))], [label("uid", adt("Id", []))], {})  
          | EClassifier sub <- directSubclassesOf(class, pkg) };
  return choice(a, alts);
}

str fieldName(str x) = "\\<uncapitalize(x)>";

Production classifier2choice(EClassifier enum, EPackage pkg) {
  Symbol a = adt(enum.name, []);
  set[Production] alts = { cons(label(el.name, a), [], [], {}) | el <- enum.eLiterals };
  return choice(a, alts);
}

map[Symbol, Production] package2definitions(EPackage pkg) 
  = ( p.def: p | EClassifier c <- pkg.eClassifiers, !(c is EDataType), p := classifier2choice(c, pkg) );
  


void flattenSamples() {
  ecores = |file:///Users/tvdstorm/CWI/rascal-ecore/src/lang/ecore/samples|.ls;
  for (loc e <- ecores) {
    try {
      EPackage pkg = load(#EPackage, e);
      println("Successfully loaded <e>");
      flattenInheritance(newRealm(), pkg);
      println("Successfully flattenend <e>");
    }
    catch value x: {
      println("Exception: <x> for <e>"); 
    }
  }
}
