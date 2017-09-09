module lang::ecore::Diff

import lang::ecore::Refs;
import lang::ecore::LCS;
import Node;
import List;
import IO;
import Type;

alias Patch
  = lrel[Id owner, Edit edit];

data Edit
  = setValue(str field, value val)
  
  // for lists
  | \insert(str field, int pos, value val)
  | remove(str field, int pos)
  
  | create(str class) 
  | destroy() 
  ;
  
map[Id, node] objectMap(node x)
  = ( getId(n): n | /node n := x, !(n is id), !(n is ref), !(n is null) ); 


Patch diff(type[&T<:node] meta, &T old, &T new) {
  m1 = objectMap(old);
  m2 = objectMap(new);
  
  Patch edits = [];
  
  edits += [ <c, create(getClass(m2[c]))> | Id c <- m2, c notin m1 ];
  edits += [ *init(meta, c, m2[c]) | Id c <- m2, c notin m1 ];
  edits += [ *diff(meta, x, m1[x], m2[x]) | Id x <- m1, x in m2 ];
  edits += [ <d, destroy()> | Id d <- m1, d notin m2 ];
  
  return edits;
}

Patch init(type[&T<:node] meta, Id id, node new) {
  Symbol s = getType(new);
  str c = getName(new);
  
  Patch edits = [];
  
  void initKid(value newKid, str field) {
    if (list[value] l := newKid) {
      for (int i <- [0..size(l)]) {
        value elt = l[i];
        if (node r := elt, !(r is ref), !(r is null)) { 
          edits += [<id, \insert(field, i, ref(getId(r)))>];
        }
        else {
          assert list[value] _ !:= elt;
          edits += [<id, \insert(field, i, elt)>];
        }
      }
    }
    else if (node r := newKid, !(r is ref), !(r is null)) { 
      edits += [<id, setValue(field, ref(getId(r)))>];
    }
    else {
      edits += [<id, setValue(field, newKid)>];
    }
  }
  
  ps = getParams(meta, s, c);
  newKids = getChildren(new);
  for (int i <- [0..size(ps)]) {
    initKid(newKids[i], ps[i][0]);
  }
  
  kws = getKwParams(meta, s, c);
  newKws = getKeywordParameters(new);
  for (<str field, _> <- kws, field != "uid", field in newKws) {
    initKid(newKws[field], field);
  }
  
  return edits;
}

Patch diff(type[&T<:node] meta, Id id, node old, node new) {
  assert getClass(old) == getClass(new);
  assert old.uid == id;
  assert new.uid == id;
  Symbol s = getType(old);
  str c = getName(old);
  
  Patch edits = [];
  
  void diffKid(value oldKid, value newKid, str field) {
    if (refEq(newKid, oldKid)) {
      return;
    }

    if (list[value] xs := oldKid, list[value] ys := newKid) {
      mx = lcsMatrix(xs, ys, refEq);
      ds = getDiff(mx, xs, ys, size(xs), size(ys), refEq);
      for (Diff d <- ds) {
        switch (d) {
          case add(value v, int pos): edits += [ <id, \insert(field, pos, v)> ];
          case remove(_, int pos): edits += [ <id, remove(field, pos)> ];
        }
      }
    }
    else if (set[value] l1 := oldKid, set[value] l2 := newKid) {
      ; // todo
    }
    else { // attributes and refs
      edits += [<id, setValue(field, newKid)>];
    }  
  }
  
  ps = getParams(meta, s, c);
  oldKids = getChildren(old);
  newKids = getChildren(new);
  for (int i <- [0..size(ps)]) {
    diffKid(oldKids[i], newKids[i], ps[i][0]);
  }
  
  kws = getKwParams(meta, s, c);
  oldKws = getKeywordParameters(old);
  newKws = getKeywordParameters(new);
  for (<str field, _> <- kws, field != "uid") {
    if (field in oldKws, field in newKws) {
      diffKid(oldKws[field], newKws[field], field);
    }
    else if (field in oldKws) {
      edits += [<id, setValue(field, null())>];
    }
    else if (field in newKws) {
      edits += [<id, setValue(field, newKws[field])>];
    }
  }
  
  return edits;
}

bool refEq(null(), null()) = true;

bool refEq(ref(Id x), ref(Id y)) = x == y;

bool refEq(node n, ref(Id x)) = getId(n) == x when !(n is ref), !(n is null);

bool refEq(ref(Id x), node n) = getId(n) == x when !(n is ref), !(n is null);

bool refEq(node n1, node n2) = getId(n1) == getId(n2) 
  when !(n1 is ref), !(n1 is null), !(n2 is ref), !(n2 is null);
   
bool refEq(list[value] vs1, list[value] vs2)
  = size(vs1) == size(vs2)  
  && ( true | it && refEq(vs1[i], vs2[i]) | i <- [0..size(vs1)] ); 

// TODO: sets

default bool refEq(value v1, value v2) = v1 == v2;

  
str getClass(node n) = getName(n);
Symbol getType(node n) = typeOf(n);

lrel[str, Symbol] getParams(type[&T<:node] meta, Symbol s, str class)
  = [ <fld, typ> | 
       cons(label(class, s), list[Symbol] ps, list[Symbol] kws, _) <- meta.definitions[s].alternatives,
       label(str fld, Symbol typ) <- ps ];

rel[str, Symbol] getKwParams(type[&T<:node] meta, Symbol s, str class)
  = { <fld, typ> | 
       cons(label(class, s), list[Symbol] ps, list[Symbol] kws, _) <- meta.definitions[s].alternatives,
       label(str fld, Symbol typ) <- kws };
  