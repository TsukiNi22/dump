-- The very common things of each language ([std] in the completion): main, control structures, usual includes and
-- usual calls, with the alternatives of the language in the documentation. Snippets: Tab jumps between the fields.
local M = {}

local entries = {} -- { languages, context, label, snippet, doc, kind, group }

-- language: 'c', 'cpp', 'python', 'lua', 'sh' (a list = several), context: 'top' | 'body' | 'any'
-- snippet: a string, or { c = ..., cpp = ... } when the text depends on the language
local function add(languages, context, label, snippet, doc, kind, group, extra)
    table.insert(entries, vim.tbl_extend('force', {
        languages = type(languages) == 'table' and languages or { languages },
        context = context, label = label, snippet = snippet, doc = doc or '', kind = kind or 'Snippet', group = group,
    }, extra or {}))
end

local function alternatives(...) -- Markdown list of alternatives
    local lines = { '', '**Alternatives**' }
    for _, line in ipairs({ ... }) do table.insert(lines, '- ' .. line) end
    return table.concat(lines, '\n')
end

local C, CPP, CBOTH = 'c', 'cpp', { 'c', 'cpp' }

--------------------------------------------------------------------------------
-- C / C++ : main
--------------------------------------------------------------------------------
add(CBOTH, 'body', 'main', 'main', 'Entry point of the program (the name only).', 'Function', 'main')
add(CBOTH, 'top', 'main (argc, argv)', 'int main(int argc, char **argv)\n{\n\t$0\n\treturn 0;\n}',
    'Entry point with the command line.' .. alternatives('`main (no arguments)` when the command line is not used',
        'C++: `std::span(argv, argc)` / `std::vector<std::string>(argv, argv + argc)` to read the arguments'),
    'Snippet', 'main')
add(CBOTH, 'top', 'main (no arguments)', { c = 'int main(void)\n{\n\t$0\n\treturn 0;\n}', cpp = 'int main()\n{\n\t$0\n\treturn 0;\n}' },
    'Entry point without arguments.', 'Snippet', 'main')

--------------------------------------------------------------------------------
-- C / C++ : control structures (in a function)
--------------------------------------------------------------------------------
add(CBOTH, 'body', 'for (index)', 'for (${1:size_t} ${2:i} = 0; ${2:i} < ${3:count}; ++${2:i}) {\n\t$0\n}',
    'Loop on an index.' .. alternatives('C++: `for (auto &&item : container)` when the index is not needed',
        'C++20: `std::views::iota(0, n)`'))
add(CPP, 'body', 'for (range)', 'for (${1:auto &&} ${2:item} : ${3:container}) {\n\t$0\n}',
    'Loop on every element of a container.' .. alternatives('`for (index)` to keep the position', '`std::for_each`'))
add(CBOTH, 'body', 'while', 'while (${1:condition}) {\n\t$0\n}', 'Loop while the condition is true.')
add(CBOTH, 'body', 'do while', 'do {\n\t$0\n} while (${1:condition});', 'Loop that runs at least once.')
add(CBOTH, 'body', 'if', 'if (${1:condition}) {\n\t$0\n}', 'Condition.')
add(CBOTH, 'body', 'if else', 'if (${1:condition}) {\n\t$2\n} else {\n\t$0\n}', 'Condition with an else branch.')
add(CBOTH, 'body', 'switch', 'switch (${1:value}) {\n\tcase ${2:0}:\n\t\t$0\n\t\tbreak;\n\tdefault:\n\t\tbreak;\n}',
    'Choice between constant values.' .. alternatives('`if else` chain when the values are not constant'))
add(CPP, 'body', 'try catch', 'try {\n\t$1\n} catch (const ${2:std::exception} &${3:e}) {\n\t$0\n}',
    'Catches an exception.' .. alternatives('C: return codes / `errno`', 'C++23: `std::expected`'))
add(CBOTH, 'body', 'return 0', 'return 0;', 'Success code of main.')

--------------------------------------------------------------------------------
-- C : usual calls
--------------------------------------------------------------------------------
add(CBOTH, 'body', 'printf', 'printf("${1:%s}\\n", ${2});',
    'Prints a formatted text on the standard output.' .. alternatives('`fprintf(stderr, ...)` for the errors',
        'C++: `std::cout << ...`', 'C++20: `std::format` (with `std::cout`)', 'C++23: `std::println`'))
add(CBOTH, 'body', 'fprintf (stderr)', 'fprintf(stderr, "${1:%s}\\n", ${2});', 'Prints on the error output.')
add(C, 'body', 'malloc', '${1:int} *${2:ptr} = malloc(${3:count} * sizeof(*${2:ptr}));\nif (${2:ptr} == NULL)\n\treturn 1;\n$0',
    'Allocates memory (to free with `free`).' .. alternatives('`calloc`: zeroed memory', '`realloc`: resize',
        'C++: `std::vector`, `std::make_unique`'))
add(C, 'body', 'fopen', 'FILE *${1:file} = fopen(${2:"path"}, ${3:"r"});\nif (${1:file} == NULL)\n\treturn 1;\n$0\nfclose(${1:file});',
    'Opens a file.' .. alternatives('C++: `std::ifstream` / `std::ofstream`', 'POSIX: `open` / `read` / `write`'))

--------------------------------------------------------------------------------
-- C++ : usual std::
--------------------------------------------------------------------------------
add(CPP, 'body', 'cout', "std::cout << ${1:value} << '\\n';",
    'Prints on the standard output (`#include <iostream>`).' .. alternatives('`std::cerr` for the errors',
        'C++20: `std::format`', 'C++23: `std::println`', '`printf`'))
add(CPP, 'body', 'cerr', "std::cerr << ${1:message} << '\\n';", 'Prints on the error output.')
add(CPP, 'body', 'cin', 'std::cin >> ${1:variable};', 'Reads from the standard input.' .. alternatives('`std::getline(std::cin, line)` for a whole line'))
add(CPP, 'body', 'vector', 'std::vector<${1:int}> ${2:values};',
    'Dynamic array (`#include <vector>`).' .. alternatives('`std::array` for a fixed size', '`std::deque` to add at both ends',
        '`std::span` to look at a part without copying'))
