module lang::ecore::Refs

import Type;
import Node;
import IO;

// just because Maybe is in the wrong tech space...
data Opt[&T]
  = just(&T \value)
  | none()
  ;

// refs are optional by default.
data Ref[&T]
  = ref(Id uid)
  | null()
  ; 

&T<:node lookup(node root, type[&T<:node] typ, Ref[&T] r) = aNode
  when /&T<:node aNode := root, getKeywordParameters(aNode)["uid"] == r.uid;
    

Ref[&T] referTo(type[&T<:node] typ, &T t) = ref(getId(t));


Id getId(&T<:node t) = x
  when Id x := getKeywordParameters(t)["uid"];
  
bool hasId(node t) = t has uid;

data Id 
  = id(int n)
  | id(loc uri);
 
alias Realm = tuple[&T(type[&T<:node], &T) new];

&T update(&T t, type[&U<:node] u, &U x) = bottom-up-break visit (t) {
     case &U y => x when getKeywordParameters(y)["uid"] == getKeywordParameters(x)["uid"]  
   };


Realm newRealm() {
  int idCount = -1; 

  Id newId() {
    idCount += 1;
    return id(idCount);
  }

  &T new(type[&T<:node] t, &T x) {
    return setKeywordParameters(x, ("uid": newId()) + getKeywordParameters(x)); 
  }

  return <new>;
}

Id noId() {
  throw "You should have used new to make things with ids.";
}
