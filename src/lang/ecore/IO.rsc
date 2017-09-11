module lang::ecore::IO

import lang::ecore::Diff;
import lang::ecore::Refs;

// NB: this module requires the rascal jar in the lib directory.
// It can be downloaded here: 
// https://update.rascal-mpl.org/console/rascal-shell-unstable.jar
// (don't commit to github...)

@javaClass{lang.ecore.IO}
java &T<:node load(type[&T<:node] meta, loc uri);

@javaClass{lang.ecore.IO}
java void save(&T<:node model, loc uri);


/*
 * do = doIt(#Machine, |file:///doors|);
 * do((Machine m) { return trafo(m); });
 * whenever you call do, it will load the model from the editor
 * provide it to the closure, and update it with diff/patch
 * if the result is an updated model
 */

//void((&T<:node)(&T<:node)) doIt(type[&T<:node] meta, loc uri) {
//  patcher = editorFor(meta, uri);
//  return void((&T<:node)(&T<:node) f) {
//    patcher(Patch(&T<:node m1) {
//      m2 = f(m1);
//      return diff(meta, m1, m2); 
//    });
//  };
//}


