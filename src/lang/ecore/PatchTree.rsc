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



Tree placeholder(Symbol s, str field) {
  if (s is opt || s is \iter-star || s is \iter-star-seps) {
    return appl(regular(s), []);
  }
  str src = "\<<field>: <symbolName(s)>\>";
  return appl(prod(s, [lit(src)], {\tag("category"("MetaAmbiguity"))}), [ char(i) | int i <- chars(src) ]);
}
  
str symbolName(sort(str n)) = n;
str symbolName(lex(str n)) = n;
str symbolName(\opt(Symbol s)) = symbolName(s) + "?";
str symbolName(\iter-star(Symbol s)) = symbolName(s) + "*";
str symbolName(\iter-star-seps(Symbol s, _)) = symbolName(s) + "*";
str symbolName(\iter(Symbol s)) = symbolName(s) + "+";
str symbolName(\iter-seps(Symbol s, _)) = symbolName(s) + "+";

Tree nullTree(Symbol s, str field)
  = appl(prod(s, [lit(src)], {\tag("category"("MetaAmbiguity"))}), [ char(i) | int i <- chars(src) ])
  when str src := "\<<field>:null\>";
  
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

Tree prod2tree(Production p)
  = appl(p, [ symbol2tree(s) | Symbol s <- p.symbols ]);
  
Tree symbol2tree(label(str field, Symbol s)) = placeholder(s, field);

Tree symbol2tree(lit(str x)) = appl(prod(lit(x), [], {}), [ char(i) | int i <- chars(x) ]);

Tree symbol2tree(s:layouts(_)) = appl(prod(s, [], {}), [ char(i) | int i <- chars(" ") ]); 



Tree addLoc(Tree t, Tree old)
 = (old has \loc) ? t[@\loc=old@\loc] : t;  
  
Tree setArg(t:appl(Production p, list[Tree] args), int i, Tree a)
  = addLoc(appl(p, args[0..i] + [a] + args[i+1..]), t);
  //when bprintln("Setting arg <i> on <t>, to <a>");  
  
Tree insertList(Tree t, int pos, Tree x) {
  assert t.prod is regular;
 
  println("Inserting: <x> at <pos>");
  //println("The list is: <t>");
  
  
  s = t.prod.def;
  int sepSize = 0;
  list[Symbol] seps = [];
  if (s is \iter-seps || s is \iter-star-seps) {
    seps = s.separators;
  }
  sepSize = size(seps);
    

  // x s1 s2 s3 y s1 s2 s3 z
  // 0 1   2  3 4  5  6  7  8
  // 0          1           2
  
  // x s y s z s a s b
  // 0 1 2 3 4 5 6 7 8
  // 0   1   2   3   4
  int idx = pos * (sepSize + 1);
  
  if (idx == 0, t.args == []) {
    return addLoc(appl(t.prod, [x]), t);
  }  
  
  println("idx = <idx>; sepsize = <sepSize>");
  println(idx == 1 + sepSize);
  println(size(t.args));
  
  if (idx == 0 || idx == 1 + sepSize, size(t.args) == 1) {
    sepTrees = [ symbol2tree(sep) | Symbol sep <- s.separators ];
    println("Adding to singleton");
    if (idx == 0) {
      return addLoc(appl(t.prod, [x] + sepTrees + t.args), t);
    }
    if (idx == 1 + sepSize) {
      return addLoc(appl(t.prod, t.args + sepTrees + [x]), t);
    }
  }
  
  assert size(t.args) > 1;
  
  println("We have size \> 1");
  
  list[Tree] sepTrees = sepSize > 0 ? t.args[1..1+sepSize] : [];
  println("SEPS:");
  for (Tree z <- sepTrees) {
    println("- `<z>`");
  }
  
  if (idx >= size(t.args)) {
    println("Appending at the end");
    return addLoc(appl(t.prod, t.args + sepTrees + [x]), t);
  }
  
  if (idx == 0) {
    println("Prepending at the beginning");
    return addLoc(appl(t.prod, [x] + sepTrees + t.args), t);
  }
  
  println("IDX = <idx>; ");
  println("Size(args) = <size(t.args)>");
  return addLoc(appl(t.prod, t.args[0..idx] + sepTrees + [x] + t.args[idx..]), t);
}  
  
