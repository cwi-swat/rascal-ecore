module lang::ecore::tests::Trafos

import lang::ecore::tests::MetaModel;
import lang::ecore::Refs;
import List;

Machine appendState(Machine m, str name = "NewState") {
  r = newRealm();
  s = r.new(#State, State(name, []));
  m.states += [s];
  return m;
}

Machine createFromScatch() {
  r = newRealm();
  s1 = r.new(#State, State("closed", []));
  s2 = r.new(#State, State("opened", []));
  s1.transitions += [r.new(#Trans, Trans("open", referTo(#State, s2)))];
  s2.transitions += [r.new(#Trans, Trans("close", referTo(#State, s1)))];
  m = r.new(#Machine, Machine("doors", [s1, s2]));
  m.initial = referTo(#State, s1);
  return m;
}

Machine prependState(Machine m, str name = "NewState") {
  r = newRealm();
  s = r.new(#State, State(name, []));
  m.states = [s] + m.states;
  return m;
}

Machine(Machine) removeStateAt(int idx) {
  return Machine(Machine m) {
    m.states = delete(m.states, idx);
    return m;
  };
}

Machine(Machine) swapState(int i, int j) {
  return Machine(Machine m) {
    tmp = m.states[i];
    m.states[i] = m.states[j];
    m.states[j] = tmp;
    return m;
  };
}


Machine(Machine) setMachineName(str name) {
  return Machine(Machine m) {
    m.name = name;
    return m;
  };
}

Machine(Machine) setStateName(int idx, str name) {
  return Machine(Machine m) {
    s = m.states[idx];
    s.name = name;
    m.states[idx] = s;
    return m;
  };
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