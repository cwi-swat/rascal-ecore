module lang::ecore::HUTN2Model

import lang::ecore::Refs;

import ParseTree;
import Type;
import String;
import util::Math;

import IO;

bool isInjection(Tree t) = isInjection(t.prod);

bool isInjection(Production p)
  = p has attributes && \tag("inject"()) in p.attributes;


&T<:node hutn2model(type[&T<:node] meta, Tree hutn, Realm realm = newRealm()) 
  = m
  when &T<:node m := hutn2obj(hutn has top ? hutn.top : hutn, "", meta, realm);


bool hasName(Tree t) = prod(_, [lit(_), _, label("name", _), _, lit("{"), _, _, _, lit("}")], _) := t.prod;

node hutn2obj(Tree t, str path, type[node] meta, Realm realm) {
  if (isInjection(t)) {
    return make(type(adt(p.def.name, []), meta.definitions), p.symbols[0].name, [hutn2obj(t.args[0], path, meta, realm)], ());
  }
  
  //println("Make <t.prod.def.name> at <path> (hasname = <hasName(t)>)");
  
  fieldVals = hasName(t) ? hutnFields(t.args[6], path, meta, realm) : hutnFields(t.args[4], path, meta, realm);
  
  if (hasName(t)) {
    fieldVals["name"] = value2value(t.args[2], path, meta, realm);
  }
   
  Production p = t.prod;
  Symbol s = adt(p.def.name, []);
  
  args = [ fieldVals[fld] | Production c <- meta.definitions[s].alternatives
         , c.def.name == p.def.name, label(str fld, _) <- c.symbols ];
         
  kws = ( fld: fieldVals[fld] | Production c <- meta.definitions[s].alternatives
        , c.def.name == p.def.name, label(str fld, _) <- c.kwTypes, fld != "uid", fld in fieldVals );
        
  tt = type(s, meta.definitions);
  model = realm.new(tt, make(tt, p.def.name, args, kws), id = id(t@\loc[fragment=path]));
  //println("model = <model>");
  return typeCast(#node, model);
}


Tree uninjectField(Tree t) = isInjection(t) ? uninjectField(t.args[0]) : t; 
 

map[str, value] hutnFields(Tree t, str path, type[node] meta, Realm realm) 
  = ( "<t.args[i].args[0]>" : field2value(uninjectField(t.args[i]), path, meta, realm) | int i <- [0,2..size(t.args)] )
  when
    true; //bprintln("FIELDS: <t.prod>");

value field2value(t:appl(prod(_, [lit(str field), _, lit(":"), _, Symbol val], _), list[Tree] args), str path, type[node] meta, Realm realm)
  =  value2value(args[4], field == "name" ? "<args[4]>" : "<path>/@<field>", meta, realm)
  when true; // bprintln("ARGS[4] prod = <args[4].prod>");
  
value field2value(t:appl(prod(_, [lit(str field), _, lit(":"), _, lit("["), _, Symbol val, _, lit("]")], _), list[Tree] args), str path, type[node] meta, Realm realm)
  =  value2value(args[6], "<path>/@<field>", meta, realm)
  when true; //bprintln("ARGS[6] prod = <args[6].prod>");

value value2value(t:appl(prod(lex("Bool"), _, _), _), str path, type[node] meta, Realm realm)
  = "<t>" == "true";

// todo: unescape
value value2value(t:appl(prod(lex("Str"), _, _), _), str path, type[node] meta, Realm realm)
  = "<t>"[1..-1];
  
value value2value(t:appl(prod(lex("Int"), _, _), _), str path, type[node] meta, Realm realm)
  = toInt("<t>");
  
value value2value(t:appl(prod(lex("Real"), _, _), _), str path, type[node] meta, Realm realm)
  = toReal("<t>");
  
value value2value(t:appl(prod(\parameterized-sort("Ref", _), _, _), _), str path, type[node] meta, Realm realm)
  = ref(id(|<scheme>://<rest>|))
  when
    str uri := "<t>"[1..-1],
    [str scheme, str rest] := split("://", uri);
  

default value value2value(t:appl(prod(\parameterized-sort("Ref", _), _, _), _), str path, type[node] meta, Realm realm)
  = null();

value value2value(t:appl(regular(\iter-star-seps(_, _)), list[Tree] args), str path, type[node] meta, Realm realm)
  = [ value2value(args[i], "<path>.<i>", meta, realm) | int i <- [0, 2..size(args)] ];
  
  
default value value2value(Tree t, str path, type[node] meta, Realm realm)
  = hutn2obj(t, path, meta, realm)
  when true; //bprintln("OBJ prod: <t.prod>");
  
  
