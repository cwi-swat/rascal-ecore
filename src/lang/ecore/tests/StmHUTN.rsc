module lang::ecore::tests::StmHUTN

extend lang::ecore::Base;
import util::IDE;
import ParseTree;


syntax Group_Field =
   states: "states"  ":"  "["  State*  "]" 
  | @inject State_Field 
  ;

syntax Group =
  @Foldable Group: "Group"  Str name  "{"  Group_Field* fields  "}" 
  ;

syntax Trans =
  @Foldable Trans: "Trans"  "{"  Trans_Field* fields  "}" 
  ;

syntax State_Field =
   final: "final"  ":"  Bool 
  |  transitions: "transitions"  ":"  "["  Trans*  "]" 
  |  name: "name"  ":"  Str 
  ;

syntax Trans_Field =
   target: "target"  ":"  Ref[State] 
  |  events: "events"  ":"  "["  Str*  "]" 
  |  guard: "guard"  ":"  Str 
  ;

syntax Machine_Field =
   initial: "initial"  ":"  Ref[State] 
  |  states: "states"  ":"  "["  State*  "]" 
  |  name: "name"  ":"  Str 
  ;

start syntax Machine =
  @Foldable Machine: "Machine"  Str name  "{"  Machine_Field* fields  "}" 
  ;

syntax State =
  @inject Group 
  | @Foldable State: "State"  Str name  "{"  State_Field* fields  "}" 
  ;


start[Machine] parseMyfsm(str src, loc l)
  = parse(#start[Machine], src, l);

void main() {
  registerLanguage("myfsm", "myfsm_hutn", start[Machine](str src, loc org) {
    return parseMyfsm(src, org);
  });
}