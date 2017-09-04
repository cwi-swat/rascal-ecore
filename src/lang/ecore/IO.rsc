module lang::ecore::IO

import IO;

// NB: this module requires the rascal jar in the lib directory.
// It can be downloaded here: 
// https://update.rascal-mpl.org/console/rascal-shell-unstable.jar
// (don't commit to github...)

data Foo
  = foo();


void smokeTest() {
  Foo x = load(#Foo, |file:///|);
  println("x = <x>");
  assert x == foo();
  x2 = patch(x, |file:///|);
  assert x2 == x; 
}

// for now, value :-(
@javaClass{lang.ecore.IO}
java value load(type[&T<:node] meta, loc src);

