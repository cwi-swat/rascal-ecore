module lang::ecore::PatchTree

import lang::ecore::Diff;
import lang::ecore::Refs;
import lang::ecore::Tree2Model;
import lang::ecore::Grammar2Ecore;
import ParseTree;

import Type;
import String;
import Set;
import IO;

/*
TODOS

- use original tree to find class prototypes and separator prototypes if not found in list itself
- support mutliple production with same class
- implement "create" by factoring out the flattened tree from patch tree.
- fix locs during the unflatten phase.
*/


&T<:Tree patchTree(type[&T<:Tree] tt, &T<:Tree pt, Patch patch, Org origins, Tree(type[&U<:Tree], str) parse) {
  Tree old = pt;
  if (pt has top) {
    old = pt.top;
  }
  
 
  rel[Id, loc] orgs = { <k, origins[k]> | k <- origins };
  
  // NB: "is sort" is needed, because otherwise other trees have same loc because injections.
  trees = ( obj: flatten(t, old, orgs) | /Tree t := old, t has prod, (t.prod.def is sort || t.prod.def is lex), t@\loc?, loc l := t@\loc, <Id obj, l> <- orgs )
        + ( obj: prod2tree(findProd(tt, class)) | <Id obj, create(str class)> <- patch.edits );
  
  map[tuple[Id, str], list[Tree]] sepCache = ();
  
  tuple[Tree,list[Tree]] getListAndSeps(Id obj, str field, Tree lst) {
     if (<obj, field> notin sepCache) {
       sepCache[<obj,field>] = getSeparators(lst);
     }
     return <lst, sepCache[<obj,field>]>;
  }
  
  for (<Id obj, Edit edit> <- patch.edits, edit has field) {
     Tree t = trees[obj];
     int idx = getFieldIndex(t.prod, edit.field);
     
     switch (edit) {
       case put(str field, value v): {
         Tree newVal = valToTree(v, tt, t.prod, field, t.prod.symbols[idx], parse);
         trees[obj] = setArg(t, idx, newVal);
       }
       
       case ins(str field, int pos, value v): {
         <lst, seps> = getListAndSeps(obj, field, t.args[idx]);
        
         lst = insertList(lst, pos, valToTree(v, tt, t.prod, field, lst.prod.def.symbol, parse), 
                  seps);

         // check for empty layout & reuse layout that is before.
         if ("<t.args[idx+1]>" == "") {
           t = setArg(t, idx + 1, t.args[idx-1]);
         }

         trees[obj] = setArg(t, idx, lst);
       }

       case del(str field, int pos): {
         <lst, seps> = getListAndSeps(obj, field, t.args[idx]);
         trees[obj] = setArg(t, idx, removeList(lst, pos, seps));
       }

     }
   }
   
  trees = unflatten(patch.root, trees);
  root = trees[patch.root];
  if (pt has top) {
    root = addLoc(appl(pt.prod, [pt.args[0], tree[patch.root], pt.args[2]]), pt);
  }
  
  return typeCast(tt, resolveTree(root, root, trees)); 
}

Production placeholderProd(Symbol s, Symbol id = lex("Id"))
  = prod(s, [lit("\<"), id, lit(":"), lit(symbolName(s)), lit("\>") ], 
       {\tag("category"("MetaAmbiguity"))});


// the result cannot be used to parse (yet; bug in Rascal)
type[&T<:Tree] addPlaceholderProds(type[&T<:Tree] tt, Symbol id = lex("Id")) {
  map[Symbol, Production] defs = tt.definitions;
  for (Symbol s <- defs, s is lex || s is sort) {
    defs[s].alternatives += {placeholderProd(s, id = id)};
  }
  if (type[&T<:Tree] tt2 := type(tt.symbol, defs)) {
    return tt2;
  }
  //return typeCast(#type[&T<:Tree], type(tt.symbol, defs));
}


Tree placeholder(Symbol s, str field) {
  if (s is opt || s is \iter-star || s is \iter-star-seps) {
    return appl(regular(s), []);
  }
  if (s is \iter-seps || s is iter) {
    // TODO: why not generate a single element here?
    // (if so, currently it will be part of the list for new elements always...)
    return appl(regular(s), []);
  }
  str src = "\<<field>:<symbolName(s)>\>";
  println("PLACHOLDER: <src>");
  return appl(placeholderProd(s), [ char(i) | int i <- chars(src) ]);
}
  