add(CPP, 'body', 'string', 'std::string ${1:text}${2: = ${3:""}};',
    'Text (`#include <string>`).' .. alternatives('`std::string_view` to read without copying', '`std::format` to build a text'))
add(CPP, 'body', 'map', 'std::map<${1:std::string}, ${2:int}> ${3:table};',
    'Sorted dictionary (`#include <map>`).' .. alternatives('`std::unordered_map`: faster, not sorted', '`std::set` when only the keys matter'))
add(CPP, 'body', 'unordered_map', 'std::unordered_map<${1:std::string}, ${2:int}> ${3:table};',
    'Hash dictionary (`#include <unordered_map>`).' .. alternatives('`std::map`: sorted'))
add(CPP, 'body', 'unique_ptr', 'auto ${1:ptr} = std::make_unique<${2:Type}>($0);',
    'Owner of one object (`#include <memory>`).' .. alternatives('`std::shared_ptr` when the owner is shared', 'a plain value when no heap is needed'))
add(CPP, 'body', 'shared_ptr', 'auto ${1:ptr} = std::make_shared<${2:Type}>($0);', 'Shared owner of an object (`#include <memory>`).')
add(CPP, 'body', 'lambda', '[${1:&}](${2}) {\n\t$0\n}', 'Anonymous function.')
add(CPP, 'body', 'sort', 'std::sort(${1:values}.begin(), ${1:values}.end()${2});',
    'Sorts a range (`#include <algorithm>`).' .. alternatives('C++20: `std::ranges::sort(values)`', '`std::stable_sort`: keeps the order of equal elements'))
add(CPP, 'body', 'find_if', 'auto ${1:it} = std::find_if(${2:values}.begin(), ${2:values}.end(), [&](const auto &${3:item}) {\n\treturn $0;\n});',
    'First element that matches (`#include <algorithm>`).' .. alternatives('C++20: `std::ranges::find_if`'))
add(CPP, 'body', 'move', 'std::move(${1:value})', 'Allows to move a value instead of copying it (`#include <utility>`).')
add(CPP, 'body', 'optional', 'std::optional<${1:Type}> ${2:value};', 'A value that may be absent (`#include <optional>`).' .. alternatives('`std::variant` for several types', 'a pointer that can be null'))
add(CPP, 'body', 'format', 'std::format("${1:{}}", ${2})', 'Builds a text (C++20, `#include <format>`).' .. alternatives('`std::ostringstream`', '`snprintf`'))

--------------------------------------------------------------------------------
-- C / C++ : top level
--------------------------------------------------------------------------------
add(CPP, 'top', 'class', 'class ${1:Name} {\npublic:\n\t${1:Name}();\n\t~${1:Name}();\n\nprivate:\n\t$0\n};', 'Class with a constructor and a destructor.' .. alternatives('`struct`: everything public'))
add(CBOTH, 'top', 'struct', 'struct ${1:Name} {\n\t$0\n};', 'Group of fields.')
add(C, 'top', 'typedef struct', 'typedef struct ${1:name} {\n\t$0\n} ${1:name}_t;', 'Structure with a type name.')
add(CPP, 'top', 'namespace', 'namespace ${1:name} {\n\n$0\n\n} // namespace ${1:name}', 'Namespace.')
add(CPP, 'top', 'enum class', 'enum class ${1:Name} {\n\t$0\n};', 'Enumeration with its own scope.' .. alternatives('`enum`: names in the enclosing scope'))
add(CPP, 'top', 'template', 'template <typename ${1:T}>\n${2:void} ${3:name}(${4})\n{\n\t$0\n}', 'Template function.' .. alternatives('C++20: `concept` + `requires` to restrict `T`'))
add(CPP, 'top', 'using namespace std', 'using namespace std;', 'Imports std (fine in a small file, avoid it in a header).')

--------------------------------------------------------------------------------
-- Python
--------------------------------------------------------------------------------
add('python', 'top', 'main', 'def main() -> None:\n\t$0\n\n\nif __name__ == "__main__":\n\tmain()', 'Entry point of a script.', 'Snippet', 'main')
add('python', 'body', 'main', 'main', 'Entry point of the script (the name only).', 'Function', 'main')
add('python', 'top', 'if __name__', 'if __name__ == "__main__":\n\t${1:main()}', 'Runs only when the file is launched directly.')
add('python', 'top', 'def', 'def ${1:name}(${2}) -> ${3:None}:\n\t$0', 'Function.')
add('python', 'top', 'class', 'class ${1:Name}:\n\tdef __init__(self${2}) -> None:\n\t\t$0', 'Class.' .. alternatives('`@dataclass` for a class that only holds data'))
add('python', 'top', 'dataclass', 'from dataclasses import dataclass\n\n\n@dataclass\nclass ${1:Name}:\n\t${2:field}: ${3:int}', 'Class that only holds data.')
add('python', 'body', 'for', 'for ${1:item} in ${2:items}:\n\t$0', 'Loop.' .. alternatives('`for index, item in enumerate(items)`', 'a comprehension: `[x for x in items]`'))
add('python', 'body', 'for enumerate', 'for ${1:index}, ${2:item} in enumerate(${3:items}):\n\t$0', 'Loop with the position.')
add('python', 'body', 'while', 'while ${1:condition}:\n\t$0', 'Loop while the condition is true.')
add('python', 'body', 'if', 'if ${1:condition}:\n\t$0', 'Condition.')
add('python', 'body', 'try except', 'try:\n\t$1\nexcept ${2:Exception} as ${3:error}:\n\t$0', 'Catches an exception.')
add('python', 'body', 'with open', 'with open(${1:path}, ${2:"r"}) as ${3:file}:\n\t$0', 'Opens a file and closes it at the end.' .. alternatives('`pathlib.Path(path).read_text()`'))
add('python', 'body', 'print', 'print(f"${1:{value}}")', 'Prints a text (f-string).' .. alternatives('`logging.info(...)` for a real program'))
for _, module in ipairs({ 'os', 'sys', 'json', 're', 'argparse', 'subprocess', 'itertools', 'functools', 'collections', 'typing' }) do
    add('python', 'top', 'import ' .. module, 'import ' .. module, 'Standard module `' .. module .. '`.')
