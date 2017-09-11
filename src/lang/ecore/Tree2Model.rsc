module lang::ecore::Tree2Model

import ParseTree;
import Type;
import List;
import lang::ecore::Refs;
import lang::ecore::Grammar2Ecore;
import IO;
import String;
import Node;


&M<:node tree2model(type[&M<:node] meta, Tree t)  {
  t = (t has top ? t.top : t);
  
  FixUps fixUps = ();
  
  void fix(node obj, lrel[str field, str path] fixes) {
    fixUps[getId(obj)] = fixes;
  }
  
  model = tree2model(meta, newRealm(), t, fix);
  model = fixUp(meta, model, fixUps);  
  
  return typeCast(meta, model);
}

alias Fix = void(node, lrel[str field, str path]);
alias FixUps = map[Id, lrel[str field, str path]];

&M<:node fixUp(type[&M<:node] meta, &M model, FixUps fixes) {
  // The stuff with typeOf etc is truly horrible here.
  // It works now, but I'd like it to be simpler.
  
  &T<:node fixup(type[&T<:node] t, &T<:node obj) {
    c = getName(obj);
    kws = getKeywordParameters(obj);
    alts = meta.definitions[t.symbol].alternatives;

    for (<str fld, str path> <- fixes[getId(obj)]) {
      kids = getChildren(obj);
      if (cons(label(c, _), ps:[*_, p:label(fld, rt:adt("Ref", _)), *_], _, _) <- alts) {
        int i = indexOf(ps, p);
        target = deref(meta, model, path);
        obj = make(t, c, kids[0..i] + [referTo(type(rt, meta.definitions), target)] + kids[i+1..], kws);
      }
      else {
        throw "Cannot find constructor for <obj>";
      }
    }

    return typeCast(t, obj);
  }
  
  return typeCast(meta, visit(model) {
    case node n => fixup(type(typeOf(n), meta.definitions), n) when isObj(n)
  });
}

value getField(type[&M<:node] meta, node obj, str fld) {
  c = getName(obj);
  t = typeOf(obj);
  if (cons(label(c, _), ps:[*_, p:label(fld, _), *_], _, _) <- meta.definitions[t].alternatives) {
    int i = indexOf(ps, p);
    return getChildren(obj)[i];
    
  }
  throw "Could not find constructor field <fld> on <obj>";
}

/*
 * Path syntax (to be fixed)
 * - <empty>
 * - Path / Id
 * - Path / Id [ <int> ]
 * - Path / Id [ Id = <str> ]
 */  

node deref(type[&M<:node] meta, &M root, str path) 
  = deref(meta, root, split("/", path)[1..]); 

node deref(type[&M<:node] meta, node obj, list[str] elts) {
  if (elts == []) {
    return obj;
  }
  
  cur = elts[0];
  
  if (/^<fld:[a-zA-Z0-9_]+>$/ := cur) {
    return deref(meta, typeCast(#node, getField(meta, obj, fld)), elts[1..]);
  }

  if (/^<fld:[a-zA-Z0-9_]+>\[<idx:[0-9_]+>$/ := cur) {
    if (list[node] l := getField(meta, obj, fld)) {
      int i = toInt(idx);
      if (i < size(l)) {
        return deref(meta, l[toInt(idx)], elts[1..]);
      }
      throw "Indexing <i> is out of bounds for list <l>";
    }
    throw "Cannot index on non-list property: <getField(meta, obj, fld)>";
  }
  
  if (/^<fld:[a-zA-Z0-9_]+>\[<key:[a-zA-Z0-9_]+>=<val:[^\]]*>\]$/ := cur) {
    if (list[node] l := getField(meta, obj, fld)) {
      if (node v <- l, getField(meta, v, key) == val) {
        return deref(meta, v, elts[1..]);
      }
      throw "Could not find element with <key> = <val>";
    }
    throw "Cannot filter on non-list property: <getField(meta, obj, fld)>";
  }
  
  throw "Invalid path element <cur>";
}


value tree2model(type[&M<:node] meta, Realm r, Tree t, Fix fix) {
  p = t.prod;
  
  if (p.def is lex) {
    // for now, just strings
    return "<t>";
  }

  if (p is regular) {
     return [ tree2model(meta, r, t.args[i], fix) | int i <- [0,2..size(t.args)], isAST(t.args[i]) ];
  }

  lrel[str, str] fixes = [];

  args = for (int i <- [0,2..size(t.args)], isAST(t.args[i])) {
    sub = tree2model(meta, r, t.args[i], fix);
    fld = p.symbols[i] is label ? p.symbols[i].name : ""; 
    if (<fld, _, str path> <- prodRefs(p)) {
      // for now, we assume sub is a primitive.
      // TODO: _ is too limited, need variable names
      // this means fix management should be outside this loop
      // to have all basic args available (then update args with null where need)
      fixes += [<fld, replaceAll(path, "_", "<sub>")>];
      append null();  
    }
    else {
      append sub;
    }
  }  
  
  a = p.def is label ? p.def.symbol.name : p.def.name;
  tt = type(adt(a, []), meta.definitions);
  obj = r.new(tt, make(tt, capitalize(p.def.name), args, ("src": t@\loc)));
  fix(obj, fixes);
  
  return obj;
}

bool isAST(Tree t) = t has prod && !(t.prod.def is lit || t.prod.def is cilit);