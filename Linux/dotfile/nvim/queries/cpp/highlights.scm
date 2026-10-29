; Light highlights for C++, written for speed: the stock ones (the C ones plus ~270 lines of nested patterns) take ~0.9 s to
; compile when the first C++ file opens, and that is a frozen editor. Flat patterns compile in a fraction of that.
; Only the information given by the nesting is lost (a::b::c::f()).

(comment) @comment

; Literals
[
  (string_literal)
  (raw_string_literal)
  (system_lib_string)
] @string

(char_literal) @character
(escape_sequence) @string.escape
(number_literal) @number
[
  (true)
  (false)
] @boolean

(null) @constant.builtin
(this) @variable.builtin

; Types
(primitive_type) @type.builtin
(sized_type_specifier) @type.builtin
(auto) @type.builtin
(type_identifier) @type
(namespace_identifier) @module

; Names
(field_identifier) @variable.member
(statement_identifier) @label
(parameter_declaration
  declarator: (identifier) @variable.parameter)

((identifier) @constant
  (#lua-match? @constant "^[A-Z][A-Z0-9_]+$"))

((namespace_identifier) @type
  (#lua-match? @type "^[A-Z]"))

; Functions
(function_declarator
  declarator: (identifier) @function)
(function_declarator
  declarator: (qualified_identifier
    name: (identifier) @function))
(function_declarator
  declarator: (field_identifier) @function.method)
(call_expression
  function: (identifier) @function.call)
(call_expression
  function: (qualified_identifier
    name: (identifier) @function.call))
(call_expression
  function: (field_expression
    field: (field_identifier) @function.method.call))
(call_expression
  function: (template_function
    name: (identifier) @function.call))
(destructor_name
  (identifier) @function.method)
(operator_name) @function

; Preprocessor
[
  "#include"
  "#define"
  "#if"
  "#ifdef"
  "#ifndef"
  "#else"
  "#elif"
  "#elifdef"
  "#elifndef"
  "#endif"
  (preproc_directive)
] @keyword.directive
(preproc_def
  name: (identifier) @constant.macro)
(preproc_function_def
  name: (identifier) @constant.macro)

; Keywords
[
  "if"
  "else"
  "switch"
  "case"
  "default"
] @keyword.conditional

[
  "for"
  "while"
  "do"
] @keyword.repeat

[
  "break"
  "continue"
  "goto"
] @keyword

"return" @keyword.return

[
  "struct"
  "union"
  "enum"
  "typedef"
  "class"
  "namespace"
  "template"
  "typename"
  "concept"
] @keyword.type

[
  (type_qualifier)
  (storage_class_specifier)
  "constexpr"
  "virtual"
  "override"
  "final"
  "public"
  "private"
  "protected"
  "explicit"
  "friend"
  "mutable"
] @keyword.modifier

[
  "try"
  "catch"
  "throw"
  "noexcept"
] @keyword.exception

[
  "new"
  "delete"
  "sizeof"
  "and"
  "or"
  "not"
  "xor"
  "bitand"
  "bitor"
  "compl"
] @keyword.operator

[
  "using"
  "decltype"
  "requires"
  "operator"
  "static_assert"
  "co_await"
  "co_yield"
  "co_return"
] @keyword

; Operators and punctuation
[
  "="
  "+"
  "-"
  "*"
  "/"
  "%"
  "=="
  "!="
  "<"
  ">"
  "<="
  ">="
  "&&"
  "||"
  "!"
  "&"
  "|"
  "^"
  "~"
  "<<"
  ">>"
  "+="
  "-="
  "*="
  "/="
  "%="
  "&="
  "|="
  "^="
  "<<="
  ">>="
  "++"
  "--"
  "->"
  "."
  "?"
  "<=>"
] @operator

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ";"
  ","
  ":"
  "::"
] @punctuation.delimiter