Tree removeList(Tree t, int pos) {
  assert t.prod is regular;
  s = t.prod.def;
  int sepSize = 0;
  if (s is \iter-seps || s is \iter-star-seps) {
    sepSize = size(s.separators);
  }
  // [0, s1 s2 s3, 1

  int idx = pos * (sepSize + 1);
  
  println("IDX for removal: <idx> (was <pos>)");
  // seems the diff is bad: it should have deleted 2, not 1
  // bla sep closed sep opened
  // 0         1          2
  
  // last one
  if (idx == size(t.args) - 1) {
    println("Removing last one.");
    return addLoc(appl(t.prod, t.args[0..-(1 + sepSize)]), t);
  }

  // singleton
  if (idx == 0, size(t.args) == 1) {
    println("Removing only one");
    return addLoc(appl(t.prod, []), t);
  }
  
  if (idx == 0) {
    println("Removing first one");
    return addLoc(appl(t.prod, t.args[idx+sepSize..]));
  }
  
  // default: also remove separators.
  println("Removing <t.args[idx]>");
  return appl(t.prod, t.args[0..idx] + t.args[idx+sepSize+1..])[@\loc=t@\loc];  
}


// start with the root.
map[str, Tree] unDeref(Tree tree, list[str] elts, map[str,Tree] env, map[Id, Tree] objs, Id target) {
  //println("Elts: <elts>");
  if (elts == []) {
    return env;
  }
  
  cur = elts[0];
  //println("Undereffing <cur>");
  
  if (/^<fld:[a-zA-Z0-9_]+>$/ := cur) {
    int idx = getFieldIndex(tree.prod, fld);
    return unDeref(tree.args[idx], elts[1..], env, orgs, target);
  }

  if (/^<fld:[a-zA-Z0-9_]+>\[<idx:[0-9_]+>$/ := cur) {
    int fldIdx = getFieldIndex(tree.prod, fld);
    Tree lst = tree.args[fldIdx];
    realIdx = toInt(idx) * (size(lst.prod.def.separators) + 1);
    return unDeref(lst.args[realIdx], elts[1..], env, orgs, target);
  }
  
  if (/^<fld:[a-zA-Z0-9_]+>\[<key:[a-zA-Z0-9_]+>=\$<var:[a-zA-Z0-9_]+>\]$/ := cur) {
    int idx = getFieldIndex(tree.prod, fld);
    Tree lst = tree.args[idx];
    delta = size(lst.prod.def.separators) + 1;
    if (int i <- [0,delta..size(lst.args)], /Tree t := lst.args[i], t == objs[target]) {
     int subIdx = getFieldIndex(lst.args[i].prod, key);
     Tree val = lst.args[i].args[subIdx];
     //println("Binding <var> to <val>");
     env[var] = val;
     return unDeref(t, elts[1..], env, objs, target);
    }
    throw "Did not find target <target> in <lst>";  
  }
  
  
}

&T<:Tree patchTree(type[&T<:Tree] tt, &T<:Tree pt, Patch patch, Org origins, Tree(type[&U<:Tree], str) parse) {
  Tree old = pt;
  if (pt has top) {
    old = pt.top;
  }
 
  rel[Id, loc] orgs = { <k, origins[k]> | k <- origins };
  trees = ( obj: t | /Tree t := old, t has \loc, loc l := t@\loc, <Id obj, l> <- orgs );
  trees += ( obj: prod2tree(findProd(tt, class)) | <Id obj, create(str class)> <- patch.edits );
  
  Tree valToTree(Production p, str field, Symbol s, value v) {
    //println("Converting <field> = <v>");
    int idx = getFieldIndex(p, field);
    xref = (<field, _, _> <- prodRefs(p));
    switch (v) {
      case null(): // BUG: edits contain ids, not refs!!!s 
        // the a argument is only always available for put...
        return xref ? nullTree(p.def, field) : placeholder(s, field);
      
      case Id x:
        if (<field, _, str path> <- prodRefs(p)) {
          return refer(path, x);
        }
        else {
          return contain(x);
        }
        
      default: {
        Symbol nt = s is label ? s.symbol : s;
        //println("Parsing <v> as <nt>");  
        return parse(typeCast(#type[&T<:Tree], type(nt, tt.definitions)), "<v>");
      }

    }
  }
  
  for (<Id obj, Edit edit> <- patch.edits) {
     switch (edit) {
       case put(str field, value v): {
         Tree t = trees[obj];
         int idx = getFieldIndex(t.prod, field);
         trees[obj] = setArg(t, idx, valToTree(trees[obj].prod, field, t.prod.symbols[idx], v));
       }
       
       case ins(str field, int pos, value v): {
         println("INSERT: <field>[<pos>] = <v>");
         Tree t = trees[obj];
         int idx = getFieldIndex(t.prod, field);
         println("t.prod = <t.prod>");
         println("IDX = <idx>");
         lst = t.args[idx];
         println(lst.prod);
         lst = insertList(lst, pos, valToTree(t.prod, field, lst.prod.def.symbol, v));
         // check for empty layout
         if ("<t.args[idx+1]>" == "") {
           // reuse layout that is before.
           t = setArg(t, idx + 1, t.args[idx-1]);
         }
         trees[obj] = setArg(t, idx, lst);
       }

       case del(str field, int pos): {
         Tree t = trees[obj];
         int idx = getFieldIndex(t.prod, field);
         lst = t.args[idx];
         lst = removeList(lst, pos);
         trees[obj] = setArg(t, idx, lst);
       }

     }
   }
   
  Tree root = makeTree(trees[patch.root], trees);
  if (pt has top) {
    root = addLoc(appl(pt.prod, [pt.args[0], root, pt.args[2]]), pt);
  }
  return typeCast(tt, resolveTree(root, root, trees)); 
}



bool hasId(Tree t, Id target, rel[Id, loc] orgs) {
  if (t@\loc?, loc l := t@\loc, <target, l> <- orgs) {
    return true;
  }
  return t has prod && prod(lit("CONTAIN"), [], {\tag("id"(target))}) := t.prod;
} 
 

Tree contain(Id id) 
  = appl(prod(lit("CONTAIN"), [], {\tag("id"(id))}), [ char(i) | int i <- chars("CONTAIN") ]);

Tree refer(str path, Id id) 
  = appl(prod(lit("REF"), [], {\tag("pathId"(<path, id>))}), [ char(i) | int i <- chars("REF") ]);


Tree resolveTree(Tree t, Tree root, map[Id, Tree] objs) {
  if (appl(_, _) !:= t) {
    return t;
  }
  env = ();
  args = for (Tree a <- t.args) {
    if (a has prod, prod(lit("REF"), [], {\tag("pathId"(<str path, Id x>))}) := a.prod)  {
      env = unDeref(root, split("/", path)[1..], (), objs, x);
      append a; // for now, substituted below. 
    }
    else {
      append resolveTree(a, root, objs);
    }      
  }
  
  for (str fld <- env) {
    //println("FLD <fld>");
    int idx = getFieldIndex(t.prod, fld);
    //println("Idx = <idx>");
    //println(args);
    args[idx] = env[fld];
  }

  return addLoc(appl(t.prod, args), t);
}

Tree makeTree(t:appl(Production p, list[Tree] args), map[Id, Tree] objs) {

  args = for (Tree a <- args) {
    if (!(a has prod)) {
      append a;
      continue;
    }
    switch (a.prod) {
      case prod(lit("CONTAIN"), [], {\tag("id"(Id x))}): {
        println("Found contain: <x>");
        //println("TREE: <objs[x]>");
        append makeTree(objs[x], objs);
      }
        
      default:
        append makeTree(a, objs);
    }
  }  

  return addLoc(appl(p, args), t);
}
  

int getFieldIndex(Production p, str fld) {
  if (int i <- [0..size(p.symbols)], p.symbols[i] is label, p.symbols[i].name == fld) {
    return i;
  }
  return -1;
}

&T<:node patchTree_(type[&T<:Tree] tt, &T<:node old, Patch patch, Org origins) {

   rel[Id, loc] orgs = { <k, origins[k]> | k <- origins };
   
   map[Id, Tree] trees = ( k: t | /Tree t := old, t has \loc, loc l := t@\loc, <Id k, l> <- orgs ); 
   



   for (<Id obj, Edit edit> <- patch.edits) {
     switch (edit) {
       case create(str class): { 
         // TODO: use old to find a template if it exists, otherwise do default layout.
         trees[obj] = prod2tree(findProd(tt, class));
         origins[obj] = id.uri; // use id loc as unique source loc for now
       }
       
       // NB: if ref is null, the placeholder will stay (leading to parse errors)
       case put(str field, ref(Id to)): {
         Tree t = trees[obj];
         int idx = getFieldIndex(t.prod, field);
         if (<field, _, str path> <- prodRefs(t.prod)) {
           trg = trees[to];
           Tree key = unresolve(trg, path);
           t.args[idx] = key;
         }
         else {
           // can it happen that trees[to] still needs updates?
           // in that case, we copy too early here.
           // need to schedule for later...
           // also children might be out of data...
           t.args[idx] = trees[to]; 
         }
         trees[obj] = t;
       }
       
       case put(str field, value v): {
         int idx = getFieldIndex(t.prod, field);
         Symbol s = t.prod.symbols[idx];
         trees[obj].args[idx] = parse(type(s, tt.definitions), "<v>");
       }
       
       case ins(str field, int pos, ref(Id to)): ;

       case ins(str field, int pos, value v): ;

       case del(str field, int pos): ;

       case destroy(): ;
       
     }
   }
}

