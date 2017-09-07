module lang::ecore::IO

import IO;

// NB: this module requires the rascal jar in the lib directory.
// It can be downloaded here: 
// https://update.rascal-mpl.org/console/rascal-shell-unstable.jar
// (don't commit to github...)

@javaClass{lang.ecore.IO}
java &T<:node load(type[&T<:node] meta, loc uri);

@javaClass{lang.ecore.IO}
java void save(&T<:node model, loc pkg, loc uri);
