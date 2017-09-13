module lang::ecore::Grammar2Ecore

import lang::ecore::Ecore;
import lang::ecore::Refs;

import Type;
import Set;
import String;
import ParseTree;
import IO;


EPackage grammar2ecore(type[&T<:Tree] g, str pkgName, str nsURI = "http://" + pkgName, str nsPrefix = "") {
  r = newRealm();
  
  pkg = r.new(#EPackage, EPackage(pkgName, nsURI, nsPrefix));
  strType = r.new(#EClassifier, EDataType("EString"));
  pkg.eClassifiers += [strType];
  
  classMap = ();
  
  // first do classes
  for (s:sort(str nt) <- g.definitions) {
    prods = g.definitions[s].alternatives;
    if (size(prods) == 1, p <- prods, !(p.def is label)) {
      // use sort name as class
      class = r.new(#EClassifier, EClass(nt, false, false));
      classMap[nt] = class;
    }
    else {
      super = r.new(#EClassifier, EClass(nt, true, false));
      classMap[nt] = super;
      for (Production p <- prods, label(str cls, _) := p.def) {
        // todo: invent names if there are no prod labels
        class = r.new(#EClassifier, EClass(cls, false, false));
        class.eSuperTypes += [referTo(#EClassifier, class)];
        classMap[cls] = class;
      }
    }
  }
    
  EStructuralFeature toField(str fld, Symbol s, Production p) {
    assert s is lex || s is sort;
    
    if (<fld, str class, _> <- prodRefs(p)) {
      return r.new(#EStructuralFeature, EReference(fld, referTo(#EClassifier, classMap[class]), false, false));
    }
    
    if (s is lex) {
      // todo: make ints etc. (via tags?)
      eAttr = r.new(#EStructuralFeature, EAttribute(fld, referTo(#EClassifier, strType)));
      if (str id <- prodIds(p)) {
        eAttr.iD = true;
      }
      return eAttr;
    }
    
    return r.new(#EStructuralFeature, EReference(fld, referTo(#EClassifier, classMap[s.name]), true, false));
  }  
    
  EStructuralFeature symbol2feature(str fld, Symbol s, Production p) {
    if (s is \iter-star-seps || s is \iter-star) {
      return toField(fld, s.symbol, p)[many=true];
    }
    
    if (s is \iter-seps || s is \iter) {
      return toField(fld, s.symbol, p)[many=true][lowerBound=1];
    }
    
    if (s is \opt) {
      return toField(fld, s.symbol, p);
    }
    
    return toField(fld, s, p);
  }  
    
  // then do fields
  for (s:sort(str nt) <- g.definitions) {
    prods = g.definitions[s].alternatives; 
    if (size(prods) == 1, p <- prods, !(p.def is label)) {
      classMap[nt].eStructuralFeatures += [symbol2feature(fldName, s, p) 
        | Production p <- prods, label(str fldName, Symbol s) <- p.symbols ];
    }
    else {
      for (Production p <- prods, label(str cls, _) := p.def) {
        classMap[cls].eStructuralFeatures += 
          [ symbol2feature(fldName, s, p) | label(str fldName, Symbol s) <- p.symbols ];
      }
    }
  }
    
  pkg.eClassifiers += [ classMap[k] | k <- classMap ];
  
  return pkg;
}

set[str] prodIds(Production p) 
  = { id[2..-2] | p has attributes, \tag("id"(str id)) <- p.attributes };

rel[str field, str class, str path] prodRefs(Production p) {
  if (p has attributes) {
    return { <fld, cls, path> | \tag("ref"(str spec)) <- p.attributes, 
       [str fld, str cls, str path] := split(":", spec[1..-1]) };
  }
  return {};
}
