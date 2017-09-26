module lang::ecore::tests::ModelSyntax

extend lang::ecore::Base;

// name is after class if iD = true

start syntax Machine
  = "Machine" Id name "{" MachineField* fields "}";
  
syntax MachineField
  = "states" ":" "[" State* states "]"
  | "initial" ":" Ref
  ;
  
syntax State
  = "State" Id name "{" StateField* fields "}";

syntax StateField
  = "transitions" ":" "[" Trans* transitions "]"
  ;

syntax Trans
  = "Trans" "{" TransField* fields "}";

syntax TransField
  = "events" ":" "[" Str* "]"
  | "target" ":" Ref
  ; 