end
add('python', 'top', 'from pathlib import Path', 'from pathlib import Path', 'Paths as objects.' .. alternatives('`os.path`: functions on strings'))

--------------------------------------------------------------------------------
-- Lua
--------------------------------------------------------------------------------
add('lua', 'body', 'for (index)', 'for ${1:i} = ${2:1}, ${3:count} do\n\t$0\nend', 'Loop on numbers.')
add('lua', 'body', 'for pairs', 'for ${1:key}, ${2:value} in pairs(${3:table}) do\n\t$0\nend', 'Loop on every key of a table.' .. alternatives('`ipairs`: only the list part, in order'))
add('lua', 'body', 'for ipairs', 'for ${1:index}, ${2:value} in ipairs(${3:list}) do\n\t$0\nend', 'Loop on a list, in order.')
add('lua', 'body', 'if', 'if ${1:condition} then\n\t$0\nend', 'Condition.')
add('lua', 'body', 'pcall', 'local ${1:ok}, ${2:result} = pcall(${3:function})', 'Calls a function without stopping on an error.')
add('lua', 'any', 'function', 'function ${1:name}(${2})\n\t$0\nend', 'Function.')
add('lua', 'any', 'local function', 'local function ${1:name}(${2})\n\t$0\nend', 'Local function.')
add('lua', 'top', 'module', 'local M = {}\n\n$0\n\nreturn M', 'Skeleton of a module.')
add('lua', 'any', 'require', "local ${1:module} = require('${2:name}')", 'Loads a module.')

--------------------------------------------------------------------------------
-- Shell
--------------------------------------------------------------------------------
add('sh', 'top', 'shebang', '#!/bin/sh\nset -eu\n$0', 'Header of a script that stops on an error.' .. alternatives('`#!/usr/bin/env bash` + `set -euo pipefail` when bash is needed'))
add('sh', 'any', 'if', 'if [ ${1:condition} ]; then\n\t$0\nfi', 'Condition.' .. alternatives('`[[ ... ]]` in bash'))
add('sh', 'any', 'for', 'for ${1:item} in ${2:list}; do\n\t$0\ndone', 'Loop.')
add('sh', 'any', 'while read', 'while IFS= read -r ${1:line}; do\n\t$0\ndone < ${2:file}', 'Reads a file line by line.')
add('sh', 'any', 'case', 'case ${1:value} in\n\t${2:pattern})\n\t\t$0\n\t\t;;\n\t*)\n\t\t;;\nesac', 'Choice between patterns.')
add('sh', 'top', 'function', '${1:name}() {\n\t$0\n}', 'Function.')

--------------------------------------------------------------------------------
-- #include lines
--------------------------------------------------------------------------------
local c_headers = {
    { 'stdio.h', 'printf, scanf, fopen, FILE...', 'C++: `<cstdio>`, `<iostream>`' },
    { 'stdlib.h', 'malloc, free, exit, atoi, qsort...', 'C++: `<cstdlib>`, `<memory>`, `<algorithm>`' },
    { 'string.h', 'strlen, strcpy, memcpy, memset...', 'C++: `<cstring>`, `<string>`' },
    { 'stdint.h', 'int32_t, uint8_t, size_t...', 'C++: `<cstdint>`' },
    { 'stdbool.h', 'bool, true, false', 'C++: built in' },
    { 'stddef.h', 'size_t, NULL, offsetof', 'C++: `<cstddef>`' },
    { 'math.h', 'sqrt, pow, sin, floor...', 'C++: `<cmath>`' },
    { 'ctype.h', 'isalpha, isdigit, toupper...', 'C++: `<cctype>`' },
    { 'errno.h', 'errno and its codes', 'C++: `<cerrno>`, `<system_error>`' },
    { 'time.h', 'time, clock, strftime...', 'C++: `<chrono>`' },
    { 'unistd.h', 'read, write, fork, sleep (POSIX)', 'C++: `<thread>` for sleep' },
    { 'fcntl.h', 'open and its flags (POSIX)', 'C++: `<fstream>`' },
    { 'assert.h', 'assert', 'C++: `<cassert>`, `static_assert`' },
}
local cpp_headers = {
    { 'iostream', 'std::cout, std::cin, std::cerr', 'C: `<stdio.h>`' },
    { 'string', 'std::string', 'C: `<string.h>`' },
    { 'vector', 'std::vector', '`<array>` for a fixed size' },
    { 'array', 'std::array', '`<vector>` for a dynamic size' },
    { 'map', 'std::map', '`<unordered_map>`: faster, not sorted' },
    { 'unordered_map', 'std::unordered_map', '`<map>`: sorted' },
    { 'set', 'std::set', '`<unordered_set>`' },
    { 'memory', 'std::unique_ptr, std::shared_ptr, std::make_unique', 'C: `<stdlib.h>` (malloc)' },
    { 'algorithm', 'std::sort, std::find, std::transform...', '`<ranges>` in C++20' },
    { 'functional', 'std::function, std::bind', 'lambdas' },
    { 'utility', 'std::move, std::pair, std::swap', '' },
    { 'optional', 'std::optional', '`<variant>`' },
    { 'variant', 'std::variant, std::visit', '`<optional>`' },
    { 'string_view', 'std::string_view', '`<string>`' },
    { 'span', 'std::span (C++20)', '`<vector>`' },
    { 'ranges', 'std::ranges, std::views (C++20)', '`<algorithm>`' },
    { 'format', 'std::format (C++20)', '`<iostream>`, `<sstream>`' },
    { 'fstream', 'std::ifstream, std::ofstream', 'C: `<stdio.h>` (fopen)' },
    { 'sstream', 'std::stringstream', '`<format>`' },
    { 'filesystem', 'std::filesystem::path (C++17)', 'C: `<dirent.h>`' },
    { 'chrono', 'std::chrono::steady_clock, durations', 'C: `<time.h>`' },
    { 'thread', 'std::thread, std::this_thread', 'C: `<pthread.h>`' },
    { 'mutex', 'std::mutex, std::lock_guard', '`<atomic>`' },
    { 'atomic', 'std::atomic', '`<mutex>`' },
    { 'cstdint', 'std::int32_t, std::uint8_t...', 'C: `<stdint.h>`' },
    { 'cmath', 'std::sqrt, std::pow...', 'C: `<math.h>`' },
    { 'exception', 'std::exception', '`<stdexcept>`' },
    { 'stdexcept', 'std::runtime_error, std::invalid_argument', '' },
}
local function includes(headers, language)
    for _, header in ipairs(headers) do
        add(language, 'include', 'include <' .. header[1] .. '>', 'include <' .. header[1] .. '>',
            header[2] .. (header[3] ~= '' and alternatives(header[3]) or ''), 'File')
    end
