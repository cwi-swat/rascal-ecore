module lang::ecore::IO

import lang::ecore::Diff;
import lang::ecore::Refs;

@javaClass{lang.ecore.IO}
java &T<:node load(type[&T<:node] meta, loc uri);

void save(&T<:node model, loc uri) = save(model, uri, model.pkgURI);

@javaClass{lang.ecore.IO}
private java void save(&T<:node model, loc uri, loc pkgURI);


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


