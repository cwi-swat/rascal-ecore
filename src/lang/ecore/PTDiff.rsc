module lang::ecore::PTDiff

import lang::ecore::LCS;

import ParseTree;
import String;
import List;
import IO;

str patch(str src, lrel[loc, str] diff) {
  int offset = 0;
  for (<loc l, str s> <- diff) {
    src = src[0..l.offset + offset] + s + src[l.offset + offset + l.length..];
    offset += size(s) - l.length;
  }
  return src;
}

lrel[loc, str] ptDiff(Tree old, Tree new) {
  diff = [];

  if (old is amb || new is amb) {
    throw "Ambiguous nodes not supported";
  }
  
  assert old has prod && new has prod;

  if (old.prod != new.prod) {
    return [<old@\loc, "<new>">];  
  }

  bool ptEq(Tree t1, Tree t2) = t1.prod == t2.prod;
  

  loc getLoc(Tree parent, Tree kid, int pos) {
    if (kid@\loc?) {
      return kid@\loc;
    }
    args = parent.args;
    src = ( "" | it + "<a>" | Tree a <- args[0..pos] );
    return parent@\loc[offset=parent@\loc.offset+size(src)];
  }
  
  if (old.prod is regular) {
    mx = lcsMatrix(old.args, new.args, ptEq);
    ds = getDiff(mx, old.args, new.args, size(old.args), size(new.args), ptEq);
    for (Diff d <- ds) {
      switch (d) {
        case add(Tree v, int pos): { 
          println("INSERTING `<v>`");
          diff += [<getLoc(old, old.args[pos], pos)[length=0], "<v>">];
        }
        
        case remove(Tree v, int pos): {
          println("DELETING `<v>`");
          diff += [<getLoc(old, v, pos), "">];
        }
          
        case same(Tree t1, Tree t2): {
          if (dontRecurse(t1.prod.def)) {
            if (!realEq(t1, t2)) {
              println("REPLACING `<t1>` with `<t2>`");
              diff += [<t1@\loc, "<t2>">];
            }
            else {
              ; //println("REALLY SAME: `<t1>` vs `<t2>`");
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
  
  assert size(old.args) == size(new.args);
  
  for (int i <- [0..size(old.args)]) {
    Tree oldArg = old.args[i];
    Tree newArg = new.args[i];
    //println("OLD: `<oldArg>`");
    //println("NEW: `<newArg>`");

    if (dontRecurse(oldArg.prod.def)) {
      if (!realEq(newArg, oldArg)) {
        println("REPLACING `<oldArg>` with `<newArg>`");
	    diff += [<old@\loc[offset=argOffset][length=size("<oldArg>")], "<newArg>">];
	  }
	  else {
	    ;
	    //println("REALLY SAME ARG: `<oldArg>` vs `<newArg>`");
	  }
    }
    else {
      diff += ptDiff(oldArg, newArg);
    }
    argOffset += size("<oldArg>");
  }  
  
  return diff;
}


bool realEq(appl(Production p, list[Tree] args1), appl(p, list[Tree] args2))
  = size(args1) == size(args2) && ( true | it && realEq(args1[i], args2[i]) | int i <- [0..size(args1)] );
  
bool realEq(char(int i), char(int j)) = i == j;  
  
default bool realEq(Tree _, Tree _) = false; 

bool dontRecurse(label(_, Symbol s)) = dontRecurse(s);
bool dontRecurse(lex(_)) = true;
bool dontRecurse(layouts(_)) = true;
bool dontRecurse(lit(_)) = true;
bool dontRecurse(cilit(_)) = true;
default bool dontRecurse(Symbol _) = false;


