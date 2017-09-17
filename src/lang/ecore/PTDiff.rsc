module lang::ecore::PTDiff

import lang::ecore::LCS;

import ParseTree;
import String;
import List;
import IO;

lrel[loc, str] ptDiff(Tree old, Tree new) {
  diff = [];

  if (old is amb || new is amb) {
    throw "Ambiguous nodes not supported";
  }
  
  assert old has prod && new has prod;

  if (old.prod != new.prod) {
    return [<old@\loc, "<new>">];  
  }

  assert old.prod == new.prod;
  
  bool ptEq(Tree t1, Tree t2) = t1.prod == t2.prod;
  

  loc getLoc(Tree parent, Tree kid, int pos) {
    if (kid@\loc?) {
      return kid@\loc;
    }
    args = parent.args;
    src = [ "<a>" | Tree a <- args[0..pos] ];
    return parent@\loc[offset=parent@\loc.offset+size(src)];
  }
  
  if (old.prod is regular) {
    mx = lcsMatrix(old.args, new.args, ptEq);
    ds = getDiff(mx, old.args, new.args, size(old.args), size(new.args), ptEq);
    for (Diff d <- ds) {
      switch (d) {
        case add(Tree v, int pos): 
          diff += [<getLoc(old, v, pos)[length=0], "<v>">];
        
        case remove(Tree v, int pos):  
          diff += [<getLoc(old, v, pos), "">];
          
        case same(Tree t1, Tree t2): {
          if (dontRecurse(t1.prod.def)) {
            if (t1 != t2) {
              diff += [<t1@\loc, "<t2>">];
            }
          }
          else {
            diff += ptDiff(t1, t2);
          }
        }
      }
    }
    return diff;
  }
  
  
  
  int argOffset = old@\loc.offset;
  for (int i <- [0..size(old.args)]) {
    Tree oldArg = old.args[i];
    Tree newArg = new.args[i];

    if (dontRecurse(oldArg.prod.def)) {
      if (newArg != oldArg) {
	    newSrc = "<newArg>";
	    diff += [<old@\loc[offset=argOffset][length=size("<oldArg>")], "<newArg>">];
	  }
    }
    else {
      diff += ptDiff(oldArg, newArg);
    }
    argOffset += size("<oldArg>");
  }  
  
  return diff;
}


bool dontRecurse(label(_, Symbol s)) = dontRecurse(s);
bool dontRecurse(lex(_)) = true;
bool dontRecurse(layouts(_)) = true;
bool dontRecurse(lit(_)) = true;
bool dontRecurse(cilit(_)) = true;
default bool dontRecurse(Symbol _) = false;


