module lang::ecore::Model2HUTN

import lang::ecore::Refs;

import Type;
import List;
import IO;
import String;
import Node;
import util::Maybe;

// NB: need reified ADT for order of parameters in constructors (EPackage would not suffice)
str model2hutn(type[&T<:node] meta, &T<:node model) 
  = obj2hutn(model, meta);

str obj2hutn(node n, type[node] meta) {
  println("******** OBJ2HUTN");
  iprintln(n);
  assert !isInjection(n);
  class = getName(n);
  kids = getChildren(n);
  kwps = getKeywordParameters(n);
  println("CLASS = <class>");
  if (cons(label(class, _), flds, _, _) <- meta.definitions[typeOf(n)].alternatives, size(flds) == size(kids)) {
    println("flds: <flds>");
    println("kids: <kids>");
    return "<class> {<for (int i <- [0..size(flds)], kids[i] != nothing(), kids[i] != null()) {><flds[i].name>: <value2hutn(kids[i], meta)>
           '  <}>
           '  <for (str kw <- kwps, kw != "uid") {><kw>: <value2hutn(kwps[kw], meta)> 
           '  <}>
           '}";  
  }
}

str value2hutn(value v, type[node] meta) {
  switch (v) {
    case null(): 
      return "null";

    case just(value x): 
      return value2hutn(x, meta);

    case ref(id(loc l)): 
      return "<l>";
      
    case list[value] vs:
      if (vs == []) {
        return "[]";
      }
      else if ([value elt] := vs) {
        return "[<value2hutn(elt, meta)>]";
      }
      else {
        return "[<for (value x <- vs) {>
               '  <value2hutn(x, meta)><}>]";
      }
      
    case node n:
      return obj2hutn(uninject(n), meta);

    case str x:
      return "\"<x>\"";
      
    default:
      return "<v>";
  
  }

}