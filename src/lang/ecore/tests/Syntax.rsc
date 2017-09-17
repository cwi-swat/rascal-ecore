module lang::ecore::tests::Syntax

extend lang::std::Layout;
extend lang::std::Id;

start syntax Machine
  = @ref{initial:State:/states[name=$initial]} 
  "machine" Id name "init" Id initial State* states "end"
  ;
  
syntax State
  = @id{"name"} "state" Id name Trans* transitions "end"
  ;
  
  
syntax Trans
  = @ref{target:State:/states[name=$target]} 
  "on" {Id ","}+ events "=\>" Id target 
  ;
  
