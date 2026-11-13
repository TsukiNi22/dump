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
  "extern" ; extern "C" (linkage specification, not a storage class)
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

; Attribute macros of libutils (_cold, _hot, _nodiscard...): read as a type by treesitter, it does not expand macros
((type_identifier) @attribute
  (#lua-match? @attribute "^_[a-z][a-z_]*$"))

; Code a macro made unreadable ('_hot _nodiscard static inline T f()', '_unused int fd'...): treesitter puts it in an
; ERROR node where every word is a bare identifier (a keyword there lost its color). Only the direct children of an
; ERROR are matched: the identifiers of the readable code are not tested
(ERROR
  (identifier) @attribute
  (#any-of? @attribute "_alignas" "_alloc_size" "_alloc_size_mul" "_assume" "_cold" "_ctor" "_deprecated" "_dtor"
    "_expect" "_fallthrough" "_hidden" "_hot" "_legacy" "_likely" "_likely_c" "_migration" "_noaddress" "_nodiscard"
    "_noinline" "_nonnull" "_noreturn" "_packed" "_read_only" "_thread_local" "_unlikely" "_unlikely_c" "_unused"
    "_write_only"))
(ERROR
  (identifier) @type.builtin
  (#any-of? @type.builtin "void" "bool" "char" "int" "short" "long" "float" "double" "signed" "unsigned" "auto"
    "wchar_t" "char8_t" "char16_t" "char32_t"))
(ERROR
  (identifier) @keyword.modifier
  (#any-of? @keyword.modifier "static" "inline" "extern" "const" "constexpr" "consteval" "constinit" "volatile"
    "virtual" "explicit" "friend" "mutable" "thread_local" "register" "override" "final" "noexcept" "public"
    "private" "protected"))
(ERROR
  (identifier) @keyword.type
  (#any-of? @keyword.type "struct" "union" "enum" "typedef" "class" "namespace" "template" "typename" "concept"))
(ERROR
  (identifier) @keyword.conditional
  (#any-of? @keyword.conditional "if" "else" "switch" "case" "default"))
(ERROR
  (identifier) @keyword.repeat
  (#any-of? @keyword.repeat "for" "while" "do"))
(ERROR
  (identifier) @keyword.return
  (#eq? @keyword.return "return"))
(ERROR
  (identifier) @keyword.exception
  (#any-of? @keyword.exception "try" "catch" "throw"))
(ERROR
  (identifier) @keyword.operator
  (#any-of? @keyword.operator "new" "delete" "sizeof" "static_cast" "dynamic_cast" "const_cast" "reinterpret_cast"))
(ERROR
  (identifier) @keyword
  (#any-of? @keyword "using" "decltype" "operator" "static_assert" "requires" "break" "continue" "goto"))
(ERROR
  (identifier) @constant.builtin
  (#any-of? @constant.builtin "nullptr" "NULL"))
(ERROR
  (identifier) @boolean
  (#any-of? @boolean "true" "false"))
(ERROR
  (identifier) @module
  (#any-of? @module "std" "utils"))
(ERROR
  (identifier) @variable.builtin
  (#eq? @variable.builtin "this"))
; Types (PascalCase or a template parameter T / U), not the UPPER_CASE constants
(ERROR
  (identifier) @type
  (#lua-match? @type "^[A-Z]%w*[a-z]%w*$"))
(ERROR
  (identifier) @type
  (#lua-match? @type "^[A-Z]$"))
((ERROR) @type.builtin
  (#any-of? @type.builtin "void" "bool" "char" "int" "short" "long" "float" "double" "signed" "unsigned" "auto"))
((ERROR) @keyword.modifier
  (#any-of? @keyword.modifier "static" "inline" "extern" "const" "constexpr" "virtual" "explicit" "friend"))

; The other places an attribute macro lands: a member ('_hot _nodiscard' alone in a class is read as '<type> <member>;')
; or a namespace ('_nodiscard constexpr utils::Type f()')
(field_declaration
  declarator: (field_identifier) @attribute
  (#any-of? @attribute "_alignas" "_alloc_size" "_assume" "_cold" "_deprecated" "_expect" "_hidden" "_hot" "_legacy"
    "_likely" "_migration" "_noaddress" "_nodiscard" "_noinline" "_nonnull" "_noreturn" "_packed" "_unlikely"
    "_unused"))
((namespace_identifier) @attribute
  (#any-of? @attribute "_cold" "_deprecated" "_hidden" "_hot" "_legacy" "_migration" "_nodiscard" "_noinline"
    "_noreturn" "_unused"))
; A statement after '_likely' / '_unlikely' ('if (x) _unlikely { if (y) break; }') is read as a call: 'if (y)'
(call_expression
  function: (identifier) @keyword.conditional
  (#any-of? @keyword.conditional "if" "switch"))
(call_expression
  function: (identifier) @keyword.repeat
  (#any-of? @keyword.repeat "for" "while"))
(call_expression
  function: (identifier) @keyword.exception
  (#eq? @keyword.exception "catch"))
(template_function
  name: (identifier) @keyword.operator
  (#any-of? @keyword.operator "static_cast" "dynamic_cast" "const_cast" "reinterpret_cast"))
(initializer_list
  (identifier) @keyword.return
  (#eq? @keyword.return "return"))
(initializer_list
  (identifier) @keyword
  (#any-of? @keyword "break" "continue"))

; Names the flat patterns above missed
(enumerator
  name: (identifier) @constant)
(concept_definition
  name: (identifier) @type)
(attribute
  name: (identifier) @attribute)
(preproc_params
  (identifier) @variable.parameter)
(optional_parameter_declaration
  declarator: (identifier) @variable.parameter)
(parameter_declaration
  declarator: (pointer_declarator
    declarator: (identifier) @variable.parameter))
(parameter_declaration
  declarator: (reference_declarator
    (identifier) @variable.parameter))
((preproc_call
  directive: (preproc_directive) @_directive
  argument: (preproc_arg) @keyword.directive)
  (#eq? @_directive "#pragma")
  (#lua-match? @keyword.directive "^%s*once%s*$"))

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
