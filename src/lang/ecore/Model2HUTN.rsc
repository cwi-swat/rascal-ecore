module lang::ecore::Model2HUTN

import lang::ecore::Refs;

import Type;
import List;
import IO;
import String;
import Node;
import util::Maybe;
import ParseTree;

&T hutn2model(type[&T<:node] meta, &U<:Tree hutn, Realm realm = newRealm()) {
  // todo
}

// NB: need reified ADT for order of parameters in constructors (EPackage would not suffice)
str model2hutn(type[&T<:node] meta, &T<:node model) 
  = obj2hutn(model, meta, 0);

str indent(int i) = ( "" | it + "  " | _ <- [0..i] );

str obj2hutn(node n, type[node] meta, int ind) {
  assert !isInjection(n);
  class = getName(n);
  kids = getChildren(n);
  kwps = getKeywordParameters(n);
  if (cons(label(class, _), flds, _, _) <- meta.definitions[typeOf(n)].alternatives, size(flds) == size(kids)) {
    str body = intercalate("\n<indent(ind + 1)>", 
      [ "<flds[i].name>: <value2hutn(kids[i], meta, ind + 1)>" | int i <- [0..size(flds)], kids[i] != nothing(), kids[i] != null() ]
      + [ "<kw>: <value2hutn(kwps[kw], meta, ind + 1)>" | str kw <- kwps, kw != "uid" ]);
    return "<class> {\n<indent(ind+1)><body>\n<indent(ind)>}";
  }
}

str value2hutn(value v, type[node] meta, int i) {
  switch (v) {
    case null(): 
      return "null";

    case just(value x): 
      return value2hutn(x, meta, i);

    case ref(id(loc l)): 
      return "<l>";
      
    case list[value] vs:
      if (vs == []) {
        return "[]";
      }
      else if ([value elt] := vs) {
        return "[<value2hutn(elt, meta, i)>]";
      }
      else {
        return "[\n<indent(i + 1)>" + intercalate("\n<indent(i + 1)>", [ value2hutn(x, meta, i + 1) | value x <- vs ]) + "\n<indent(i)>]";
      }
      
    case node n:
      return obj2hutn(uninject(n), meta, i);

    case str x:
      return "\"<x>\"";
      
    default:
      return "<v>";
  
  }

}