str symbolName(sort(str n)) = n;
str symbolName(lex(str n)) = n;
str symbolName(\opt(Symbol s)) = symbolName(s) + "?";
str symbolName(\iter-star(Symbol s)) = symbolName(s) + "*";
str symbolName(\iter-star-seps(Symbol s, _)) = symbolName(s) + "*";
str symbolName(\iter(Symbol s)) = symbolName(s) + "+";
str symbolName(\iter-seps(Symbol s, _)) = symbolName(s) + "+";
str symbolName(label(_, Symbol s)) = symbolName(s);
str symbolName(\start(Symbol s)) = symbolName(s);


// find templates for classes in t, substituting arguments to placeholders
// (if no templates are found, create from grammar, with default layout)
map[str, Tree] templates(Tree t, set[str] classes) = ();


Production findProd(type[&T<:Tree] tt, str class) {
  srt = sort(class);
  
  if (srt in tt.definitions, size(tt.definitions[srt].alternatives) == 1, Production p <- tt.definitions[srt].alternatives) {
    return p;
  }
  
  if (Symbol s <- tt.definitions, Production p <- tt.definitions[s].alternatives, p.def is label, p.def.name == class) {
    return p;
  }
  
  throw "No production for <class>";
}

Tree prod2tree(Production p) = appl(p, [ symbol2tree(s) | Symbol s <- p.symbols ]);
  
Tree symbol2tree(label(str field, Symbol s)) = placeholder(s, field);

Tree symbol2tree(lit(str x)) = appl(prod(lit(x), [], {}), [ char(i) | int i <- chars(x) ]);

Tree symbol2tree(s:layouts(_)) = appl(prod(s, [], {}), [ char(i) | int i <- chars(" ") ]); 



Tree addLoc(Tree t, Tree old) = (old has \loc) ? t[@\loc=old@\loc] : t;  
  
Tree setArg(t:appl(Production p, list[Tree] args), int i, Tree a)
  = addLoc(appl(p, args[0..i] + [a] + args[i+1..]), t);
  
list[Tree] getSeparators(Tree lst) {
  assert lst.prod is regular;
  s = lst.prod.def;
  int sepSize = 0;
  if (s is \iter-seps || s is \iter-star-seps) {
    sepSize = size(s.separators);
  }
  if (size(lst.args) > 1) {
     return sepSize > 0 ? lst.args[1..1+sepSize] : [];
  }
  return [ symbol2tree(sep) | Symbol sep <- s.separators ]; 
}
  
    
Tree insertList(Tree t, int pos, Tree x, list[Tree] seps) {
  assert t.prod is regular;
  sepSize = size(seps);
    
  int idx = pos * (sepSize + 1);
  
  if (idx == 0, t.args == []) {
    return addLoc(appl(t.prod, [x]), t);
  }  
  
  if (idx == 0 || idx == 1 + sepSize, size(t.args) == 1) {
    if (idx == 0) {
      return addLoc(appl(t.prod, [x] + seps + t.args), t);
    }
    if (idx == 1 + sepSize) {
      return addLoc(appl(t.prod, t.args + seps + [x]), t);
    }
  }
  
  assert size(t.args) > 1;
  
  if (idx >= size(t.args)) {
    return addLoc(appl(t.prod, t.args + seps + [x]), t);
  }
  
  if (idx == 0) {
    return addLoc(appl(t.prod, [x] + seps + t.args), t);
  }
  
  return addLoc(appl(t.prod, t.args[0..idx]  + [x] + seps + t.args[idx..]), t);
}  
  
  
Tree removeList(Tree t, int pos, list[Tree] seps) {
  assert t.prod is regular;
  sepSize = size(seps);

  int idx = pos * (sepSize + 1);
  
  // singleton
  if (idx == 0, size(t.args) == 1) {
    return addLoc(appl(t.prod, []), t);
  }
  
  
  // last one
  if (idx - sepSize == size(t.args) - 1) {
    return addLoc(appl(t.prod, t.args[0..-(1 + sepSize)]), t);
  }

  
  if (idx == 0) {
    return addLoc(appl(t.prod, t.args[idx+sepSize+1..]), t);
  }
  
  // default: also remove separators.
  return addLoc(appl(t.prod, t.args[0..idx] + t.args[idx+sepSize+1..]), t);  
}


map[str, Tree] unDeref(Tree tree, str path, map[str,Tree] env, map[Id, Tree] objs, value target, Symbol s, str field) 
  = unDeref(tree, splitPath(path), env, objs, target, s, field);

