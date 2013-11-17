EBNF
---

<pre>
chunk ::= {stat [';']} [laststat [';']]

block ::= chunk

stat ::= varlist '=' explist | 
         functioncall | 
         <b>do</b> block <b>end</b> | 
         <b>while</b> exp <b>do</b> block <b>end</b> | 
         <b>repeat</b> block <b>until</b> exp | 
         <b>if</b> exp <b>then</b> block {<b>elseif</b> exp <b>then</b> block} [<b>else</b> block] <b>end</b> | 
         <b>for</b> type Name '=' exp ',' exp [',' exp] <b>do</b> block <b>end</b> | 
         <b>for</b> typednamelist <b>in</b> explist <b>do</b> block <b>end</b> | 
         <b>class</b> Name [extends Name] classbody |
         <b>function</b> funcname funcbody | 
         scope <b>function</b> Name funcbody | 
         [scope] type namelist ['=' explist] 

laststat ::= <b>return</b> [explist] | <b>break</b>

funcname ::= Name {'.' Name} [':' Name]

varlist ::= var {',' var}

var ::= Name | prefixexp '[' exp ']' | prefixexp '.' Name 

scope ::= <b>local</b> | <b>global</b>

type ::= <b>Number</b> | <b>Bool</b> | <b>String</b> | <b>Table</b> | <b>Function</b> | Name

namelist ::= Name {',' Name}

typednamelist ::= type Name {',' type Name}

explist ::= {exp ','} exp

exp ::= <b>nil</b> | <b>false</b> | <b>true</b> | Number | String | '...' | function | 
        prefixexp | tableconstructor | exp binop exp | unop exp 

prefixexp ::= var | functioncall | '(' exp ')'

functioncall ::= prefixexp args | prefixexp ':' Name args 

args ::= '(' [explist] ')' | tableconstructor | String 

classbody ::= {classstat} <b>end</b>

classstat ::= <b>function</b> Name funcbody | type namelist ['=' explist]

function ::= <b>function</b> funcbody

funcbody ::= '(' [parlist] ')' block <b>end</b>

parlist ::= typednamelist [',' '...'] | '...'

tableconstructor ::= '{' [fieldlist] '}'

fieldlist ::= field {fieldsep field} [fieldsep]

field ::= '[' exp ']' '=' exp | type Name '=' exp | exp

fieldsep ::= ',' | ';'

binop ::= '+' | '-' | '*' | '/' | '^' | '%' | '..' | 
          '<' | '<=' | '>' | '>=' | '==' | '~=' | 
          <b>and</b> | <b>or</b>

unop ::= '-' | <b>not</b> | '#'
</pre>