end
includes(c_headers, C)
includes(cpp_headers, CPP)

--------------------------------------------------------------------------------
-- Rust
--------------------------------------------------------------------------------
add('rust', 'top', 'fn main', 'fn main() {\n\t$0\n}', 'Entry point of the program.', 'Snippet', 'main')
add('rust', 'body', 'main', 'main', 'Entry point of the program (the name only).', 'Function', 'main')
add('rust', 'top', 'fn main (Result)', 'fn main() -> Result<(), Box<dyn std::error::Error>> {\n\t$0\n\tOk(())\n}', 'Entry point that can use `?`.' .. alternatives('`anyhow::Result<()>` with the anyhow crate'), 'Snippet', 'main')
add('rust', 'top', 'fn', 'fn ${1:name}(${2}) -> ${3:()} {\n\t$0\n}', 'Function.')
add('rust', 'top', 'pub fn', 'pub fn ${1:name}(${2}) -> ${3:()} {\n\t$0\n}', 'Public function.')
add('rust', 'top', 'struct', 'struct ${1:Name} {\n\t${2:field}: ${3:Type},\n}', 'Structure.' .. alternatives('tuple struct: `struct Name(Type);`'))
add('rust', 'top', 'impl', 'impl ${1:Type} {\n\t$0\n}', 'Methods of a type.' .. alternatives('`impl Trait for Type`'))
add('rust', 'top', 'enum', 'enum ${1:Name} {\n\t${2:Variant},\n}', 'Enumeration (each variant can hold data).')
add('rust', 'top', 'trait', 'trait ${1:Name} {\n\tfn ${2:method}(&self);\n}', 'Shared behaviour.')
add('rust', 'top', 'derive', '#[derive(Debug, Clone${1})]', 'Generates the usual traits.' .. alternatives('`PartialEq`, `Eq`, `Hash`, `Default`, `Copy`'))
add('rust', 'top', 'mod tests', '#[cfg(test)]\nmod tests {\n\tuse super::*;\n\n\t#[test]\n\tfn ${1:it_works}() {\n\t\t$0\n\t}\n}', 'Unit tests of the file.')
add('rust', 'top', 'use std', 'use std::${1:collections::HashMap};', 'Imports from the standard library.')
add('rust', 'body', 'let', 'let ${1:name} = ${2:value};', 'Immutable binding.' .. alternatives('`let mut` to change it later'))
add('rust', 'body', 'let mut', 'let mut ${1:name} = ${2:value};', 'Mutable binding.')
add('rust', 'body', 'for', 'for ${1:item} in ${2:iterator} {\n\t$0\n}', 'Loop.' .. alternatives('`.iter().for_each(...)`', '`for (i, item) in x.iter().enumerate()`'))
add('rust', 'body', 'while', 'while ${1:condition} {\n\t$0\n}', 'Loop while the condition is true.' .. alternatives('`loop { ... break; }`'))
add('rust', 'body', 'loop', 'loop {\n\t$0\n}', 'Infinite loop (leave with `break`).')
add('rust', 'body', 'if', 'if ${1:condition} {\n\t$0\n}', 'Condition.')
add('rust', 'body', 'if let', 'if let ${1:Some(value)} = ${2:option} {\n\t$0\n}', 'Condition on one pattern.' .. alternatives('`match` for several patterns', '`let Some(x) = y else { return }`'))
add('rust', 'body', 'match', 'match ${1:value} {\n\t${2:pattern} => $0,\n\t_ => {}\n}', 'Choice between patterns (must be exhaustive).')
add('rust', 'body', 'println!', 'println!("${1:{}}", ${2});', 'Prints a line.' .. alternatives('`eprintln!` for the errors', '`format!` to build a String', '`dbg!` to debug a value'))
add('rust', 'body', 'vec!', 'vec![${1}]', 'Vector.' .. alternatives('`[T; N]` array when the size is fixed', '`Vec::with_capacity(n)`'))
add('rust', 'body', 'Result', 'let ${1:value} = ${2:call}()?;', 'Propagates the error to the caller.' .. alternatives('`.unwrap()` / `.expect("msg")` when it cannot fail', '`match` to handle it here'))

