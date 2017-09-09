module lang::ecore::IO

import lang::ecore::Diff;
import lang::ecore::Refs;

// NB: this module requires the rascal jar in the lib directory.
// It can be downloaded here: 
// https://update.rascal-mpl.org/console/rascal-shell-unstable.jar
// (don't commit to github...)

@javaClass{lang.ecore.IO}
@reflect{IO}
java &T<:node load(type[&T<:node] meta, loc uri);

@javaClass{lang.ecore.IO}
java void save(&T<:node model, loc pkg, loc uri);

void save(type[&T<:node] meta, &T model, loc uri) {
  old = load(meta, uri);
  patch = diff(meta, old, new);
  patchOnDisk(patch, uri);
}

@javaClass{lang.ecore.IO}
@reflect{IO}
java map[int, loc] patchOnDisk(Patch patch, loc uri);

&T<:node endoTransform(type[&T<:node] meta, &T<:node model, loc uri, &T(&T) trafo) {
  newModel = trafo(model);
  m = patch(diff(meta, model, newModel), uri);
  return rekey(m, newModel);
}


&T<:node rekey(map[int, loc] m, &T<:node model) {
  return visit (model) {
    case &U<:node n => become(n, id(m[i]))
      when isObj(n), id(int i) := getId(n)
  };
}
