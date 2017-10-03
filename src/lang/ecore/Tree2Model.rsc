module lang::ecore::Tree2Model

import ParseTree;
import Type;
import List;
import lang::ecore::Refs;
import lang::ecore::Grammar2Ecore;
import IO;
import String;
import Node;
import Map;

/*
Assumptions
- all prods from grammar correspond to class with identity
- refs are always primitives (i.e. lexicals)
- ref paths are only along the containment hierarchy.
- all regulars are mapped to lists (?)

TODO
- use meta model (EPackage, not type[&M<:node]...
*/


alias Fix = void(node, lrel[str field, str path]);
alias Track = void(Id, loc);
alias FixUps = map[Id, lrel[str field, str path]];


&M<:node tree2model(type[&M<:node] meta, Tree t, loc uri = t@\loc) 
  = tree2modelWithOrigins(meta, t, uri = uri)[0];

alias Org = map[Id id, loc src];

tuple[&M<:node, Org] tree2modelWithOrigins(type[&M<:node] meta, Tree t, loc uri = t@\loc)  {
  t = (t has top ? t.top : t);
  
  FixUps fixUps = ();
  Org origins = ();
  
  void track(Id x, loc l) {
    origins[x] = l;
  }
  
  void fix(node obj, lrel[str field, str path] fixes) {
    fixUps[getId(obj)] = fixes;
  }
  
  model = tree2model(meta, newRealm(), t, fix, uri, "/", track);
  model = fixUp(meta, model, fixUps);  
  
  return <typeCast(meta, model), origins>;
}

value tree2model(type[&M<:node] meta, Realm r, Tree t, Fix fix, loc uri, str xmi, Track track) {
  p = t.prod;
  
  if (p.def is lex) {
    return "<t>"; // for now, just strings
  }
  
  largs = labeledAstArgs(t, p);

  if (p is regular) {
    if (opt(lit(str _)) := p.def) {
      return t.args != [];
    }
    return [ tree2model(meta, r, largs[i][1], fix, uri, xmi + ".<i>", track) | int i <- [0..size(largs)] ];
  }

  lrel[str, value] env = [ <fld, tree2model(meta, r, a, fix, uri, xmi + "/@<fld>", track)> 
     | int i <- [0..size(largs)], <str fld, Tree a> := largs[i] ];


  lrel[str, str] fixes = [];
  env = for (<str fld, value v> <- env) {
    if (<fld, _, str path> <- prodRefs(p)) {
      fixes += [<fld, substBindings(path, env)>];
      append <fld, null()>;
    }
    else {
      append <fld, v>;
    }      
  }  
  
  adtName = p.def is label ? p.def.symbol.name : p.def.name;
  tt = type(adt(adtName, []), meta.definitions);
  
  //println("ENV");
  //iprintln(env);
  
  args = ();  
  kws = (); 
  
  for (<str fld, value v> <- env) {
    int idx = getFieldIndex(meta, adt(adtName, []), p.def.name, fld); 
    if (idx != -1) {
      args[idx] = v;
    }
    else { // assume it's a keyword param.
      kws[fld] = v;
    }
  }
  
  // todo: also special case "name" attributes
  if (str x <- prodIds(p), <x, str v> <- env) {
  	uri.fragment = v;
  }
  else if (<"name", str v> <- env) {
    uri.fragment = v;
  }
  else {
  	uri.fragment = xmi;
  }
  
  Id myId = id(uri.top);
  if (t@\loc?) {
    track(myId, t@\loc);
  }
  else {
    println("WARNING: no loc for <t>");
  }
  
  //println("## CREATING: <p.def.name>");
  //println("ARGS:");
  //for (int  i <- args) println("- <i>: <args[i]>");
  //println("KWS:");
  //for (str k <- kws) println("- <k>: <kws[k]>");
  
  obj = r.new(tt, make(tt, p.def.name, [ args[i] | int i <- [0..size(args)] ], kws), id = myId);
  fix(obj, fixes);
  
  return obj;
}

&M<:node fixUp(type[&M<:node] meta, &M model, FixUps fixes) {
  // The stuff with typeOf etc is truly horrible here.
  // It works now, but I'd like it to be simpler.
  
  &T<:node fixup(type[&T<:node] t, &T<:node obj) {
    c = getName(obj);
    kws = getKeywordParameters(obj);
    alts = meta.definitions[t.symbol].alternatives;

    for (<str fld, str path> <- fixes[getId(obj)]) {
      kids = getChildren(obj);
      target = deref(meta, model, path);
      if (cons(label(c, _), ps:[*_, p:label(fld, rt:adt("Ref", _)), *_], _, _) <- alts) {
        int i = indexOf(ps, p);
        obj = make(t, c, kids[0..i] + [target is null ? target : referTo(type(rt, meta.definitions), target)] + kids[i+1..], kws);
      }
      else if (cons(label(c, _), _, [*_, p:label(fld, rt:adt("Ref", _)), *_], _) <- alts) {
        obj = setKeywordParameters(obj, kws + (fld: target is null ? target : referTo(type(rt, meta.definitions), target))); 
      }
      else {
        throw "Cannot find constructor for fixing <obj>.<fld> to <path>";
      }
    }

    return typeCast(t, obj);
  }
  
  return typeCast(meta, visit(model) {
    case node n => fixup(type(typeOf(n), meta.definitions), n) when isObj(n)
  });
}

value getField(type[&M<:node] meta, node obj, str fld) 
  = getChildren(obj)[getFieldIndex(meta, typeOf(obj), getName(obj), fld)];

int getFieldIndex(type[&M<:node] meta, Symbol t, str c, str fld) {
  if (cons(label(c, _), ps:[*_, p:label(fld, _), *_], _, _) <- meta.definitions[t].alternatives) {
    return indexOf(ps, p);
  }
  return -1;
}

/*
 * Path syntax (to be fixed)
 * - <empty>
 * - Path / Id
 * - Path / Id [ <int> ]
 * - Path / Id [ Id = <str> ]
 */  

list[str] splitPath(str path) = split("/", path)[1..];

node deref(type[&M<:node] meta, &M root, str path) 
  = deref(meta, root, splitPath(path)); 

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
      return null();
      //throw "Could not find element with <key> = <val>";
    }
    throw "Cannot filter on non-list property: <getField(meta, obj, fld)>";
  }
  
  throw "Invalid path element <cur>";
}


lrel[str, Tree] labeledAstArgs(Tree t, Production p) 
  =  [ <(p has symbols && p.symbols[i] is label) ? p.symbols[i].name : "", t.args[i]> 
       | int i <- [0,2..size(t.args)], isAST(t.args[i]) ];

str substBindings(str path, lrel[str, value] env) 
  = ( path | replaceAll(it, "$<x>", "<v>") | <str x, value v> <- env );


bool isAST(Tree t) = t has prod && !(t.prod.def is lit || t.prod.def is cilit);