--------------------------------------------------------------------------------
-- JavaScript / TypeScript
--------------------------------------------------------------------------------
local JS = { 'javascript', 'typescript' }
add(JS, 'any', 'function', 'function ${1:name}(${2}) {\n\t$0\n}', 'Function.' .. alternatives('arrow function: `const name = (args) => { ... }`'))
add(JS, 'any', 'arrow function', 'const ${1:name} = (${2}) => {\n\t$0\n};', 'Arrow function (keeps `this` of the outside).')
add(JS, 'any', 'async function', 'async function ${1:name}(${2}) {\n\t$0\n}', 'Function that can `await`.')
add(JS, 'any', 'class', 'class ${1:Name} {\n\tconstructor(${2}) {\n\t\t$0\n\t}\n}', 'Class.')
add(JS, 'top', 'import', "import { ${1} } from '${2:module}';", 'Imports from a module.' .. alternatives("`import x from '...'` (default export)", "`require('...')` (CommonJS)"))
add(JS, 'top', 'export', 'export ${1:const} ${2:name} = ${3:value};', 'Exports to the other modules.')
add(JS, 'body', 'for (index)', 'for (let ${1:i} = 0; ${1:i} < ${2:array}.length; ${1:i}++) {\n\t$0\n}', 'Loop on an index.' .. alternatives('`for (const item of array)`', '`array.forEach(...)`'))
add(JS, 'body', 'for of', 'for (const ${1:item} of ${2:iterable}) {\n\t$0\n}', 'Loop on the values.' .. alternatives('`for in`: the keys of an object'))
add(JS, 'body', 'if', 'if (${1:condition}) {\n\t$0\n}', 'Condition.')
add(JS, 'body', 'if else', 'if (${1:condition}) {\n\t$2\n} else {\n\t$0\n}', 'Condition with an else branch.')
add(JS, 'body', 'try catch', 'try {\n\t$1\n} catch (${2:error}) {\n\t$0\n}', 'Catches an error.')
add(JS, 'body', 'console.log', 'console.log(${1});', 'Prints in the console.' .. alternatives('`console.error`, `console.table`'))
add(JS, 'body', 'fetch', 'const ${1:response} = await fetch(${2:url});\nconst ${3:data} = await ${1:response}.json();', 'HTTP request.' .. alternatives('`axios`'))
add(JS, 'body', 'map', '${1:array}.map((${2:item}) => ${3:item})', 'New array from each element.' .. alternatives('`forEach`: no result', '`flatMap`'))
add(JS, 'body', 'filter', '${1:array}.filter((${2:item}) => ${3:condition})', 'Keeps the elements that match.')
add(JS, 'body', 'reduce', '${1:array}.reduce((${2:total}, ${3:item}) => ${4:total}, ${5:0})', 'Folds an array into one value.')
add(JS, 'body', 'setTimeout', 'setTimeout(() => {\n\t$0\n}, ${1:1000});', 'Runs a function later.')
add('typescript', 'top', 'interface', 'interface ${1:Name} {\n\t${2:field}: ${3:string};\n}', 'Shape of an object.' .. alternatives('`type Name = { ... }`: can also name unions'))
add('typescript', 'top', 'type', 'type ${1:Name} = ${2:string | number};', 'Type alias.')
add('typescript', 'top', 'enum', 'enum ${1:Name} {\n\t${2:Value},\n}', 'Enumeration.' .. alternatives('a union of strings: `type X = "a" | "b"`'))

--------------------------------------------------------------------------------
-- HTML / CSS
--------------------------------------------------------------------------------
add('html', 'top', 'html5', '<!doctype html>\n<html lang="${1:en}">\n<head>\n\t<meta charset="utf-8">\n\t<meta name="viewport" content="width=device-width, initial-scale=1">\n\t<title>${2:Title}</title>\n</head>\n<body>\n\t$0\n</body>\n</html>', 'Skeleton of a page.')
for _, tag in ipairs({ 'div', 'section', 'article', 'header', 'footer', 'main', 'nav', 'aside', 'span', 'p', 'ul', 'ol', 'li', 'button', 'h1', 'h2', 'h3' }) do
    add('html', 'any', tag, '<' .. tag .. '>$0</' .. tag .. '>', '`<' .. tag .. '>` element.')
end
add('html', 'any', 'a', '<a href="${1:#}">${2:text}</a>', 'Link.')
add('html', 'any', 'img', '<img src="${1}" alt="${2}">', 'Image (always give an `alt`).')
add('html', 'any', 'input', '<input type="${1:text}" name="${2}" id="${3}">', 'Form field.' .. alternatives('`<textarea>`, `<select>`'))
add('html', 'any', 'form', '<form action="${1}" method="${2:post}">\n\t$0\n</form>', 'Form.')
add('html', 'any', 'link css', '<link rel="stylesheet" href="${1:style.css}">', 'Style sheet.')
add('html', 'any', 'script', '<script src="${1:main.js}"></script>', 'Script.' .. alternatives('`type="module"` for the ES modules', '`defer` to run after the page is read'))
add({ 'css', 'scss' }, 'any', 'flex center', 'display: flex;\njustify-content: center;\nalign-items: center;', 'Centers the content.' .. alternatives('`display: grid; place-items: center;`'))
add({ 'css', 'scss' }, 'any', 'grid', 'display: grid;\ngrid-template-columns: ${1:repeat(3, 1fr)};\ngap: ${2:1rem};', 'Grid layout.' .. alternatives('`flex` for one direction'))
add({ 'css', 'scss' }, 'any', 'media query', '@media (max-width: ${1:600px}) {\n\t$0\n}', 'Rules for some screens.')
add({ 'css', 'scss' }, 'any', ':root variables', ':root {\n\t--${1:color}: ${2:#333};\n}', 'Variables of the page, used with `var(--name)`.')
add({ 'css', 'scss' }, 'any', 'transition', 'transition: ${1:all} ${2:0.2s} ${3:ease};', 'Smooth change of a property.')
add({ 'css', 'scss' }, 'any', 'reset', '*,\n*::before,\n*::after {\n\tbox-sizing: border-box;\n\tmargin: 0;\n}', 'Usual reset.')

--------------------------------------------------------------------------------
-- Zig
--------------------------------------------------------------------------------
add('zig', 'top', 'main', 'const std = @import("std");\n\npub fn main() !void {\n\t$0\n}', 'Entry point.', 'Snippet', 'main')
add('zig', 'body', 'main', 'main', 'Entry point (the name only).', 'Function', 'main')
add('zig', 'top', 'fn', 'fn ${1:name}(${2}) ${3:void} {\n\t$0\n}', 'Function.')
add('zig', 'top', 'struct', 'const ${1:Name} = struct {\n\t${2:field}: ${3:u32},\n};', 'Structure.')
add('zig', 'body', 'print', 'std.debug.print("${1:{}}\\n", .{${2}});', 'Prints on the error output.' .. alternatives('`std.io.getStdOut().writer()` for the standard output'))
add('zig', 'body', 'for', 'for (${1:items}) |${2:item}| {\n\t$0\n}', 'Loop.' .. alternatives('`for (items, 0..) |item, index|`'))
add('zig', 'body', 'while', 'while (${1:condition}) {\n\t$0\n}', 'Loop while the condition is true.')
add('zig', 'body', 'if', 'if (${1:condition}) {\n\t$0\n}', 'Condition.')
add('zig', 'body', 'defer', 'defer ${1:cleanup};', 'Runs at the end of the scope.' .. alternatives('`errdefer`: only when an error is returned'))
add('zig', 'body', 'try', 'try ${1:call}', 'Returns the error to the caller.' .. alternatives('`catch |err|` to handle it here'))

