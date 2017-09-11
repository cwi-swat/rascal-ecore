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

bool isRef(Ref[void] _) = true;

default bool isRef(node _) = false;

bool isObj(node n) = !isRef(n) && hasId(n);

data Id 
  = id(int n)
  | id(loc uri);
 
alias Realm = tuple[&T(type[&T<:node], &T) new];

&T update(&T t, type[&U<:node] u, &U x) = bottom-up-break visit (t) {
     case &U y => x when getKeywordParameters(y)["uid"] == getKeywordParameters(x)["uid"]  
   };


&T<:node setId(&T<:node x, Id id) = 
  setKeywordParameters(x, getKeywordParameters(x) + ("uid": id));

&T<:node become(&T<:node x, Id id) = new
  when &T new := setId(x, id); 


Realm newRealm() {
  int idCount = -1; 

  Id newId() {
    idCount += 1;
    return id(idCount);
  }

  &T new(type[&T<:node] t, &T x, Id id = newId()) {
    return setId(x, id); 
  }

  return <new>;
}

Id noId() {
  throw "You should have used new to make things with ids.";
}

loc noLoc() {
  throw "No location has been set";
}
