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



str tester(str src, lang::ecore::tests::MetaModel::Machine(lang::ecore::tests::MetaModel::Machine) trafo) {
  lang::ecore::tests::Syntax::Machine pt = parse(#start[Machine], src, |project://rascal-ecore/src/lang/ecore/tests/someTest|).top;
  <m, orgs> = tree2modelWithOrigins(#lang::ecore::tests::MetaModel::Machine, pt);
  m2 = trafo(m);
  patch = diff(#lang::ecore::tests::MetaModel::Machine, m, m2);
  iprintln(patch);
  pt2 = patchTree(#lang::ecore::tests::Syntax::Machine, pt, patch, orgs, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  });
  println("Returning: <pt2>");
  return "<pt2>";
}

/*
 * Insertion (plus creation)
 */

str addStateToEmptyResult() = tester("machine Doors
  									'init closed
  									'end", appendState);

test bool addStateToEmpty() = addStateToEmptyResult() == 
  "machine Doors
  'init closed
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
  'init closed
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
  'init closed
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
 * Properties
 */
 

str setMachineNameResult() = tester("machine Doors
             					   'init closed
             					   'end", setMachineName("Foo"));
 
test bool setMachineName()
  = setMachineNameResult()
  ==
  "machine Foo
  'init closed
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
  'init \<initial:null\>
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