--------------------------------------------------------------------------------
-- Go
--------------------------------------------------------------------------------
add('go', 'top', 'main', 'package main\n\nimport "fmt"\n\nfunc main() {\n\t$0\n}', 'Program.', 'Snippet', 'main')
add('go', 'body', 'main', 'main', 'Entry point (the name only).', 'Function', 'main')
add('go', 'top', 'func', 'func ${1:name}(${2}) ${3:error} {\n\t$0\n}', 'Function.')
add('go', 'top', 'struct', 'type ${1:Name} struct {\n\t${2:Field} ${3:string}\n}', 'Structure.')
add('go', 'body', 'for', 'for ${1:i} := 0; ${1:i} < ${2:n}; ${1:i}++ {\n\t$0\n}', 'Loop on an index.' .. alternatives('`for ... range`'))
add('go', 'body', 'for range', 'for ${1:i}, ${2:value} := range ${3:items} {\n\t$0\n}', 'Loop on a slice, a map or a channel.')
add('go', 'body', 'if err', 'if err != nil {\n\treturn ${1:err}\n}', 'Usual error check.')
add('go', 'body', 'fmt.Println', 'fmt.Println(${1})', 'Prints a line.' .. alternatives('`fmt.Printf`', '`log.Println` for a real program'))
add('go', 'body', 'go func', 'go func() {\n\t$0\n}()', 'Runs in a goroutine.')

--------------------------------------------------------------------------------
-- Java / PHP / SQL
--------------------------------------------------------------------------------
add('java', 'top', 'main', 'public class ${1:Main} {\n\tpublic static void main(String[] args) {\n\t\t$0\n\t}\n}', 'Program.', 'Snippet', 'main')
add('java', 'body', 'main', 'main', 'Entry point (the name only).', 'Function', 'main')
add('java', 'body', 'sout', 'System.out.println(${1});', 'Prints a line.' .. alternatives('`System.out.printf`', 'a logger for a real program'))
add('java', 'body', 'for (index)', 'for (int ${1:i} = 0; ${1:i} < ${2:n}; ${1:i}++) {\n\t$0\n}', 'Loop on an index.')
add('java', 'body', 'for each', 'for (${1:Type} ${2:item} : ${3:items}) {\n\t$0\n}', 'Loop on the elements.' .. alternatives('`items.forEach(...)`, streams'))
add('java', 'body', 'try catch', 'try {\n\t$1\n} catch (${2:Exception} ${3:e}) {\n\t$0\n}', 'Catches an exception.')
add('php', 'top', 'php', '<?php\n\n$0', 'Opening of a script.')
add('php', 'any', 'function', 'function ${1:name}(${2}) {\n\t$0\n}', 'Function.')
add('php', 'body', 'foreach', 'foreach (${1:$items} as ${2:$item}) {\n\t$0\n}', 'Loop on an array.')
add('php', 'body', 'echo', 'echo ${1};', 'Prints.')
add('sql', 'any', 'select', 'SELECT ${1:*}\nFROM ${2:table}\nWHERE ${3:condition};', 'Reads rows.')
add('sql', 'any', 'insert', 'INSERT INTO ${1:table} (${2:columns})\nVALUES (${3:values});', 'Adds a row.')
add('sql', 'any', 'update', 'UPDATE ${1:table}\nSET ${2:column} = ${3:value}\nWHERE ${4:condition};', 'Changes rows (never without WHERE).')
add('sql', 'any', 'delete', 'DELETE FROM ${1:table}\nWHERE ${2:condition};', 'Removes rows (never without WHERE).')
add('sql', 'any', 'create table', 'CREATE TABLE ${1:name} (\n\tid INTEGER PRIMARY KEY,\n\t${2:column} ${3:TEXT} NOT NULL\n);', 'New table.')
add('sql', 'any', 'join', '${1:INNER} JOIN ${2:table} ON ${2:table}.${3:id} = ${4:other}.${5:id}', 'Combines two tables.' .. alternatives('`LEFT JOIN`: keeps the rows without match'))

--------------------------------------------------------------------------------
-- Assembly (NASM x86-64 Linux, the AT&T / GAS form in the alternatives)
--------------------------------------------------------------------------------
local ASM = { 'asm', 'nasm' }
add(ASM, 'any', '_start', 'section .text\nglobal _start\n\n_start:\n\t$0\n\tmov rax, 60\t\t; sys_exit\n\txor rdi, rdi\t; status 0\n\tsyscall',
    'Program without libc (Linux x86-64).' .. alternatives('GAS: `.section .text` / `.globl _start`', 'with libc: `global main` + `ret`'), 'Snippet', 'main')
add(ASM, 'any', 'main', 'global main\nsection .text\n\nmain:\n\t$0\n\txor eax, eax\n\tret', 'Entry point with libc (linked with gcc).', 'Snippet', 'main')
add(ASM, 'any', 'section .data', 'section .data\n${1:message} db "${2:Hello}", 10\n${3:length} equ $ - ${1:message}', 'Initialized data.' .. alternatives('`section .bss` for the zeroed data'))
add(ASM, 'any', 'section .bss', 'section .bss\n${1:buffer} resb ${2:256}', 'Zeroed data.')
add(ASM, 'any', 'write', '\tmov rax, 1\t\t; sys_write\n\tmov rdi, 1\t\t; stdout\n\tmov rsi, ${1:message}\n\tmov rdx, ${2:length}\n\tsyscall', 'Prints with a system call.')
add(ASM, 'any', 'exit', '\tmov rax, 60\t\t; sys_exit\n\tmov rdi, ${1:0}\n\tsyscall', 'Leaves the program.')
add(ASM, 'any', 'function', '${1:name}:\n\tpush rbp\n\tmov rbp, rsp\n\t$0\n\tpop rbp\n\tret', 'Function with its stack frame.' .. alternatives('`enter` / `leave`', 'without a frame when no locals are used'))
add(ASM, 'any', 'loop', '\tmov rcx, ${1:count}\n${2:.loop}:\n\t$0\n\tdec rcx\n\tjnz ${2:.loop}', 'Loop with a counter.' .. alternatives('`loop` instruction (slower)'))
add(ASM, 'any', 'cmp jmp', '\tcmp ${1:rax}, ${2:0}\n\tj${3:e} ${4:.label}', 'Compare then jump.' .. alternatives('`test rax, rax` to compare with 0', '`je` `jne` `jg` `jl` `jge` `jle` `ja` `jb`'))

