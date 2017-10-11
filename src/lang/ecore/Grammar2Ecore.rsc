module lang::ecore::Grammar2Ecore

import lang::ecore::Ecore;
import lang::ecore::EcoreUtil;
import lang::ecore::Refs;

import analysis::graphs::Graph;

import Type;
import Set;
import String;
import ParseTree;
import IO;


/*
 * TODOS
 * - multiple productions with same class (use this to infer optionality)
 * - support optional literals as boolean properties
 * - optional non-terminals are optional references
 *
 * "The Mapping"
 *  
 * RULES
 * syntax S = Prod* -> abstract class S + subclasses where all Ps are partioned according to their label
 * 
 * PRODUCTIONS
 * for each set of prods with the same label
 * p: Symbol*
 * p: Symbol*
 * ...
 * - add *required* fields to class p, for all field-labeled symbols occurring in *all* prods
 * - add optional fields to class p, for all field-labeled symbols occurring in at *least one* prod (but not all)
 * - if @id{x} is present, set iD = true; @id{x} must be present on all prods with same label.
 * 
 * SYMBOLS
 * Symbol label
 * - create feature with type according to Symbol named label.
 * - type of Symbol is determined as (in order):
 *   - "literal"? -> boolean
 *   - if prod has @ref{label:C:/path}, make ref to C, set containment=false 
 *   - else Id -> string,
 *   - if prod has @lift{label:prim}, set type to prim (assume values of type prim are parseable as Symbol)
 *   - Symbol* -> set many=true, lowerbound=0, upperbound=-1, type = typeOf(Symbol), containment=true
 *   - Symbol? -> set lowerbound=0, upperbound=1, type = typeOf(Symbol), containment=true
 *   - Symbol+ -> set lowerbound=1, upperbound=-1, type = typeOf(symbol), containment=true
 *        [for all regulars: if @ref{label:C:/...} and Symbol=Id, same, but containment=false]
 *        [for all * /+ regulars: if @ordered{label:b}, set ordered=b;
 *   - else: set containment=true, type = typeOf(Symbol) (implied: many=false, etc.)
 *
 * So annotations required
 *  @id{fieldName}
 *  @ref{fieldName:Class:path}
 *  @ordered{fieldName:bool}
 *  @lift{fieldName:prim}
 *  @opposite{fieldName:Class.fieldName}
 *
 * NOTES REGARDING TREE2MODEL
 *
 * Assumptions
 * - all every tree node (that is not a lexical/@lifted, or literal etc.) corresponds to an object
 *   (i.e. has an identity)
 * - everything that is optional as per the above, should be optional (= keyword param) in model ADT
 * - all collections are represented as lists (even if @ordered{fieldName:false})
 * - primitives (via @lift) are converted via to<prim>("<tree>"); for int/bool/real
 * - @ref things are created as Ref[Class] values via the refs referTo(#Class, ...) function
 *   (this implies that every Class needs to be an ADT...; FIXME: this is problematic)
 */
 
bool hasConcreteProds(str nt, set[Production] prods) {
  // syntax S = syms;
  if (size(prods) == 1, Production p <- prods, !(p.def is label)) {
    return true;
  }
  // syntax S = ... | S: ... | ...
  if (Production p <- prods, p.def is label, p.def.name == nt) {
    return true;
  }
  return false;
}

