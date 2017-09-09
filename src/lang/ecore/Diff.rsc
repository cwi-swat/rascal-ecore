module lang::ecore::Diff

import lang::ecore::Refs;
import lang::ecore::LCS;
import Node;
import List;
import IO;
import Type;

alias Patch
  = tuple[Id root, Edits edits];

alias Edits
  = lrel[Id obj, Edit edit];

data Edit
  = put(str field, value val)
  | unset(str field)
  | ins(str field, int pos, value val)
  | del(str field, int pos)
  | create(str class) 
  | destroy() 
  ;
  
map[Id, node] objectMap(node x) = ( getId(n): n | /node n := x, isObj(n) ); 

Patch diff(type[&T<:node] meta, &T old, &T new) {
  m1 = objectMap(old);
  m2 = objectMap(new);
  
  edits = [ <c, create(getClass(m2[c]))> | Id c <- m2, c notin m1 ];
  edits += [ *init(meta, c, m2[c]) | Id c <- m2, c notin m1 ];
  edits += [ *diff(meta, x, m1[x], m2[x]) | Id x <- m1, x in m2 ];
  edits += [ <d, destroy()> | Id d <- m1, d notin m2 ];
  
  return <getId(new), edits>;
}

Edits init(type[&T<:node] meta, Id id, node new) {
  Symbol s = getType(new);
  str c = getName(new);
  
  Edits edits = [];
  
  ps = getParams(meta, s, c);
  newKids = getChildren(new);
  edits += [ *initKid(id, newKids[i], ps[i]) | int i <- [0..size(ps)] ];
  
  kws = getKwParams(meta, s, c);
  newKws = getKeywordParameters(new);
  edits += [ *initKid(id, newKws[fld], fld) | str fld <- kws, fld != "uid", fld in newKws ];

  return edits;
}

Edits initKid(Id id, list[value] v, str field) 
  = [ <id, ins(field, i, primOrId(v[i]))> | int i <- [0..size(v)] ];

default Edits initKid(Id id, value v, str field)
  = [<id, put(field, primOrId(v))>];


// assumptions: all nodes have a uid, except ref/null
Edits diff(type[&T<:node] meta, Id id, node old, node new) {
  assert getClass(old) == getClass(new);
  assert old.uid == id;
  assert new.uid == id;
  
  Symbol s = getType(old);
  str c = getName(old);
  
  Edits edits = [];
  
  ps = getParams(meta, s, c);
  oldKids = getChildren(old);
  newKids = getChildren(new);
  edits += [ *diffKid(id, oldKids[i], newKids[i], ps[i]) | int i <- [0..size(ps)] ];  
  
  kws = getKwParams(meta, s, c);
  oldKws = getKeywordParameters(old);
  newKws = getKeywordParameters(new);
  for (str field <- kws, field != "uid") {
    if (field in oldKws, field in newKws) {
      edits += diffKid(id, oldKws[field], newKws[field], field);
    }
    else if (field in oldKws) {
      edits += [<id, unset(field)>];
    }
    else if (field in newKws) {
      edits += [<id, put(field, primOrId(newKws[field]))>];
    }
  }
  
  return edits;
}

Edits diffKid(Id id, value oldKid, value newKid, str field) {
  if (refEq(newKid, oldKid)) {
    return [];
  }

  if (list[value] xs := oldKid, list[value] ys := newKid) {
    mx = lcsMatrix(xs, ys, refEq);
    ds = getDiff(mx, xs, ys, size(xs), size(ys), refEq);
    return for (Diff d <- ds) {
      switch (d) {
        case add(value v, int pos): append <id, ins(field, pos, primOrId(v))>;
        case remove(_, int pos): append <id, del(field, pos)>;
      }
    }
  }
  
  if (set[value] l1 := oldKid, set[value] l2 := newKid) {
    return []; // todo
  }
   // attributes and refs
  return [<id, put(field, primOrId(newKid))>];
}



// also covers ref/null cases on both sides
default bool refEq(value v1, value v2) = v1 == v2;

bool refEq(node n, ref(Id x)) = getId(n) == x when !isRef(n);

bool refEq(ref(Id x), node n) = getId(n) == x when !isRef(n);

bool refEq(node n1, node n2) = getId(n1) == getId(n2) 
  when !isRef(n1), !isRef(n2);
   
bool refEq(list[value] vs1, list[value] vs2)
  = size(vs1) == size(vs2)  
  && ( true | it && refEq(vs1[i], vs2[i]) | i <- [0..size(vs1)] ); 

bool refEq(set[value] s1, set[value] s2) {
  outer: for (value x <- s1) {
    for (value y <- s2) {
      if (refEq(x, y)) {
        continue outer;
      }
    }
    return false;
  }
  outer: for (value x <- s2) {
    for (value y <- s1) {
      if (refEq(x, y)) {
        continue outer;
      }
    }
    return false;
  }
  return true;
}
  
// for some reason refs still end up in the second case...
//value primOrId(ref(Id x)) = x;
//value primOrId(node n) = getId(n) when hasId(n), !isRef(n);
//default value primOrId(value v) = v;

value primOrId(value v) {
  if (ref(Id x) := v) {
    return x;
  }
  if (node n := v, hasId(n)) {
    return getId(n);
  }
  return v;
}
  
str getClass(node n) = getName(n);

Symbol getType(node n) = typeOf(n);

list[str] getParams(type[&T<:node] meta, Symbol s, str c)
  = [ fld | cons(label(c, s), list[Symbol] ps, _, _) <- meta.definitions[s].alternatives, label(str fld, _) <- ps ];

set[str] getKwParams(type[&T<:node] meta, Symbol s, str c)
  = { fld | cons(label(c, s), _, list[Symbol] kws, _) <- meta.definitions[s].alternatives, label(str fld, _) <- kws };
  