--------------------------------------------------------------------------------
-- Shell (sh / bash / zsh)
--------------------------------------------------------------------------------
add('sh', 'top', 'shebang bash', '#!/usr/bin/env bash\nset -euo pipefail\n$0', 'Header of a bash script that stops on an error.')
add('sh', 'any', '[[ ]]', '[[ ${1:-n "$var"} ]]', 'Test of bash and zsh.' .. alternatives('`[ ]` for POSIX sh'))
add('sh', 'any', 'array', '${1:items}=(${2:one two})\nfor ${3:item} in "${${1:items}[@]}"; do\n\t$0\ndone', 'Array and loop (bash).')
add('sh', 'any', 'trap', "trap '${1:cleanup}' ${2:EXIT}", 'Runs a command when the script ends.')
add('sh', 'any', 'getopts', 'while getopts "${1:h}" ${2:opt}; do\n\tcase "$${2:opt}" in\n\t\t${3:h}) $0 ;;\n\t\t*) exit 1 ;;\n\tesac\ndone', 'Reads the options.')
add('sh', 'any', 'heredoc', 'cat <<EOF\n$0\nEOF', 'Text on several lines.')

--------------------------------------------------------------------------------
-- File header (Xartania frame without the title): date, file name filled in, the author and the description to replace
--------------------------------------------------------------------------------
local description_placeholder = 'Je ne pense pas que...'

local function snippet_text(text) return (text:gsub('[%$}\\]', '\\%0')) end -- Escapes of the snippet syntax

-- The header of the file in the style of its language, like header/xartania.lua without the ASCII title
local function header_of(language, file)
    local date = os.date('%d/%m/%Y')
    local name = snippet_text(file and file.name ~= '' and vim.fn.fnamemodify(file.name, ':t') or 'file')
    local description = '${2:' .. description_placeholder .. '}'
    if language == 'make' then
        return table.concat({
            '#**************************************************************#', '#', '#Edition:', '#**  ' .. date .. ' by ${1:<placeholder>}', '#',
            '#File Name:', '#**  ' .. name, '#', '#File Description:', '#**  ' .. description,
            '#**************************************************************#',
        }, '\n')
    elseif language == 'python' then
        local quotes = string.rep('"', 63)
        return table.concat({
            quotes, '', 'Edition:', '##  ' .. date .. ' by ${1:<placeholder>}', '', 'File Name:', '##  ' .. name, '', 'File Description:',
            '##  ' .. description, quotes,
        }, '\n')
    end
    local cpp = language == 'cpp' -- The C++ header has the @date / @author / @file tags
    return table.concat({
        '/**************************************************************\\', '', 'Edition:',
        '##  ' .. (cpp and '@date ' or '') .. date .. ' by ' .. (cpp and '@author ' or '') .. '${1:<placeholder>}', '', 'File Name:',
        '##  ' .. (cpp and '@file ' or '') .. name, '', 'File Description:', '##  ' .. description,
        '\\**************************************************************/',
    }, '\n')
end

-- Special skeletons ([spe]): shown between < and >, which do not count in the matching ('header' is what is compared)
add({ 'c', 'cpp', 'python', 'make' }, 'top', '<header>', header_of,
    'Header of the file: edition date, file name and description (the author is left to fill in).' ..
    alternatives('`Ctrl+H` writes the complete Xartania header, with the ASCII title'),
    'Snippet', nil, { match = 'header', special = true })

