module lang::ecore::tests::TestPatch

extend lang::ecore::tests::Syntax; // bug in reifier.
import lang::ecore::tests::MetaModel;
import lang::ecore::tests::Trafos;

import lang::ecore::Tree2Model;
import lang::ecore::PatchTree;
import lang::ecore::Diff;
import lang::ecore::Refs;

import ParseTree;
import IO;
import String;


str tester(str src, lang::ecore::tests::MetaModel::Machine(lang::ecore::tests::MetaModel::Machine) trafo) {
  //gram = addPlaceholderProds(#lang::ecore::tests::Syntax::Machine);
  //type[lang::ecore::tests::Syntax::Machine] gram = #lang::ecore::tests::Syntax::Machine;
  lang::ecore::tests::Syntax::Machine pt = parse(#start[Machine], src, |project://rascal-ecore/src/lang/ecore/tests/someTest|).top;
  <m, orgs> = tree2modelWithOrigins(#lang::ecore::tests::MetaModel::Machine, pt);
  m2 = trafo(m);
  patch = diff(#lang::ecore::tests::MetaModel::Machine, m, m2);
  iprintln(patch);
  // and here it needs to be the non-start reified type...
  pt2 = patchTree(#lang::ecore::tests::Syntax::Machine, pt, patch, orgs, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  });
  newSrc = "<pt2>"; 
  println("Returning: <replaceAll(newSrc, " ", "_")>");
  return "<pt2>";
}

/*
 * Creation
 */
 
str createMachineResult() {
  m = createFromScatch();
  patch = create(#lang::ecore::tests::MetaModel::Machine, m);
  pt = (Machine)`machine X init Y end`;
  orgs = ();
  pt2 = patchTree(#lang::ecore::tests::Syntax::Machine, pt, patch, orgs, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  });
  newSrc = "<pt2>";
  return newSrc; 
  //machine doors init ⟨initial:Id⟩ state closed on open => ⟨target:Id⟩ end state opened on close => ⟨target:Id⟩ end end
}


/*
 * Insertion (plus creation)
 */

str addStateToEmptyResult() = tester("machine Doors
  									'init closed
  									'end", appendState);

test bool addStateToEmpty() 
  = addStateToEmptyResult() == 
  "machine Doors
  'init ⟨initial:Id⟩
  'state NewState  end
  'end";

str addStateToSingletonResult() = tester("machine Doors
  										'init closed
  										'state closed end
  										'end", appendState);

test bool addStateToSingleton() 
  = addStateToSingletonResult()
  ==
  "machine Doors
  'init closed
  'state closed end state NewState  end
  'end";
  
str addStateToManyResult() = tester("machine Doors
  								   'init closed
  								   'state closed end
  								   'state opened end
                                    'end", appendState);

test bool addStateToMany() 
  = addStateToManyResult()
  ==
  "machine Doors
  'init closed
  'state closed end
  'state opened end
  'state NewState  end
  'end";
  
  
str prependStateToSingletonResult() = tester("machine Doors
									        'init closed
									        'state closed end
									        'end", prependState);
									        
test bool prependStateToSingleton()
  = prependStateToSingletonResult()
  ==
  "machine Doors
  'init closed
  'state NewState  end state closed end
  'end";
  
str prependStateToManyResult() = tester("machine Doors
							           'init closed
							           'state closed end
							           'state opened end
							           'end", prependState);
									        
test bool prependStateToMany()
  = prependStateToManyResult()
  ==
  "machine Doors
  'init closed
  'state NewState  end
  'state closed end
  'state opened end
  'end";
  
/*
 * Removal from lists
 */
 

str removeSingletonResult() = tester("machine Doors
 									'init closed
 									'state closed end
 									'end", removeStateAt(0));

test bool removeSingleton()
  = removeSingletonResult()
  ==
  "machine Doors
  'init ⟨initial:Id⟩
  '
  'end";

str removeFromFrontResult() = tester("machine Doors
 									'init closed
 									'state closed end
 									'state opened end
 									'end", removeStateAt(0));

test bool removeFromFront()
  = removeFromFrontResult()
  == 
  "machine Doors
  'init ⟨initial:Id⟩
  'state opened end
  'end";
  

str removeFromEndResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state opened end
 								   'end", removeStateAt(1));

test bool removeFromEnd()
  = removeFromEndResult()
  ==
  "machine Doors
  'init closed
  'state closed end
  'end";
  

str removeFromMidResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state removed end
 								   'state opened end
 								   'end", removeStateAt(1));

test bool removeFromMid()
  = removeFromMidResult()
  ==
  "machine Doors
  'init closed
  'state closed end
  'state opened end
  'end";
  
  
/* 
 * Permutations
 */

str swapTwoStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state opened end
 								   'end", swapState(0, 1));

test bool swapTwoStates()
  = swapTwoStatesResult()
  ==
  "machine Doors
  'init closed
  'state opened end state closed end
  'end";


str swapBeginEndStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state A end
 								   'state B end
 								   'state C end
 								   'state opened end
 								   'end", swapState(0, 4));

test bool swapBeginEndStates()
  = swapBeginEndStatesResult()
  ==
  "machine Doors
  'init closed
  'state opened end
  'state A end
  'state B end
  'state C end
  'state closed end
  'end";

/*
 * Properties
 */
 

str setMachineNameResult() = tester("machine Doors
             					   'init closed
             					   'end", setMachineName("Foo"));
 
test bool setMachineName()
  = setMachineNameResult()
  ==
  "machine Foo
  'init ⟨initial:Id⟩
  'end"; 

str setStateNameWithRefResult() = tester("machine Doors
 										'init closed
 										'state closed end
 										'end", setStateName(0, "CLOSED"));
 										
test bool setStateNameWithRef()
  = setStateNameWithRefResult()
  == 
  "machine Doors
  'init CLOSED
  'state CLOSED end
  'end";
  
/*
 * Cross references.
 */
  
  
str setInitialToNullResult() = tester("machine Doors
                                      'init closed
                                      'state closed end
                                      'end", setInitial("nonExisting"));
                                      
test bool setInitialToNullGivesNullTree()
  = setInitialToNullResult()
  ==
  "machine Doors
  'init ⟨initial:Id⟩
  'state closed end
  'end";
  
  
str setInitialToExistingStateResult() = tester("machine Doors
                                               'init closed
                                               'state closed end
                                               'state opened end
                                               'end", setInitial("opened"));
                                               
test bool setInitialToExistingState()
  = setInitialToExistingStateResult()
  ==
  "machine Doors
  'init opened
  'state closed end
  'state opened end
  'end";
  
  
