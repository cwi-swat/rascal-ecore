module lang::ecore::IO

import IO;
import rmt::meta::Activities;
import rmt::Refs;

// NB: this module requires the rascal jar in the lib directory.
// It can be downloaded here: 
// https://update.rascal-mpl.org/console/rascal-shell-unstable.jar
// (don't commit to github...)

void smokeTest() {

	//Just to test:
	Activity x = load(#Activity, |project://org.modelexecution.operationalsemantics.ad.test/model/xmi/test1.xmi| );
	println("x = <x>");
	
	aRef = x.edges[0].source;
	println("\nResolve crossref: <lookup(x, #ActivityNode, aRef)>");

  //Foo x = load(#Foo, |file:///|);
  //println("x = <x>");
  //assert x == foo();
}

@reflect
@javaClass{lang.ecore.IO}
java &T<:node load(type[&T<:node] meta, loc src);

