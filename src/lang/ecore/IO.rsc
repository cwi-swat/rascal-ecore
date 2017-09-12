module lang::ecore::IO

import lang::ecore::Ecore;
import lang::ecore::Diff;
import lang::ecore::Refs;

// TODO: https://stackoverflow.com/questions/9386348/register-ecore-meta-model-programmatically


@javaClass{lang.ecore.IO}
java &T<:node load(type[&T<:node] meta, loc uri);


@javaClass{lang.ecore.IO}
java EPackage load(loc pkgURI, type[EPackage] ecore = #EPackage);


void save(&T<:node model, loc uri) = save(model, uri, model.pkgURI);

@javaClass{lang.ecore.IO}
private java void save(&T<:node model, loc uri, loc pkgURI);

@javaClass{lang.ecore.IO}
java void(Patch(&T<:node)) editor(type[&T<:node] meta, loc uri);


/*
 * do = editor(#Machine, |file:///doors|);
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


