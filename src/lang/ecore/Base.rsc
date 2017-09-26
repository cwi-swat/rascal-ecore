module lang::ecore::Base

extend lang::std::Layout;
extend lang::std::Id;

lexical Ref
  = Id
  | Path;
  
lexical Path
  = root: "/"
  | field: Path "/@" Id 
  | index: Path!root "." Int
  ;

lexical Bool
  = "true"
  | "false"
  ;

lexical Real
  = [\-]? [0-9]+ [E e] [+ \-]? [0-9]+ 
  | [\-]? [0-9]+ "." !>> "." [0-9]* 
  | [\-]? [0-9]+ "." [0-9]* [E e] [+ \-]? [0-9]+  
  ;


lexical Int
  = [0] !>> [0-9 A-Z _ a-z] 
  | [\-]? [1-9] [0-9]* !>> [0-9 A-Z _ a-z] 
  ;

lexical Str
  = @category="Constant" "\"" StringCharacter* chars "\"" ;
  
lexical StringCharacter
	= "\\" [\" \\ b f n r t] 
	| UnicodeEscape 
	| ![\" \\ \n\t\r\b\f]
	;
  
lexical UnicodeEscape
	  = utf16: "\\" [u] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] 
    | utf32: "\\" [U] (("0" [0-9 A-F a-f]) | "10") [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] // 24 bits 
    | ascii: "\\" [a] [0-7] [0-9A-Fa-f]
    ;
  