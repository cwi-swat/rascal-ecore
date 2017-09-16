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
  //iprintln(patch);
  // and here it needs to be the non-start reified type...
  pt2 = patchTree(#lang::ecore::tests::Syntax::Machine, pt, patch, orgs, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  });
  newSrc = "<pt2>"; 
  return "<pt2>";
}

/*
 * Creation
 */
 
str createMachineResult() {
  m = createFromScatch();
  patch = create(#lang::ecore::tests::MetaModel::Machine, m);
  pt = (Machine)`machine X init Y end`; // dummy
  orgs = ();
  pt2 = patchTree(#lang::ecore::tests::Syntax::Machine, pt, patch, orgs, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  });
  newSrc = "<pt2>";
  return newSrc; 
}

test bool testCreateMachine() 
  = createMachineResult() 
  == 
  "machine Doors init closed state closed on open =\> opened end state opened on close =\> closed end end";


/*
 * Insertion (plus creation)
 */

str addStateToEmptyResult() = tester("machine Doors
  									'init closed
  									'end", appendState);

test bool testAddStateToEmpty() 
  = addStateToEmptyResult() == 
  "machine Doors
  'init ⟨initial:Id⟩
  'state NewState  end
  'end";

str addStateToSingletonResult() = tester("machine Doors
  										'init closed
  										'state closed end
  										'end", appendState);

test bool testAddStateToSingleton() 
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

test bool testAddStateToMany() 
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
									        
test bool testPrependStateToSingleton()
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
									        
test bool testPrependStateToMany()
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

test bool testRemoveSingleton()
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

test bool testRemoveFromFront()
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

test bool testRemoveFromEnd()
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

test bool testRemoveFromMid()
  = removeFromMidResult()
  ==
  "machine Doors
  'init closed
  'state closed end
  'state opened end
  'end";

str removeAllResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state removed end
 								   'state opened end
 								   'end", removeStates([0,1,2]));

test bool testRemoveAll()
  = removeAllResult()
  ==
  "machine Doors
  'init ⟨initial:Id⟩
  '
  'end";
  
  
/* 
 * Permutations
 */

str swapTwoStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state opened end
 								   'end", swapState(0, 1));

test bool testSwapTwoStates()
  = swapTwoStatesResult()
  ==
  "machine Doors
  'init closed
  'state opened end
  'state closed end
  'end";


str swapBeginEndStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state A end
 								   'state B end
 								   'state C end
 								   'state opened end
 								   'end", swapState(0, 4));

test bool testSwapBeginEndStates()
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

str reverseAllStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state A end
 								   'state B end
 								   'state C end
 								   'state opened end
 								   'end", reverseStates);

test bool testReverseAllStates()
  = reverseAllStatesResult()
  ==
  "machine Doors
  'init closed
  'state opened end
  'state C end
  'state B end
  'state A end
  'state closed end
  'end";


/*
 * Properties
 */
 

str setMachineNameResult() = tester("machine Doors
             					   'init closed
             					   'end", setMachineName("Foo"));
 
test bool testSetMachineName()
  = setMachineNameResult()
  ==
  "machine Foo
  'init ⟨initial:Id⟩
  'end"; 

str setStateNameWithRefResult() = tester("machine Doors
 										'init closed
 										'state closed end
 										'end", setStateName(0, "CLOSED"));
 										
test bool testSetStateNameWithRef()
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
                                      
test bool testSetInitialToNullGivesNullTree()
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
                                               
test bool testSetInitialToExistingState()
  = setInitialToExistingStateResult()
  ==
  "machine Doors
  'init opened
  'state closed end
  'state opened end
  'end";
  
 /* 
  * Abritrary trafos
  */
  

str arbitraryTrafo1Result() = tester("machine Doors
                                    'init closed
                                    'state closed end
                                    'state opened end
                                    'state locked end
                                    'end", arbitraryTrafo1);

 
 test bool testArbitraryTrafo1()
   = arbitraryTrafo1Result()
   ==
   "machine Doors_
   'init NewState_3
   'state BLA on bar =\> NewState_3 end
   'state closed end
   'state locked end
   'state NewState_3  end
   'end";
   
   
   
   
   
   
   
   
 
  