--------------------------------------------------------------------------------
-- Preprocessor directives (C / C++): written without the '#', it is added when the line does not start with it
-- Headers only (the #include lines above are offered in every file)
--------------------------------------------------------------------------------
local directive_entries = {}

local function directive(label, snippet, doc)
    table.insert(directive_entries, { label = label, snippet = snippet, doc = doc })
end

directive('define', 'define ${1:NAME} ${2:value}', 'Constant or macro without arguments.' ..
    alternatives('C++: `constexpr` / `inline constexpr` (typed, scoped)', 'C: `enum` or `static const`'))
directive('define (macro)', 'define ${1:NAME}(${2:args}) ${3:body}', 'Macro with arguments.' ..
    alternatives('C++: an `inline` function or a template', 'wrap the arguments in parentheses: `((x) * (x))`'))
directive('undef', 'undef ${1:NAME}', 'Removes a macro.')
directive('ifdef', 'ifdef ${1:NAME}\n$0\n#endif', 'Code kept when the macro is defined.' .. alternatives('`#if defined(NAME)` to combine tests'))
directive('ifndef', 'ifndef ${1:NAME}\n$0\n#endif', 'Code kept when the macro is not defined.')
directive('if', 'if ${1:condition}\n$0\n#endif', 'Code kept when the condition is true.')
directive('if defined', 'if defined(${1:NAME})\n$0\n#endif', 'Same as `#ifdef`, can be combined with `&&` and `||`.')
directive('elif', 'elif ${1:condition}', 'Else branch with a condition.')
directive('else', 'else', 'Else branch.')
directive('endif', 'endif', 'End of `#if`, `#ifdef` or `#ifndef`.')
directive('error', 'error "${1:message}"', 'Stops the compilation with a message.' .. alternatives('C++: `static_assert(condition, "message")`'))
directive('warning', 'warning ${1:message}', 'Warning of the compiler (the build goes on).' ..
    alternatives('`#pragma message("text")`', '`[[deprecated("text")]]` on a function'))
directive('message', 'pragma message("${1:text}")', 'Message written by the compiler.' .. alternatives('`#warning text` (GCC / Clang)'))
directive('pragma once', 'pragma once', 'Include guard of a header, short form.' .. alternatives('`guard`: `#ifndef` / `#define` / `#endif`, portable'))
directive('pragma pack', 'pragma pack(push, ${1:1})\n$0\n#pragma pack(pop)', 'Alignment of the fields of a structure.' .. alternatives('`alignas` / `__attribute__((packed))`'))
directive('extern "C"', 'ifdef __cplusplus\nextern "C" {\n#endif\n\n$0\n\n#ifdef __cplusplus\n}\n#endif',
    'Makes a C header usable from C++.')
directive('guard', nil, 'Include guard with the name of the file: `#ifndef` / `#define` / `#endif`.' ..
    alternatives('`pragma once`: shorter, supported by every usual compiler'))

local header_extensions = { h = true, hpp = true, hh = true, hxx = true, tcc = true, inc = true, ipp = true }

function M.is_header(name)
    return header_extensions[(name:match('%.(%w+)$') or ''):lower()] == true
end

-- Name of the macro of the guard: x.hpp -> X_H, c2dmp-hsm.hpp -> C2DMPHSM_H
local function guard_name(name)
    return vim.fn.fnamemodify(name, ':t:r'):upper():gsub('[^%w_]', '') .. '_H'
end

-- Items after a '#' (with_hash = false) or on a line that only holds a word (with_hash = true: the # is inserted)
-- file = { name = path of the buffer }: the directives are for the headers only, the #include lines for every file
function M.preprocessor(language, with_hash, file)
    local result = {}
    local prefix = with_hash and '#' or ''
    for _, entry in ipairs(entries) do
        if entry.context == 'include' and vim.tbl_contains(entry.languages, language) then
            table.insert(result, { label = prefix .. entry.label, match = 'include ' .. entry.label:gsub('^include ', ''),
                snippet = prefix .. entry.snippet, doc = entry.doc, kind = entry.kind, rank = 1, strict = with_hash })
        end
    end
    if file and M.is_header(file.name) then
        local guard = guard_name(file.name)
        for _, entry in ipairs(directive_entries) do
            local snippet = entry.snippet
            if entry.label == 'guard' then
                snippet = 'ifndef ' .. guard .. '\n\t#define ' .. guard .. '\n\n\t$0\n\n#endif /* ' .. guard .. ' */'
            end
            local special = entry.label == 'guard'
            table.insert(result, { label = special and '<guard>' or (prefix .. entry.label), match = entry.label,
                snippet = prefix .. snippet, doc = entry.doc, kind = special and 'Snippet' or 'Keyword', rank = 1,
                strict = with_hash, special = special or nil })
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Context and items
--------------------------------------------------------------------------------
local functions = { function_definition = true, function_declaration = true, lambda_expression = true, method_definition = true }

-- The cursor is inside a function (C / C++: a { } block of a function, Python / Lua: a function)
-- Without a treesitter parser: unclosed { before the cursor (braces in strings and comments are not skipped)
local function brace_depth(buf, row, col)
    local depth = 0
    for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, row + 1, false)) do
        if index == row + 1 then line = line:sub(1, col) end
        line = line:gsub('//.*$', '')
        for char in line:gmatch('[{}]') do depth = depth + (char == '{' and 1 or -1) end
    end
    return depth
end

local body_cache = {} -- buffer -> { row, lines, braces, result }

-- Typing on a line does not change where the cursor is, unless a { or } is typed (or lines are added): the syntax tree
-- (a parse at each key) is only asked again then
function M.in_body(buf, row, col)
    local text = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    local _, opened = text:sub(1, col):gsub('{', '')
    local _, closed = text:sub(1, col):gsub('}', '')
    local lines = vim.api.nvim_buf_line_count(buf)
    local cached = body_cache[buf]
    if cached and cached.row == row and cached.lines == lines and cached.opened == opened and cached.closed == closed then
        return cached.result
    end
    local result = M.in_body_uncached(buf, row, col)
    body_cache[buf] = { row = row, lines = lines, opened = opened, closed = closed, result = result }
    return result
end

function M.in_body_uncached(buf, row, col)
    local ok, parser = pcall(vim.treesitter.get_parser, buf)
    local trees = ok and parser and parser:parse()
    if not trees or not trees[1] then return brace_depth(buf, row, col) > 0 end
    local node = trees[1]:root():named_descendant_for_range(row, math.max(col - 1, 0), row, math.max(col - 1, 0))
    while node do
        local type = node:type()
        if type == 'compound_statement' or functions[type] then return true end
        -- A body not finished yet ('f() { mai }') is read as the value of a declaration: the { } after a function declarator
        if type == 'initializer_list' then
            local declaration = node:parent()
            local declarator = declaration and declaration:field('declarator')[1]
            if declarator and declarator:type() == 'function_declarator' then return true end
        end
        node = node:parent()
    end
    return false
end

local language_names = {
    c = 'c', cpp = 'cpp', python = 'python', lua = 'lua', sh = 'sh', bash = 'sh', zsh = 'sh', rust = 'rust',
    javascript = 'javascript', javascriptreact = 'javascript', typescript = 'typescript', typescriptreact = 'typescript',
    html = 'html', css = 'css', scss = 'scss', less = 'css', zig = 'zig', go = 'go', java = 'java', php = 'php',
    sql = 'sql', asm = 'asm', nasm = 'nasm', make = 'make',
}

-- context: 'top' | 'body' | 'hash' (after a '#') | 'line' (a line that only holds a word: the # is added)
function M.items(filetype, context, file)
    local language = language_names[filetype]
    local result = {}
    if not language then return result end
    if context == 'hash' or context == 'line' then
        return (language == 'c' or language == 'cpp') and M.preprocessor(language, context == 'line', file) or result
    end
    for _, entry in ipairs(entries) do
        if vim.tbl_contains(entry.languages, language) then
            local wanted = entry.context == 'any' or entry.context == context
                or (context == 'body' and entry.context == 'body')
            -- At the top level: the skeletons and the declarations, in a function: the statements and the word
            if wanted or (entry.group and entry.context ~= 'include' and context ~= 'include') then
                local snippet = entry.snippet
                if type(snippet) == 'function' then snippet = snippet(language, file)
                elseif type(snippet) == 'table' then snippet = snippet[language] end
                local preferred = entry.context == context or entry.context == 'any'
                table.insert(result, {
                    label = entry.label, snippet = snippet, doc = entry.doc, kind = entry.kind, group = entry.group,
                    rank = preferred and 1 or 2, match = entry.match, special = entry.special,
                })
            end
        end
    end
    return result
end

return M
