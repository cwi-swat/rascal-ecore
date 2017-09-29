module lang::ecore::Grammar2Ecore

import lang::ecore::Ecore4;
import lang::ecore::Refs;

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


EPackage grammar2ecore(type[&T<:Tree] g, str pkgName, str nsURI = "http://" + pkgName, str nsPrefix = "", Realm realm = newRealm()) {
  fact = realm.new(#EFactory, EFactory(null()));
  
  pkg = realm.new(#EPackage, EPackage(referTo(#EFactory, fact), name = pkgName, nsURI = nsURI, nsPrefix = nsPrefix));
  fact.ePackage = referTo(#EPackage, pkg);
  
  strType = EClassifier(realm.new(#EDataType, EDataType(name = "EString")));
  pkg.eClassifiers += [strType];
  
  map[str, EClass] classMap = ();
  
  // first do classes
  for (s:sort(str nt) <- g.definitions) {
    super = realm.new(#EClass, EClass(name = nt));
    assert nt notin classMap : "class <nt> already defined";
    classMap[nt] = super;
    prods = g.definitions[s].alternatives;
    
    if (size(prods) > 1) {
      classMap[nt].abstract = true;
    }

    for (size(prods) > 1, Production p <- prods, label(str cls, _) := p.def) {
      // todo: invent names if there are no prod labels
      // todo: merge class fields if multiple prods have same labels.
      // deal with optionality.
      class = realm.new(#EClass, EClass(name = cls));
      class.eSuperTypes += [referTo(#EClass, super)];
      assert cls notin classMap : "class <nt> already defined";
      classMap[cls] = class;
    }
  }
    
  EStructuralFeature toField(str fld, Symbol s, Production p) {
    assert s is lex || s is sort;
    
    if (<fld, str class, _> <- prodRefs(p)) {
      return EStructuralFeature(realm.new(#EReference, EReference(
        name = fld, 
        lowerBound = 1, upperBound = 1,
        eType = referTo(#EClassifier, EClassifier(classMap[class])))
      ));
    }
    
    if (s is lex) {
      // todo: make ints etc. (via tags?)
      eAttr = EStructuralFeature(realm.new(#EAttribute, EAttribute(
        name = fld, 
        lowerBound = 1, upperBound = 1,
        eType = referTo(#EClassifier, strType))
      ));
        
      if (str id <- prodIds(p)) {
        eAttr.iD = true;
      }
      return eAttr;
    }
    
    return EStructuralFeature(realm.new(#EReference, EReference(
      name = fld, 
      eType = referTo(#EClassifier, EClassifier(classMap[s.name])),
      lowerBound = 1, upperBound = 1,
      containment = true)
    ));
  }  
  
  EStructuralFeature makeOpt(EStructuralFeature(EAttribute a))
    = EStructuralFeature(a[lowerBound=0]);

  EStructuralFeature makeOpt(EStructuralFeature(EReference r))
    = EStructuralFeature(r[lowerBound=0]);


  EStructuralFeature makeMany(EStructuralFeature(EAttribute a))
    = EStructuralFeature(a[upperBound=-1]);

  EStructuralFeature makeMany(EStructuralFeature(EReference r))
    = EStructuralFeature(r[upperBound=-1]);
    
  EStructuralFeature symbol2feature(str fld, Symbol s, Production p) {
    if (s is \iter-star-seps || s is \iter-star) {
      // OOPS: this sets attributes on EStructuralFeature injection, not the attribute/ref itself...
      return makeOpt(makeMany(toField(fld, s.symbol, p)));
    }
    
    if (s is \iter-seps || s is \iter) {
      return makeMany(toField(fld, s.symbol, p));
    }
    
    if (s is \opt) {
      return makeOpt(toField(fld, s.symbol, p));
    }
    
    return toField(fld, s, p);
  }  
    
  // then do fields
  for (s:sort(str nt) <- g.definitions) {
    prods = g.definitions[s].alternatives;
    if (size(prods) == 1, Production p <- prods) {
      classMap[nt].eStructuralFeatures += 
        [ symbol2feature(fldName, s, p) | label(str fldName, Symbol s) <- p.symbols ];
    }
    else { 
      for (Production p <- prods, label(str cls, _) := p.def) {
        classMap[cls].eStructuralFeatures += 
          [ symbol2feature(fldName, s, p) | label(str fldName, Symbol s) <- p.symbols ];
      }
    }
  }
    
  pkg.eClassifiers += [ EClassifier(classMap[k]) | k <- classMap ];
  
  return pkg;
}

set[str] prodIds(Production p) 
  = { id[1..-1] | p has attributes, \tag("id"(str id)) <- p.attributes };

rel[str field, str class, str path] prodRefs(Production p) 
  = { <fld, cls, path> | p has attributes, \tag("ref"(str spec)) <- p.attributes, 
       [str fld, str cls, str path] := split(":", spec[1..-1]) };
