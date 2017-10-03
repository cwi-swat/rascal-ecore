module lang::ecore::tests::TestHUTN


import lang::ecore::Grammar2Ecore;
import lang::ecore::Ecore2HUTN;
import lang::ecore::Model2HUTN;
import lang::ecore::HUTN2Model;
import lang::ecore::Tree2Model;
import lang::ecore::Ecore;
import lang::ecore::Diff;

import lang::ecore::tests::StmHUTN;
import lang::ecore::tests::Syntax;
import lang::ecore::tests::MetaModel;

import IO;
import ParseTree;

void setup() {
  writeMyFsmHUTNGrammar();
}

void testHUTNBackAndForth() {
  stms = [ l | loc l <- |project://rascal-ecore/src/lang/ecore/tests/|.ls
             , l.extension in {"old", "new"}];
  int fails = 0;
  int errs = 0;
  for (loc stm <- stms) {
    if (!testToAndFromHUTN(stm)) {
       fails += 1;
    }
  } 
  println("<fails> failed; <errs> exceptions; <size(stms) - fails - errs> success");
}


bool testToAndFromHUTN(loc stm) {
  pt = parse(#lang::ecore::tests::Syntax::Machine, stm);
  lang::ecore::tests::MetaModel::Machine m = tree2model(#lang::ecore::tests::MetaModel::Machine, pt);
  str src = model2hutn(#lang::ecore::tests::MetaModel::Machine, m);
  //println(src);
  hutnLoc = stm[extension="<stm.extension>_hutn"];
  writeFile(hutnLoc, src);
  hutn = parseMyfsm(src, hutnLoc);
  m2 = hutn2model(#lang::ecore::tests::MetaModel::Machine, hutn);
  iprintln(diff(#lang::ecore::tests::MetaModel::Machine, m, m2));
  return true;
}