//NB: prods *must be labeled*;
map[str, EClassifier] grammar2classMap(type[&T<:Tree] g, Realm realm) {
  map[str, EClassifier] classMap = ();
  
  
  for (s:sort(str nt) <- g.definitions) {
    assert nt notin classMap : "class <nt> already defined";
    super = realm.new(#EClass, EClass(name = nt));
    classMap[nt] = EClassifier(super);

    prods = g.definitions[s].alternatives;

    if (!hasConcreteProds(nt, prods)) {
      classMap[nt].eClass.abstract = true;
    }
    
    for (Production p <- prods, label(str cls, _) := p.def, cls != nt, cls notin classMap) {
      class = realm.new(#EClass, EClass(name = cls));
      class.eSuperTypes += [referTo(#EClass, classMap[nt].eClass)];
      classMap[cls] = EClassifier(class);
    }
  }

  return classMap;
}

rel[str class, str field, bool req, bool id, Symbol symbol, tuple[str class, str path] classAndPath] prods2fieldMap(map[str, EClassifier] classMap, set[Production] prods) {

  bool isRequired(str cls, str fld) {
    for (Production p <- prods, p.def.name == cls) {
      if (label(fld, Symbol _) <- p.symbols) {
        continue;
      }
      return false;
    }
    return true;
  }
    
  bool idFor(str cls, str fld) 
    = Production p <- prods &&  p.def.name == cls && fld in prodIds(p);
    
  tuple[str,str] pathFor(str cls, str fld) {
    if (Production p <- prods,  p.def.name == cls, <fld, str class, str path> <- prodRefs(p)) {
      return <class, path>;
    }
    return <"", "">;
  } 
  
  result = {};
  
  for (str cls <- classMap) {
    flds = { <fld, sym> | Production p <- prods, p.def.name == cls, label(str fld, Symbol sym) <- p.symbols };
    result += {<cls, fld, isRequired(cls, fld), idFor(cls, fld), sym, pathFor(cls, fld)> | <str fld, Symbol sym> <- flds };
  }

  return result;
}

EPackage grammar2ecore(type[&T<:Tree] g, str pkgName, str nsURI = "http://" + pkgName, str nsPrefix = "", Realm realm = newRealm()) {
  fact = realm.new(#EFactory, EFactory(null()));
  
  pkg = realm.new(#EPackage, EPackage(referTo(#EFactory, fact), name = pkgName, nsURI = nsURI, nsPrefix = nsPrefix));
  fact.ePackage = referTo(#EPackage, pkg);
  
  strType = EClassifier(realm.new(#EDataType, EDataType(name = "EString")));
  boolType = EClassifier(realm.new(#EDataType, EDataType(name = "EBoolean")));
  
  map[str, EClassifier] classMap = grammar2classMap(g, realm) + ("EString": strType, "EBoolean": boolType);
  
      
  allProds = ( {} | it + g.definitions[s].alternatives | Symbol s <- g.definitions );
  fieldMap = prods2fieldMap(classMap, allProds);
  
  inh = { <sub.name, sup.name> | str class <- classMap, EClassifier(EClass sub) := classMap[class],
     Ref[EClass] refSup <- sub.eSuperTypes, EClassifier(EClass sup) <- classMap<1>, sup.uid == refSup.uid };

  for (str class <- reverse(order(inh)) + [ c | str c <- classMap, EClassifier(EClass e) := classMap[c], e.eSuperTypes == [] ]) {
    for (<class, str field, bool req, bool id, Symbol symbol, <str target, str path>> <- fieldMap) {
      if (!anySuperClassHasFeature(classMap, class, field)) {
        // NB: we don't check that the feature has the same type etc, we assume: same name ==> same feature.
        classMap[class].eClass.eStructuralFeatures += [ symbol2feature(classMap, realm, field, symbol, req, id, target, path) ];
      }
    }
  }
    
  pkg.eClassifiers = [ classMap[k] | k <- classMap ];
  
  return pkg;
}


EStructuralFeature symbol2feature(map[str, EClassifier] classMap, Realm realm, str fld, Symbol s, bool req, bool id, str target, str path) {
    if (s is \iter-star-seps || s is \iter-star) {
      return makeOpt(makeMany(toField(classMap, realm, fld, s.symbol, req, id, target, path)));
    }
    
    if (s is \iter-seps || s is \iter) {
      return makeMany(toField(classMap, realm, fld, s.symbol, req, id, target, path));
    }

    if (s is \opt, s.symbol is lit) {
      return toField(classMap, realm, fld, s.symbol, req, id, target, path);
    }
    
    if (s is \opt) {
      return makeOpt(toField(classMap, realm, fld, s.symbol, req, id, target, path));
    }
    
    return toField(classMap, realm, fld, s, req, id, target, path);
 }  
 
 EStructuralFeature toField(map[str, EClassifier] classMap, Realm realm, str fld, Symbol s, bool req, bool id, str target, str path) {
    //println("fld = <fld>, sym = <s>, req = <req>, id= <id>, path = <path>");
    
    // cross references
    if (path != "") {
      f = EStructuralFeature(realm.new(#EReference, EReference(
        name = fld, 
        upperBound = 1,
        eType = referTo(#EClassifier, classMap[target]))
      ));
      
      if (req) {
        f.eReference.lowerBound = 1;
      }
      
      return f;
    }
    
    // bool attributes
    if (s is lit || s is cilit) { // only in opt
      f = EStructuralFeature(realm.new(#EAttribute, EAttribute(
        name = fld, 
        upperBound = 1,
        eType = referTo(#EClassifier, classMap["EBoolean"]))
      ));
      
      if (req) {
        f.eAttribute.lowerBound = 1;      
      }
      
      return f;
    }
    
    // string attributes
    if (s is lex) {
      f = EStructuralFeature(realm.new(#EAttribute, EAttribute(
        name = fld, 
        upperBound = 1,
        eType = referTo(#EClassifier, classMap["EString"]))
      ));
        
      if (id) {
        f.eAttribute.iD = true;
      }
      
      if (req) {
        f.eAttribute.lowerBound = 1;
      }
      return f;
    }
    
    // containment
    f = EStructuralFeature(realm.new(#EReference, EReference(
      name = fld, 
      eType = referTo(#EClassifier, classMap[s.name]),
      upperBound = 1,
      containment = true)
    ));
    
    if (req) {
      f.eReference.lowerBound = 1;
    }
    
    return f;
}  
  
      

bool anySuperClassHasFeature(map[str, EClassifier] classMap, str class, str field) {
  if (EStructuralFeature f <- classMap[class].eClass.eStructuralFeatures, f.name == field) {
    return true;
  }
  return ( false | it || anySuperClassHasFeature(classMap, sup.name, field) |
       Ref[EClass] refSup <- classMap[class].eClass.eSuperTypes, EClassifier(EClass sup) <- classMap<1>, 
          sup.uid == refSup.uid );
}

set[str] prodIds(Production p) 
  = { id[1..-1] | p has attributes, \tag("id"(str id)) <- p.attributes };

rel[str field, str class, str path] prodRefs(Production p) 
  = { <fld, cls, path> | p has attributes, \tag("ref"(str spec)) <- p.attributes, 
       [str fld, str cls, str path] := split(":", spec[1..-1]) };
