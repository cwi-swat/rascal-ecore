module lang::ecore::text::Paths

import lang::std::Id;
import Type;
import Node;
import List;
import String;
import ParseTree;
import Exception;

syntax Path
  = "/" {Nav "/"}* navs 
  ;
  
syntax Nav
  = Id field
  | Id field "[" Nat index "]"
  | Id field "[" Id key "=" Val val "]"
  ;
  
lexical Val 
  = ![\]]* 
  ;  
  
lexical Nat
  = [1-9][0-9]* !>> [0-9]
  | [0]
  ;  
  
  
Path parsePath(str src) = parse(#Path, src);

value getField(type[&M<:node] meta, node obj, str fld) 
  = getChildren(obj)[getFieldIndex(meta, typeOf(obj), getName(obj), fld)];

int getFieldIndex(type[&M<:node] meta, Symbol t, str c, str fld) {
  if (cons(label(c, _), ps:[*_, p:label(fld, _), *_], _, _) <- meta.definitions[t].alternatives) {
    return indexOf(ps, p);
  }
  return -1;
}

node deref(type[&M<:node] meta, node obj, Path p)
  = ( obj | deref1(n, meta, it) |  Nav n <- p.navs ); 

node deref1((Nav)`<Id fld>`, type[&M<:node] meta, node obj)
  = typeCast(#node, getField(meta, obj, "<fld>"));
  
node deref1((Nav)`<Id fld>[<Nat idx>]`, type[&M<:node] meta, node obj) 
  = l[toInt("<idx>")]
  when
    list[node] l := getField(meta, obj, "<fld>");  

node deref1((Nav)`<Id fld>[<Id key>=<Val val>]`, type[&M<:node] meta, node obj)
  = v
  when
    list[node] l := getField(meta, obj, "<fld>"),
    node v <- l, 
    getField(meta, v, "<key>") == "<val>";
    
default node deref1(Nav n, type[&M<:node] meta, node obj) {
  throw InvalidArgument(obj, "could not deref <n>");
}

Tree deref(Tree t, Path p) 
  = ( t | deref1(n, it) | Nav n <- p.navs );

Tree deref1((Nav)`<Id fld>`, Tree t)
  = t.args[idx]
  when
    int idx := getFieldIndex(t.prod, "<fld>");


int sepSize(Tree lst)
  = (lst.prod.def is \iter-seps || lst.prod.def is \iter-star-seps) ? size(lst.prod.def.separators) : 0;

Tree deref1((Nav)`<Id fld>[<Nat idx>]`, Tree t)
  = lst.args[toInt("<idx>") * (sepSize(lst) + 1)]
  when
    int fldIdx := getFieldIndex(t.prod, "<fld>"),
    Tree lst := t.args[fldIdx], 
    lst.prod is regular;


Tree deref1(n:(Nav)`<Id fld>[<Id key>=<Val val>]`, Tree t) {
  int fldIdx = getFieldIndex(t.prod, "<fld>"); 
  if (Tree lst := t.args[fldIdx], lst.prod is regular) {
    for (int i <- [0,sepSize(lst)+1..size(lst.args)]) {
      Tree kid = lst.args[i];
      int keyIdx = getFieldIndex(kid.prod, "<key>");
      if ("<kid.args[keyIdx]>" == "<val>") {
        return kid;
      }
    }
    throw NoSuchElement("<n>");
  }
  throw InvalidArgument(t.args[fldIdx]);
} 

default Tree deref1(Nav n, Tree t) {
  throw InvalidArgument(t, "could not deref <n>");
}

int getFieldIndex(Production p, str fld)  = i
  when 
    int i <- [0..size(p.symbols)], 
    label(fld, _) := p.symbols[i];
  
default int getFieldIndex(Production p, str fld) = -1;


