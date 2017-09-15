module lang::ecore::tests::Trafos

import lang::ecore::tests::MetaModel;
import lang::ecore::Refs;

Machine appendState(Machine m, str name = "NewState") {
  r = newRealm();
  s = r.new(#State, State(name, []));
  m.states += [s];
  return m;
}

Machine prependState(Machine m, str name = "NewState") {
  r = newRealm();
  s = r.new(#State, State(name, []));
  m.states = [s] + m.states;
  return m;
}

Machine(Machine) setInitial(str name) {
  return Machine(Machine m) {
    if (State s <- m.states, s.name == name) {
      m.initial = referTo(#State, s);
    }
    else {
      m.initial = null();
    }
    return m;
  };
}