// start with the root.
map[str, Tree] unDeref(Tree tree, list[str] elts, map[str,Tree] env, map[Id, Tree] objs, value target, Symbol s, str field) {
  // ASSERT: tree is unflattened (no more CONTAIN nodes).

  if (elts == []) {
    return env;
  }
  
  cur = elts[0];
  
  if (/^<fld:[a-zA-Z0-9_]+>$/ := cur) {
    int idx = getFieldIndex(tree.prod, fld);
    return unDeref(tree.args[idx], elts[1..], env, orgs, target, s, field);
  }

  if (/^<fld:[a-zA-Z0-9_]+>\[<idx:[0-9_]+>$/ := cur) {
    int fldIdx = getFieldIndex(tree.prod, fld);
    Tree lst = tree.args[fldIdx];
    realIdx = toInt(idx) * (size(lst.prod.def.separators) + 1);
    return unDeref(lst.args[realIdx], elts[1..], env, orgs, target, s, field);
  }
  
  if (/^<fld:[a-zA-Z0-9_]+>\[<key:[a-zA-Z0-9_]+>=\$<var:[a-zA-Z0-9_]+>\]$/ := cur) {
    int idx = getFieldIndex(tree.prod, fld);
    Tree lst = tree.args[idx];
    delta = size(getSeparators(lst)) + 1;
    if (int i <- [0,delta..size(lst.args)], /Tree t := lst.args[i], target in objs, t == objs[target]) {
      int subIdx = getFieldIndex(lst.args[i].prod, key);
      Tree val = lst.args[i].args[subIdx];
      env[var] = val;
      return unDeref(t, elts[1..], env, objs, target, s, field);
    }
    
    return (var: placeholder(s, field));
  }
  
  throw "Invalid path element <cur>";  
}


Tree flatten(t:appl(Production p, list[Tree] args), Tree root, rel[Id, loc] orgs) 
  = addLoc(appl(p, [ flattenArg(args[i], t, root, p.symbols[i], orgs) | int i <- [0..size(args)] ]), t);
  
Tree flattenArg(a:appl(prod(sort(_), _, _), _), Tree parent, Tree root, Symbol s, rel[Id, loc] orgs) 
  = contain(obj)
  when loc l := a@\loc, <Id obj, l> <- orgs;

Tree flattenArg(a:appl(p:prod(_, _, _), _), Tree parent, Tree root, label(str field, Symbol _), rel[Id, loc] orgs) 
  = refer(path, deref(root, substBindings(path, treeEnv(parent)), orgs))
  when <field, _, str path> <- prodRefs(parent.prod);

Tree flattenArg(a:appl(p:regular(Symbol reg), list[Tree] args), Tree parent, Tree root, Symbol s, rel[Id, loc] orgs)
  =  addLoc(appl(p, [ flattenArg(elt, a, root, reg.symbol, orgs) | Tree elt <- args]), a);

default Tree flattenArg(Tree a, Tree parent, Tree root, Symbol s, rel[Id, loc] orgs) = a;

lrel[str, value] treeEnv(Tree t)
  = [ <fld, t.args[getFieldIndex(t.prod, fld)]> | label(str fld, _) <- t.prod.symbols ];


Tree valToTree(value v, type[&T<:Tree] tt, Production p, str field, Symbol s, Tree(type[&U<:Tree], str) parse) {
  switch (v) {
    case null():
      // todo: if there's something already in the tree, reuse that
      // so that user's partial ids for references are not deleted.
      return placeholder(s, field);
    
    case Id x: {
      if (<field, _, str path> <- prodRefs(p)) {
        return refer(path, x);
      }
      return contain(x);
    }
    
    default: {
      Symbol nt = (s is label ? s.symbol : s);
      src = "<v>";
      if (src == "") {
        return placeholder(nt, field);
      }
      println("PARSING `<src>` as <nt>");
      return parse(typeCast(#type[&T<:Tree], type(nt, tt.definitions)), src);
    }
  } 
}
  



Production containProd(Id id) = prod(lit("CONTAIN"), [], {\tag("id"(id))}); 
Production referProd(str path, value x) =  prod(lit("REF"), [], {\tag("path"(path, x))});

Id containedId(appl(prod(lit("CONTAIN"), [], {\tag("id"(Id x))}), _)) = x;

Tree contain(Id id) 
  = appl(containProd(id), [ char(i) | int i <- chars("CONTAIN") ]);

Tree refer(str path, value x) 
  = appl(referProd(path, x), [ char(i) | int i <- chars("REF") ]);


value deref(Tree t, str path, rel[Id, loc] orgs)
  = deref(t, splitPath(path), orgs);

value deref(Tree t, list[str] elts, rel[Id, loc] orgs) {
  if (elts == []) {
    if (loc l := t@\loc, <Id x, l> <- orgs) {
      return x;
    }
    return null();
  }
  
  cur = elts[0];
  
  if (/^<fld:[a-zA-Z0-9_]+>$/ := cur) {
    int idx = getFieldIndex(t.prod, fld);
    return deref(t.args[idx], elts[1..], orgs);
  }

  if (/^<fld:[a-zA-Z0-9_]+>\[<idx:[0-9_]+>$/ := cur) {
    int fldIdx = getFieldIndex(t.prod, fld); 
    if (Tree lst := t.args[fldIdx], lst.prod is regular) {
      int sepSize = (lst.prod.def is \iter-seps || lst.prod.def is \iter-star-seps) ? size(lst.prod.def.separators) : 0; 
      int i = toInt(idx) * (sepSize + 1);
      return deref(lst.args[i], elts[1..], orgs);
    }
    throw "Cannot index on non-list property: <t.args[fldIdx]>";
  }
  
  if (/^<fld:[a-zA-Z0-9_]+>\[<key:[a-zA-Z0-9_]+>=<val:[^\]]*>\]$/ := cur) {
    int fldIdx = getFieldIndex(t.prod, fld); 
    if (Tree lst := t.args[fldIdx], lst.prod is regular) {
	    int sepSize = (lst.prod.def is \iter-seps || lst.prod.def is \iter-star-seps) ? size(lst.prod.def.separators) : 0;
	    for (int i <- [0,sepSize+1..size(lst.args)]) {
	      Tree kid = lst.args[i];
	      int keyIdx = getFieldIndex(kid.prod, key);
	      if ("<kid.args[keyIdx]>" == val) {
	        return deref(kid, elts[1..], orgs);
	      }
	    }
	    return null();
    } 
    
    throw "Cannot filter on non-list property: <t.args[fldIdx]>";
  }
  
  throw "Invalid path element <cur>";
}

Tree resolveTree(Tree t, Tree root, map[Id, Tree] objs) {
  if (appl(_, _) !:= t) {
    return t;
  }
  
  env = ();
  
  int i = 0;
  args = for (Tree a <- t.args) {
    // if a is a crossref (e.g., "initial"), then we solve for the key value
    if (a has prod, prod(lit("REF"), [], {\tag("path"(str path, value x))}) := a.prod)  {
      Symbol s = t.prod.symbols[i];
      str fld = s.name; // assume labeled
      env += unDeref(root, path, (), objs, x, s, fld);
      append a; // for now, substituted below. 
    }
    else {
      append resolveTree(a, root, objs);
    } 
    i += 1;     
  }
  
  for (str fld <- env) {
    int idx = getFieldIndex(t.prod, fld);
    args[idx] = env[fld];
  }

  return addLoc(appl(t.prod, args), t);
}

map[Id, Tree] unflatten(Id x, map[Id, Tree] objs) {
  args = for (Tree a <- objs[x].args) {
    if (!(a has prod)) {
      append a;
      continue;
    }
    switch (a.prod) {
      case prod(lit("CONTAIN"), [], {\tag("id"(Id y))}): {
        objs = unflatten(y, objs);
        append objs[y];
      }
       
      case regular(_): {
        //TODO: refactor here...
        lstArgs = for (Tree elt <- a.args) {
          if (!(elt has prod)) { append elt; continue; }
          switch (elt.prod) {
             case prod(lit("CONTAIN"), [], {\tag("id"(Id y))}): {
		        objs = unflatten(y, objs);
		        append objs[y];
             }
             
             default: append elt;
          }
        }
        append addLoc(appl(a.prod, lstArgs), a);
      }
        
      default:
        append a;
    }
  }
  objs[x] = addLoc(appl(objs[x].prod, args), objs[x]);
  return objs;
}


int getFieldIndex(Production p, str fld) {
  if (int i <- [0..size(p.symbols)], p.symbols[i] is label, p.symbols[i].name == fld) {
    return i;
  }
  return -1;
}

