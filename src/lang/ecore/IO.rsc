module lang::ecore::IO

import lang::ecore::Ecore;
import lang::ecore::Diff;
import lang::ecore::Refs;
import util::Maybe;

// TODO: https://stackoverflow.com/questions/9386348/register-ecore-meta-model-programmatically

@doc{Load a model resource `uri` and "parse" it according to `meta`.} 
@javaClass{lang.ecore.IO}
java &T<:node load(type[&T<:node] meta, loc uri);


@doc{Load an Ecore meta model (an EPackage), identified by its `pkgURI` with which it's registered.}
@javaClass{lang.ecore.IO}
java EPackage load(loc pkgURI, type[EPackage] ecore = #EPackage);


@doc{Save a model to resource `uri`}
void save(&T<:node model, loc uri) = save(model, uri, model.pkgURI);

@javaClass{lang.ecore.IO}
private java void save(&T<:node model, loc uri, loc pkgURI);

@doc{Obtain and "editor" function to dynamically patch model editor contents of type `meta`.
Basic operation:

```
ed = editor(#MetaModel, |project://<someResourceBeingEdited>|);
ed(Patch(MetaModel m1) {
  m2 = trafo(m1);
  return diff(m1, m2);
});
```
}
@javaClass{lang.ecore.IO}
@reflect
java void(Patch(&T<:node)) editor(type[&T<:node] meta, loc uri, type[Patch] pt = #Patch);

void(Patch) patcher(type[&T<:node] meta, loc uri) {
  ed = editor(meta, uri); 
  return void(Patch p) {
    ed(Patch(&T<:node ignored) {
      return p;
    });
  };
}

void(&T<:node) reconciler(type[&T<:node] meta, loc uri) {
  void(Patch) patch = patcher(meta, uri);
  Maybe[&T<:node] prev = nothing();
  
  return void(&T<:node model) {
    if (just(&T<:node old) := prev) {
	  patch(diff(meta, old, model));
    }
    else {
      patch(create(meta, model));
    }
    prev = just(model);
  };
}

void((&T<:node)(&T<:node)) transformer(type[&T<:node] meta, loc uri) {
  void(Patch(&T<:node)) ed = editor(meta, uri);
  return void((&T<:node)(&T<:node) trafo) {
    ed(Patch(&T<:node current) {
      &T<:node new = trafo(current);
      return diff(meta, current, new);
    });
  };
}





