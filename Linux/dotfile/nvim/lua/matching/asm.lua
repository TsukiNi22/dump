-- Assembly x86-64 (NASM syntax, Linux, System V ABI): instructions, registers, system calls, directives and snippets
-- with their documentation (operands, where the result goes, flags, implicit registers, the AT&T form), for the
-- completion ([ins] [reg] [sys] [dir] [snip] [lbl]) and the help under the mouse / K
local M = {}

M.filetypes = { asm = true, nasm = true }

local syscall_registers = { 'rdi', 'rsi', 'rdx', 'r10', 'r8', 'r9' }
local comment_column = 24 -- Column of the ';' in the generated snippets

--------------------------------------------------------------------------------
-- Instructions
--------------------------------------------------------------------------------
-- name, forms ('syntax ; effect'), desc, ops { { operand, text } }, res (where the result goes), imp (implicit
-- registers), flags, att (AT&T / GAS form), note, snip (snippet when the default one built from the operands is not right)
local instructions = {}
local function ins(entry) table.insert(instructions, entry) end

local reg_mem = 'register or memory'
local reg_mem_imm = 'register, memory or immediate (no memory if dst is memory)'
local arith_flags = 'OF SF ZF AF CF PF set from the result'

-- Data movement
ins({ name = 'mov', forms = { 'mov dst, src ; dst = src' }, desc = 'Copies src into dst.',
    ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } }, res = '`dst`', flags = 'unchanged', att = 'movq %src, %dst',
    note = 'No memory to memory move. A 32-bit destination zeroes the upper 32 bits (`mov eax, 1` → rax = 1), an 8 / 16-bit one keeps the rest. Size of a memory store with an immediate: `mov qword [rdi], 0`.' })
ins({ name = 'movzx', forms = { 'movzx dst, src ; dst = zero extended src' }, desc = 'Copies a byte / word into a bigger register, the upper bits set to 0 (unsigned widening).',
    ops = { { 'dst', '16 / 32 / 64-bit register' }, { 'src', '8 / 16-bit register or memory (`byte [rsi]`)' } }, res = '`dst`', flags = 'unchanged', att = 'movzbq (%rsi), %rax',
    note = '32 → 64 bits: a plain `mov r32, r/m32` already zeroes the upper half. Usual: `movzx eax, byte [rsi]` to read one char.' })
ins({ name = 'movsx', forms = { 'movsx dst, src ; dst = sign extended src' }, desc = 'Copies a byte / word into a bigger register, keeping the sign (signed widening).',
    ops = { { 'dst', '16 / 32 / 64-bit register' }, { 'src', '8 / 16-bit register or memory' } }, res = '`dst`', flags = 'unchanged', att = 'movsbq (%rsi), %rax',
    note = '32 → 64 bits signed: `movsxd`.' })
ins({ name = 'movsxd', forms = { 'movsxd dst64, src32 ; dst = sign extended src' }, desc = 'Widens a signed 32-bit value to 64 bits.',
    ops = { { 'dst64', '64-bit register' }, { 'src32', '32-bit register or memory' } }, res = '`dst64`', flags = 'unchanged', att = 'movslq %eax, %rax',
    note = 'For eax → rax: `cdqe` (shorter).' })
ins({ name = 'lea', forms = { 'lea dst, [base + index*scale + disp] ; dst = address' }, desc = 'Computes an address without reading memory (Load Effective Address).',
    ops = { { 'dst', 'register' }, { '[...]', 'address: base + index * 1/2/4/8 + displacement' } }, res = '`dst`', flags = 'unchanged', att = 'leaq 8(%rdi,%rsi,4), %rax',
    note = 'Also cheap arithmetic: `lea rax, [rdi + rsi*4 + 8]`. Address of a label, position independent (PIE): `lea rsi, [rel message]`.' })
ins({ name = 'xchg', forms = { 'xchg a, b ; a <-> b' }, desc = 'Swaps two operands.', ops = { { 'a', reg_mem }, { 'b', 'register (one of the two)' } },
    res = '`a` and `b`', flags = 'unchanged', att = 'xchgq %rax, %rbx', note = 'With a memory operand it is atomic (implicit lock, slow).' })
ins({ name = 'push', forms = { 'push src ; rsp -= 8, [rsp] = src' }, desc = 'Pushes a value on the stack.', ops = { { 'src', '64-bit register, memory or immediate (sign-extended imm32)' } },
    res = '`[rsp]`', imp = 'writes `rsp`', flags = 'unchanged', att = 'pushq %rbx',
    note = 'The stack must be 16-byte aligned before a `call`: count your pushes (each one moves rsp by 8).' })
ins({ name = 'pop', forms = { 'pop dst ; dst = [rsp], rsp += 8' }, desc = 'Pops the top of the stack into dst.', ops = { { 'dst', '64-bit register or memory' } },
    res = '`dst`', imp = 'writes `rsp`', flags = 'unchanged', att = 'popq %rbx', note = 'Pop in the reverse order of the pushes.' })
ins({ name = 'bswap', forms = { 'bswap reg ; reverses the byte order' }, desc = 'Reverses the bytes of a 32 / 64-bit register (endianness: htonl).',
    ops = { { 'reg', '32 / 64-bit register' } }, res = '`reg`', flags = 'unchanged', att = 'bswapq %rax' })

-- Arithmetic
ins({ name = 'add', forms = { 'add dst, src ; dst = dst + src' }, desc = 'Addition.', ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } },
    res = '`dst`', flags = arith_flags .. ' (CF = unsigned carry, OF = signed overflow)', att = 'addq %src, %dst' })
ins({ name = 'sub', forms = { 'sub dst, src ; dst = dst - src' }, desc = 'Subtraction.', ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } },
    res = '`dst`', flags = arith_flags .. ' (CF = unsigned borrow)', att = 'subq %src, %dst', note = 'Reserve stack space: `sub rsp, 32`.' })
ins({ name = 'adc', forms = { 'adc dst, src ; dst = dst + src + CF' }, desc = 'Addition with the carry of the previous one (big numbers).',
    ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } }, res = '`dst`', imp = 'reads CF', flags = arith_flags, att = 'adcq %src, %dst' })
ins({ name = 'sbb', forms = { 'sbb dst, src ; dst = dst - (src + CF)' }, desc = 'Subtraction with the borrow of the previous one.',
    ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } }, res = '`dst`', imp = 'reads CF', flags = arith_flags, att = 'sbbq %src, %dst',
    note = '`sbb eax, eax` → eax = -1 if CF else 0 (branchless mask).' })
ins({ name = 'inc', forms = { 'inc dst ; dst = dst + 1' }, desc = 'Adds 1.', ops = { { 'dst', reg_mem } }, res = '`dst`',
    flags = 'OF SF ZF AF PF set, CF unchanged', att = 'incq %rax', note = 'Memory: give the size, `inc qword [counter]`.' })
ins({ name = 'dec', forms = { 'dec dst ; dst = dst - 1' }, desc = 'Subtracts 1.', ops = { { 'dst', reg_mem } }, res = '`dst`',
    flags = 'OF SF ZF AF PF set, CF unchanged', att = 'decq %rcx', note = 'Loop: `dec rcx` then `jnz .loop`.' })
ins({ name = 'neg', forms = { 'neg dst ; dst = -dst' }, desc = 'Two\'s complement negation.', ops = { { 'dst', reg_mem } }, res = '`dst`',
    flags = arith_flags .. ', CF = 1 unless dst was 0', att = 'negq %rax' })
ins({ name = 'mul', forms = { 'mul src ; rdx:rax = rax * src (64-bit)', 'mul src32 ; edx:eax = eax * src', 'mul src8 ; ax = al * src' },
    desc = 'Unsigned multiplication of rax by src.', ops = { { 'src', 'register or memory (no immediate: use `imul dst, src, imm`)' } },
    res = '`rdx:rax`: low half in `rax`, high half in `rdx`', imp = 'reads `rax`, writes `rax` and `rdx`',
    flags = 'CF = OF = 1 when the high half (rdx) is not 0, SF ZF AF PF undefined', att = 'mulq %rbx',
    note = 'rdx is always overwritten, even when the result fits in rax: save it if it holds a value (3rd argument!).' })
ins({ name = 'imul', forms = { 'imul src ; rdx:rax = rax * src (signed)', 'imul dst, src ; dst = dst * src', 'imul dst, src, imm ; dst = src * imm' },
    desc = 'Signed multiplication (the 2 / 3 operand forms keep the low half only: fine for signed and unsigned).',
    ops = { { 'dst', 'register' }, { 'src', reg_mem }, { 'imm', 'immediate (3 operand form)' } },
    res = '`rdx:rax` (1 operand) or `dst` (2 / 3 operands)', imp = '1 operand form: reads `rax`, writes `rax` and `rdx`',
    flags = 'CF = OF = 1 when the result was truncated, SF ZF AF PF undefined', att = 'imulq %rbx, %rax',
    snip = 'imul ${1:dst}, ${2:src}', note = 'Usual form: `imul rax, rbx` or `imul rax, rbx, 10` (does not touch rdx).' })
ins({ name = 'div', forms = { 'div src ; rax = rdx:rax / src, rdx = rdx:rax % src' },
    desc = 'Unsigned division of the 128-bit rdx:rax by src.', ops = { { 'src', 'register or memory (no immediate)' } },
    res = 'quotient in `rax`, remainder in `rdx` (32-bit: eax / edx, 8-bit: al / ah)', imp = 'reads `rdx:rax`, writes `rax` and `rdx`', flags = 'undefined',
    att = 'divq %rbx', note = 'Zero rdx first (`xor edx, edx`): an old value in rdx changes the dividend and a too big quotient crashes (#DE). Division by 0 → SIGFPE.' })
ins({ name = 'idiv', forms = { 'idiv src ; rax = rdx:rax / src, rdx = rdx:rax % src (signed)' },
    desc = 'Signed division of rdx:rax by src (the quotient is rounded toward 0, the remainder has the sign of the dividend).',
    ops = { { 'src', 'register or memory (no immediate)' } }, res = 'quotient in `rax`, remainder in `rdx`', imp = 'reads `rdx:rax`, writes `rax` and `rdx`',
    flags = 'undefined', att = 'idivq %rbx', note = 'Sign-extend rax into rdx first: `cqo` (64-bit) / `cdq` (32-bit). Division by 0 → SIGFPE.' })
ins({ name = 'cqo', forms = { 'cqo ; rdx:rax = sign extended rax' }, desc = 'Fills rdx with the sign of rax, before `idiv`.', res = '`rdx`', imp = 'reads `rax`', flags = 'unchanged', att = 'cqto' })
ins({ name = 'cdq', forms = { 'cdq ; edx:eax = sign extended eax' }, desc = 'Fills edx with the sign of eax, before a 32-bit `idiv`.', res = '`edx`', imp = 'reads `eax`', flags = 'unchanged', att = 'cltd' })
ins({ name = 'cdqe', forms = { 'cdqe ; rax = sign extended eax' }, desc = 'Widens the signed eax to rax.', res = '`rax`', imp = 'reads `eax`', flags = 'unchanged', att = 'cltq' })
ins({ name = 'cmp', forms = { 'cmp a, b ; flags = a - b (nothing stored)' }, desc = 'Compares two values: a subtraction that only sets the flags.',
    ops = { { 'a', reg_mem }, { 'b', reg_mem_imm } }, res = 'the flags only', flags = arith_flags, att = 'cmpq %b, %a (reversed!)',
    note = 'Then `jcc` / `setcc` / `cmovcc`. Signed: `jl jle jg jge`, unsigned: `jb jbe ja jae`.' })

-- Logic, shifts, bits
ins({ name = 'test', forms = { 'test a, b ; flags = a & b (nothing stored)' }, desc = 'Bitwise AND that only sets the flags.',
    ops = { { 'a', reg_mem }, { 'b', 'register or immediate' } }, res = 'the flags only', flags = 'SF ZF PF set, CF = OF = 0', att = 'testq %rax, %rax',
    note = '`test rax, rax` then `jz` / `js`: is it 0 / negative (shorter than `cmp rax, 0`).' })
ins({ name = 'and', forms = { 'and dst, src ; dst = dst & src' }, desc = 'Bitwise AND.', ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } }, res = '`dst`',
    flags = 'SF ZF PF set, CF = OF = 0', att = 'andq %src, %dst', note = 'Align the stack: `and rsp, -16`.' })
ins({ name = 'or', forms = { 'or dst, src ; dst = dst | src' }, desc = 'Bitwise OR.', ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } }, res = '`dst`',
    flags = 'SF ZF PF set, CF = OF = 0', att = 'orq %src, %dst' })
ins({ name = 'xor', forms = { 'xor dst, src ; dst = dst ^ src' }, desc = 'Bitwise exclusive OR.', ops = { { 'dst', reg_mem }, { 'src', reg_mem_imm } }, res = '`dst`',
    flags = 'SF ZF PF set, CF = OF = 0', att = 'xorq %src, %dst', note = '`xor eax, eax`: the usual way to set a register to 0 (short, zeroes all of rax).' })
ins({ name = 'not', forms = { 'not dst ; dst = ~dst' }, desc = 'Bitwise NOT (one\'s complement).', ops = { { 'dst', reg_mem } }, res = '`dst`', flags = 'unchanged', att = 'notq %rax' })
local shift_ops = { { 'dst', reg_mem }, { 'count', 'immediate or `cl` (only cl, masked to 0-63)' } }
ins({ name = 'shl', forms = { 'shl dst, count ; dst = dst << count' }, desc = 'Shift left (multiplies by 2^count).', ops = shift_ops, res = '`dst`',
    flags = 'CF = last bit shifted out, SF ZF PF set, OF defined for count 1', att = 'shlq $3, %rax', note = 'Same instruction as `sal`.' })
ins({ name = 'sal', forms = { 'sal dst, count ; dst = dst << count' }, desc = 'Arithmetic shift left (same as `shl`).', ops = shift_ops, res = '`dst`',
    flags = 'CF = last bit shifted out', att = 'salq $3, %rax' })
ins({ name = 'shr', forms = { 'shr dst, count ; dst = dst >> count (unsigned)' }, desc = 'Logical shift right: zeros come in (unsigned division by 2^count).', ops = shift_ops, res = '`dst`',
    flags = 'CF = last bit shifted out, SF ZF PF set', att = 'shrq $1, %rax' })
ins({ name = 'sar', forms = { 'sar dst, count ; dst = dst >> count (signed)' }, desc = 'Arithmetic shift right: copies of the sign bit come in (signed division by 2^count, rounded toward -infinity).',
    ops = shift_ops, res = '`dst`', flags = 'CF = last bit shifted out, SF ZF PF set', att = 'sarq $1, %rax' })
ins({ name = 'rol', forms = { 'rol dst, count ; rotate left' }, desc = 'Rotation left: the bits leaving on the left come back on the right.', ops = shift_ops, res = '`dst`', flags = 'CF = last bit rotated', att = 'rolq $8, %rax' })
ins({ name = 'ror', forms = { 'ror dst, count ; rotate right' }, desc = 'Rotation right.', ops = shift_ops, res = '`dst`', flags = 'CF = last bit rotated', att = 'rorq $8, %rax' })
ins({ name = 'bt', forms = { 'bt src, n ; CF = bit n of src' }, desc = 'Tests one bit.', ops = { { 'src', reg_mem }, { 'n', 'register or immediate' } }, res = '`CF`', flags = 'CF = the bit', att = 'btq $3, %rax',
    note = 'Then `jc` / `jnc`. `bts` / `btr` / `btc` also set / clear / flip the bit.' })
ins({ name = 'bsf', forms = { 'bsf dst, src ; dst = index of the lowest set bit' }, desc = 'Bit scan forward.', ops = { { 'dst', 'register' }, { 'src', reg_mem } }, res = '`dst`',
    flags = 'ZF = 1 when src is 0 (dst then undefined)', att = 'bsfq %rbx, %rax', note = '`tzcnt` gives 64 for 0 instead.' })
ins({ name = 'bsr', forms = { 'bsr dst, src ; dst = index of the highest set bit' }, desc = 'Bit scan reverse (log2 of src).', ops = { { 'dst', 'register' }, { 'src', reg_mem } }, res = '`dst`',
    flags = 'ZF = 1 when src is 0', att = 'bsrq %rbx, %rax', note = '`lzcnt` counts the leading zeros.' })
ins({ name = 'popcnt', forms = { 'popcnt dst, src ; dst = number of set bits' }, desc = 'Counts the bits set to 1.', ops = { { 'dst', 'register' }, { 'src', reg_mem } }, res = '`dst`',
    flags = 'ZF = (src == 0), others 0', att = 'popcntq %rbx, %rax' })
ins({ name = 'tzcnt', forms = { 'tzcnt dst, src ; dst = trailing zeros' }, desc = 'Counts the zeros below the lowest set bit (64 for 0).', ops = { { 'dst', 'register' }, { 'src', reg_mem } }, res = '`dst`', flags = 'CF = (src == 0), ZF = (dst == 0)', att = 'tzcntq %rbx, %rax' })
ins({ name = 'lzcnt', forms = { 'lzcnt dst, src ; dst = leading zeros' }, desc = 'Counts the zeros above the highest set bit (64 for 0).', ops = { { 'dst', 'register' }, { 'src', reg_mem } }, res = '`dst`', flags = 'CF = (src == 0), ZF = (dst == 0)', att = 'lzcntq %rbx, %rax' })

-- Control flow
ins({ name = 'jmp', forms = { 'jmp label ; rip = label', 'jmp reg / [mem] ; indirect jump' }, desc = 'Unconditional jump.', ops = { { 'label', 'label, register or memory' } },
    res = '`rip`', flags = 'unchanged', att = 'jmp label / jmp *%rax', snip = 'jmp ${1:label}' })
ins({ name = 'call', forms = { 'call function ; push return address, jmp function' }, desc = 'Calls a function: pushes the address of the next instruction then jumps.',
    ops = { { 'function', 'label, register or memory' } }, res = 'return value in `rax` (`rdx:rax` for 128 bits, `xmm0` for a float)', imp = 'writes `rsp` (-8)',
    flags = 'whatever the function leaves', att = 'call function / call *%rax',
    note = 'System V: arguments in `rdi rsi rdx rcx r8 r9` (floats `xmm0-7`), then on the stack. rsp must be 16-byte aligned *before* the call. The callee may destroy `rax rcx rdx rsi rdi r8-r11 xmm*`, it keeps `rbx rbp r12-r15`. Variadic (printf): `al` = number of vector registers used (`xor eax, eax`). libc in a PIE: `call printf wrt ..plt`.' })
ins({ name = 'ret', forms = { 'ret ; rip = [rsp], rsp += 8' }, desc = 'Returns to the caller (pops the return address).', imp = 'reads and writes `rsp`', flags = 'unchanged', att = 'ret',
    note = 'rsp must point to the return address again: undo the pushes / `sub rsp` first (`leave`). Return value in `rax`.' })
ins({ name = 'loop', forms = { 'loop label ; rcx -= 1, jump if rcx != 0' }, desc = 'Counted loop on rcx.', ops = { { 'label', 'label (short jump)' } }, res = '`rcx`, `rip`',
    imp = 'reads and writes `rcx`', flags = 'unchanged', att = 'loop label', note = 'Slower than `dec rcx` + `jnz label` on recent CPUs.' })
ins({ name = 'syscall', forms = { 'syscall ; rax = kernel function rax(rdi, rsi, rdx, r10, r8, r9)' }, desc = 'Calls the kernel (Linux x86-64).',
    res = '`rax`: the result, or `-errno` on error (rax in -4095 to -1)', imp = 'reads `rax` (number) and `rdi rsi rdx r10 r8 r9` (arguments), destroys `rcx` (return rip) and `r11` (rflags)',
    flags = 'unchanged for the program (restored from r11)', att = 'syscall',
    note = '4th argument in **r10**, not rcx. All the other registers are kept. Usual errors: -1 EPERM, -2 ENOENT, -9 EBADF, -11 EAGAIN, -12 ENOMEM, -13 EACCES, -14 EFAULT, -17 EEXIST, -22 EINVAL. Type `sys_` for the calls with their arguments.' })
ins({ name = 'int', forms = { 'int n ; software interrupt n' }, desc = 'Software interrupt. `int 0x80` = the old 32-bit system calls.', ops = { { 'n', 'immediate byte' } },
    flags = 'IF TF cleared during the handler', att = 'int $0x80',
    note = '`int 0x80` uses the 32-bit numbers (eax) and registers (ebx ecx edx esi edi ebp) and truncates the pointers to 32 bits: use `syscall` in 64-bit code. `int3` = breakpoint.' })
ins({ name = 'int3', forms = { 'int3 ; breakpoint' }, desc = 'Breakpoint trap (SIGTRAP), stops in gdb.', flags = 'unchanged', att = 'int3' })
ins({ name = 'leave', forms = { 'leave ; mov rsp, rbp + pop rbp' }, desc = 'Undoes the stack frame made by the prologue (before `ret`).', res = '`rsp`, `rbp`', imp = 'reads `rbp`', flags = 'unchanged', att = 'leave' })
ins({ name = 'enter', forms = { 'enter size, 0 ; push rbp, mov rbp, rsp, sub rsp, size' }, desc = 'Makes a stack frame of size bytes of locals.',
    ops = { { 'size', 'bytes of locals (multiple of 16)' }, { '0', 'nesting level, always 0 in C-like code' } }, res = '`rsp`, `rbp`', flags = 'unchanged', att = 'enter $16, $0',
    snip = 'enter ${1:16}, 0', note = 'Much slower than the 3 instructions it replaces: compilers never use it.' })
ins({ name = 'nop', forms = { 'nop ; nothing' }, desc = 'Does nothing (padding, alignment).', flags = 'unchanged', att = 'nop' })
ins({ name = 'hlt', forms = { 'hlt ; halts the CPU' }, desc = 'Halts until the next interrupt. Kernel mode only: in a program it crashes (SIGSEGV).', flags = 'unchanged', att = 'hlt' })
ins({ name = 'ud2', forms = { 'ud2 ; invalid instruction' }, desc = 'Raises an invalid opcode (SIGILL): marks a place that must never be reached.', flags = 'unchanged', att = 'ud2' })
ins({ name = 'cpuid', forms = { 'cpuid ; eax ebx ecx edx = CPU information for leaf eax' }, desc = 'CPU identification (vendor, features).', res = '`eax ebx ecx edx`', imp = 'reads `eax` (leaf) and `ecx` (sub-leaf)', flags = 'unchanged', att = 'cpuid' })
ins({ name = 'rdtsc', forms = { 'rdtsc ; edx:eax = time stamp counter' }, desc = 'Reads the cycle counter of the CPU (benchmarks).', res = '`edx:eax` (high:low, upper halves of rax / rdx zeroed)', flags = 'unchanged', att = 'rdtsc',
    note = 'Full value: `shl rdx, 32` then `or rax, rdx`.' })

-- Strings (rsi = source, rdi = destination, rcx = count with rep, DF = direction)
local string_note = 'Moves forward when DF = 0 (`cld`, the ABI default). b / w / d / q = 1 / 2 / 4 / 8 bytes.'
ins({ name = 'movsb', forms = { 'movsb ; [rdi] = [rsi], rsi += 1, rdi += 1', 'rep movsb ; memcpy(rdi, rsi, rcx)' }, desc = 'Copies bytes from [rsi] to [rdi].',
    res = '`[rdi]`', imp = 'reads and advances `rsi`, `rdi` (and decrements `rcx` with `rep`)', flags = 'unchanged', att = 'rep movsb', note = string_note })
ins({ name = 'movsq', forms = { 'movsq ; [rdi] = [rsi] (8 bytes), rsi += 8, rdi += 8', 'rep movsq ; copies rcx qwords' }, desc = 'Copies qwords from [rsi] to [rdi].',
    res = '`[rdi]`', imp = '`rsi`, `rdi`, `rcx` with rep', flags = 'unchanged', att = 'rep movsq', note = string_note })
ins({ name = 'stosb', forms = { 'stosb ; [rdi] = al, rdi += 1', 'rep stosb ; memset(rdi, al, rcx)' }, desc = 'Stores al at [rdi].',
    res = '`[rdi]`', imp = 'reads `al`, advances `rdi` (`rcx` with rep)', flags = 'unchanged', att = 'rep stosb', note = string_note })
ins({ name = 'stosq', forms = { 'stosq ; [rdi] = rax, rdi += 8', 'rep stosq ; fills rcx qwords with rax' }, desc = 'Stores rax at [rdi].',
    res = '`[rdi]`', imp = 'reads `rax`, advances `rdi` (`rcx` with rep)', flags = 'unchanged', att = 'rep stosq', note = string_note })
ins({ name = 'lodsb', forms = { 'lodsb ; al = [rsi], rsi += 1' }, desc = 'Loads the byte at [rsi] into al.', res = '`al`', imp = 'advances `rsi`', flags = 'unchanged', att = 'lodsb', note = string_note })
ins({ name = 'scasb', forms = { 'scasb ; compare al with [rdi], rdi += 1', 'repne scasb ; finds al (strlen / memchr)' }, desc = 'Compares al with the byte at [rdi].',
    res = 'the flags', imp = 'reads `al`, advances `rdi` (`rcx` with repne)', flags = 'like `cmp al, [rdi]`', att = 'repne scasb',
    note = 'strlen: `xor al, al` / `mov rcx, -1` / `repne scasb` / `not rcx` / `dec rcx` → length in rcx. ' .. string_note })
ins({ name = 'cmpsb', forms = { 'cmpsb ; compare [rsi] with [rdi], both += 1', 'repe cmpsb ; memcmp on rcx bytes' }, desc = 'Compares the bytes at [rsi] and [rdi].',
    res = 'the flags', imp = 'advances `rsi`, `rdi` (`rcx` with repe)', flags = 'like `cmp [rsi], [rdi]`', att = 'repe cmpsb', note = string_note })
ins({ name = 'rep', forms = { 'rep movsb / stosb ; repeats rcx times' }, desc = 'Prefix: repeats the string instruction while rcx != 0 (rcx decremented each time).', imp = 'reads and writes `rcx`', flags = 'unchanged',
    snip = 'rep ${1:movsb}', note = '`repe` / `repne`: also stop when the comparison is not equal / is equal (with cmps / scas).' })
ins({ name = 'lock', forms = { 'lock add [mem], src ; atomic read-modify-write' }, desc = 'Prefix: makes the memory operation atomic (threads).', flags = 'those of the instruction',
    snip = 'lock ${1:add} ${2:qword [mem]}, ${3:1}', note = 'Works with add sub inc dec and or xor xadd cmpxchg bts... `xchg` with memory is always locked.' })
ins({ name = 'xadd', forms = { 'xadd dst, src ; tmp = dst + src, src = dst, dst = tmp' }, desc = 'Exchange and add (atomic fetch_add with `lock`).',
    ops = { { 'dst', reg_mem }, { 'src', 'register' } }, res = '`dst` (sum) and `src` (old dst)', flags = arith_flags, att = 'lock xaddq %rax, (%rdi)' })
ins({ name = 'cmpxchg', forms = { 'cmpxchg dst, src ; if rax == dst: dst = src else rax = dst' }, desc = 'Compare and swap (atomic with `lock`).',
    ops = { { 'dst', reg_mem }, { 'src', 'register' } }, res = '`dst` or `rax`, ZF = 1 when the swap happened', imp = 'reads and writes `rax`', flags = 'like `cmp rax, dst`', att = 'lock cmpxchgq %rbx, (%rdi)' })
ins({ name = 'cld', forms = { 'cld ; DF = 0' }, desc = 'Clears the direction flag: the string instructions move forward.', flags = 'DF = 0', att = 'cld' })
ins({ name = 'std', forms = { 'std ; DF = 1' }, desc = 'Sets the direction flag: the string instructions move backward (restore with `cld`).', flags = 'DF = 1', att = 'std' })
ins({ name = 'clc', forms = { 'clc ; CF = 0' }, desc = 'Clears the carry flag.', flags = 'CF = 0', att = 'clc' })
ins({ name = 'stc', forms = { 'stc ; CF = 1' }, desc = 'Sets the carry flag.', flags = 'CF = 1', att = 'stc' })

-- Floats (SSE2, scalar): ss = float (32-bit), sd = double (64-bit)
local float_note = 'Floats are passed and returned in `xmm0-7` (`xmm0` = return value), all caller-saved. ss = float, sd = double.'
local float_ops = { { 'dst', 'xmm register' }, { 'src', 'xmm register or memory' } }
for _, op in ipairs({ { 'add', '+', 'Addition' }, { 'sub', '-', 'Subtraction' }, { 'mul', '*', 'Multiplication' }, { 'div', '/', 'Division' } }) do
    for _, kind in ipairs({ { 'ss', 'float' }, { 'sd', 'double' } }) do
        ins({ name = op[1] .. kind[1], forms = { op[1] .. kind[1] .. ' dst, src ; dst = dst ' .. op[2] .. ' src (' .. kind[2] .. ')' },
            desc = op[3] .. ' of ' .. kind[2] .. 's.', ops = float_ops, res = '`dst` (low lane)', flags = 'unchanged', att = op[1] .. kind[1] .. ' %xmm1, %xmm0', note = float_note })
    end
end
ins({ name = 'movss', forms = { 'movss dst, src ; one float' }, desc = 'Moves a float (32-bit) between xmm registers and memory.', ops = float_ops, res = '`dst`', flags = 'unchanged', att = 'movss (%rdi), %xmm0', note = float_note })
ins({ name = 'movsd', forms = { 'movsd xmm, src ; one double (SSE)', 'movsd ; [rdi] = [rsi] 4 bytes (string, no operands)' }, desc = 'Moves a double between xmm registers and memory (with operands), or copies a dword (string form).',
    ops = float_ops, res = '`dst`', flags = 'unchanged', att = 'movsd (%rdi), %xmm0', note = float_note })
ins({ name = 'sqrtsd', forms = { 'sqrtsd dst, src ; dst = sqrt(src)' }, desc = 'Square root of a double.', ops = float_ops, res = '`dst`', flags = 'unchanged', att = 'sqrtsd %xmm1, %xmm0', note = float_note })
ins({ name = 'cvtsi2sd', forms = { 'cvtsi2sd xmm, int ; xmm = (double) int' }, desc = 'Integer → double.', ops = { { 'xmm', 'xmm register' }, { 'int', '32 / 64-bit register or memory' } }, res = '`xmm`', flags = 'unchanged', att = 'cvtsi2sdq %rax, %xmm0', snip = 'cvtsi2sd ${1:xmm0}, ${2:rax}' })
ins({ name = 'cvttsd2si', forms = { 'cvttsd2si reg, xmm ; reg = (long) xmm, truncated' }, desc = 'Double → integer, truncated toward 0 (like a C cast).', ops = { { 'reg', '32 / 64-bit register' }, { 'xmm', 'xmm register or memory' } }, res = '`reg`', flags = 'unchanged', att = 'cvttsd2si %xmm0, %rax', snip = 'cvttsd2si ${1:rax}, ${2:xmm0}' })
ins({ name = 'cvtss2sd', forms = { 'cvtss2sd dst, src ; float → double' }, desc = 'Float → double.', ops = float_ops, res = '`dst`', flags = 'unchanged', att = 'cvtss2sd %xmm1, %xmm0', note = 'printf takes doubles: convert the floats first.' })
ins({ name = 'ucomisd', forms = { 'ucomisd a, b ; compares two doubles' }, desc = 'Compares doubles and sets the flags like an unsigned compare.', ops = { { 'a', 'xmm register' }, { 'b', 'xmm register or memory' } }, res = 'the flags',
    flags = 'ZF PF CF (PF = 1: one of them is NaN)', att = 'ucomisd %xmm1, %xmm0', note = 'Then `ja jae jb jbe je` (the unsigned conditions), `jp` for NaN.' })
ins({ name = 'pxor', forms = { 'pxor xmm, xmm ; xmm = 0 when both are the same' }, desc = 'Bitwise XOR of xmm registers: `pxor xmm0, xmm0` sets 0.0.', ops = { { 'dst', 'xmm register' }, { 'src', 'xmm register or memory' } }, res = '`dst`', flags = 'unchanged', att = 'pxor %xmm0, %xmm0' })
ins({ name = 'movq', forms = { 'movq xmm, r64 ; bits of r64 into xmm', 'movq r64, xmm ; bits of xmm into r64' }, desc = 'Copies 64 bits between a general register and an xmm register (no conversion).',
    ops = { { 'dst', 'xmm or 64-bit register' }, { 'src', 'xmm or 64-bit register / memory' } }, res = '`dst`', flags = 'unchanged', att = 'movq %rax, %xmm0' })

-- Conditions: jcc, setcc, cmovcc
local conditions = {
    { 'e', 'equal / zero', 'ZF = 1', { 'z' } }, { 'ne', 'not equal / not zero', 'ZF = 0', { 'nz' } },
    { 'g', 'greater (signed >)', 'ZF = 0 and SF = OF', { 'nle' } }, { 'ge', 'greater or equal (signed >=)', 'SF = OF', { 'nl' } },
    { 'l', 'less (signed <)', 'SF != OF', { 'nge' } }, { 'le', 'less or equal (signed <=)', 'ZF = 1 or SF != OF', { 'ng' } },
    { 'a', 'above (unsigned >)', 'CF = 0 and ZF = 0', { 'nbe' } }, { 'ae', 'above or equal (unsigned >=)', 'CF = 0', { 'nb', 'nc' } },
    { 'b', 'below (unsigned <)', 'CF = 1', { 'nae', 'c' } }, { 'be', 'below or equal (unsigned <=)', 'CF = 1 or ZF = 1', { 'na' } },
    { 's', 'sign (negative)', 'SF = 1', {} }, { 'ns', 'not sign (positive or 0)', 'SF = 0', {} },
    { 'o', 'overflow (signed)', 'OF = 1', {} }, { 'no', 'no overflow', 'OF = 0', {} },
    { 'p', 'parity (NaN after ucomisd)', 'PF = 1', { 'pe' } }, { 'np', 'no parity', 'PF = 0', { 'po' } },
}
local condition_note = 'After `cmp a, b`: the condition is read as "a <cond> b". Signed: g ge l le, unsigned: a ae b be.'
for _, condition in ipairs(conditions) do
    for index, suffix in ipairs({ condition[1], unpack(condition[4]) }) do
        local alias = index > 1 and (' Same as the `' .. condition[1] .. '` form.') or ''
        ins({ name = 'j' .. suffix, forms = { 'j' .. suffix .. ' label ; jump if ' .. condition[2] }, desc = 'Jumps when ' .. condition[2] .. ' (' .. condition[3] .. ').' .. alias,
            ops = { { 'label', 'label' } }, res = '`rip`', imp = 'reads the flags: ' .. condition[3], flags = 'unchanged', att = 'j' .. suffix .. ' label', note = condition_note })
        ins({ name = 'set' .. suffix, forms = { 'set' .. suffix .. ' dst8 ; dst8 = 1 if ' .. condition[2] .. ' else 0' }, desc = 'Stores 1 when ' .. condition[2] .. ' (' .. condition[3] .. '), else 0.' .. alias,
            ops = { { 'dst8', '8-bit register or memory (`al`, `byte [x]`)' } }, res = '`dst8`', imp = 'reads the flags', flags = 'unchanged', att = 'set' .. suffix .. ' %al',
            note = 'A byte only: widen it with `movzx eax, al`. ' .. condition_note })
        ins({ name = 'cmov' .. suffix, forms = { 'cmov' .. suffix .. ' dst, src ; dst = src if ' .. condition[2] }, desc = 'Moves src into dst when ' .. condition[2] .. ' (' .. condition[3] .. '), branchless.' .. alias,
            ops = { { 'dst', '16 / 32 / 64-bit register' }, { 'src', 'register or memory (no immediate)' } }, res = '`dst`', imp = 'reads the flags', flags = 'unchanged',
            att = 'cmov' .. suffix .. 'q %rbx, %rax', note = 'A 32-bit dst is zero-extended even when nothing is moved. ' .. condition_note })
    end
end

--------------------------------------------------------------------------------
-- Registers
--------------------------------------------------------------------------------
-- { 64, 32, 16, low 8, high 8, role }
local register_list = {
    { 'rax', 'eax', 'ax', 'al', 'ah', 'Accumulator. **Return value** of the functions (`rdx:rax` for 128 bits), **number of the system call** before `syscall` and its result after, implicit operand of `mul` / `div`. Variadic calls: `al` = number of vector registers used. Caller-saved.' },
    { 'rbx', 'ebx', 'bx', 'bl', 'bh', 'General purpose. **Callee-saved**: a function that uses it must push / pop it.' },
    { 'rcx', 'ecx', 'cx', 'cl', 'ch', '**4th argument** of a function. Counter of `loop` and `rep`, `cl` = count of the shifts. **Destroyed by `syscall`** (return address). Caller-saved.' },
    { 'rdx', 'edx', 'dx', 'dl', 'dh', '**3rd argument** (functions and system calls). High half of `mul` / `div` (`rdx:rax`), 2nd return register. Caller-saved.' },
    { 'rsi', 'esi', 'si', 'sil', nil, '**2nd argument** (functions and system calls). Source of the string instructions (`movs`, `lods`, `cmps`). Caller-saved.' },
    { 'rdi', 'edi', 'di', 'dil', nil, '**1st argument** (functions and system calls). Destination of the string instructions (`movs`, `stos`, `scas`). Caller-saved.' },
    { 'rbp', 'ebp', 'bp', 'bpl', nil, '**Frame pointer**: base of the frame after `push rbp` / `mov rbp, rsp` (locals at `[rbp - 8]`..., stack arguments from `[rbp + 16]`). Callee-saved.' },
    { 'rsp', 'esp', 'sp', 'spl', nil, '**Stack pointer**: top of the stack, which grows down. Must be **16-byte aligned before each `call`** (at the entry of a function it is 8 off: the return address). Changed by push / pop / call / ret.' },
    { 'r8', 'r8d', 'r8w', 'r8b', nil, '**5th argument** (functions and system calls). Caller-saved.' },
    { 'r9', 'r9d', 'r9w', 'r9b', nil, '**6th argument** (functions and system calls). The next arguments go on the stack. Caller-saved.' },
    { 'r10', 'r10d', 'r10w', 'r10b', nil, '**4th argument of a system call** (rcx for a function: `syscall` destroys rcx). Caller-saved.' },
    { 'r11', 'r11d', 'r11w', 'r11b', nil, 'Scratch. **Destroyed by `syscall`** (holds rflags). Caller-saved.' },
    { 'r12', 'r12d', 'r12w', 'r12b', nil, 'General purpose. **Callee-saved** (kept across calls: good for values that must survive a `call`).' },
    { 'r13', 'r13d', 'r13w', 'r13b', nil, 'General purpose. **Callee-saved**.' },
    { 'r14', 'r14d', 'r14w', 'r14b', nil, 'General purpose. **Callee-saved**.' },
    { 'r15', 'r15d', 'r15w', 'r15b', nil, 'General purpose. **Callee-saved**.' },
}
local registers = {} -- name -> { name, size, doc }
local register_order = {}
local function add_register(name, size, doc)
    registers[name] = { name = name, size = size, doc = doc }
    table.insert(register_order, name)
end
for _, reg in ipairs(register_list) do
    add_register(reg[1], 64, reg[6])
    add_register(reg[2], 32, 'Low 32 bits of `' .. reg[1] .. '`. **Writing it zeroes the upper 32 bits** of ' .. reg[1] .. '.\n\n' .. reg[6])
    add_register(reg[3], 16, 'Low 16 bits of `' .. reg[1] .. '` (writing it keeps the other bits).\n\n' .. reg[6])
    add_register(reg[4], 8, 'Low byte of `' .. reg[1] .. '` (writing it keeps the other bits).\n\n' .. reg[6])
    if reg[5] then add_register(reg[5], 8, 'Bits 8-15 of `' .. reg[1] .. '` (not usable with r8-r15, sil, dil... in the same instruction).\n\n' .. reg[6]) end
end
local ordinals = { '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th' }
for index = 0, 15 do
    local role = index == 0 and '**1st float argument and float return value**.'
        or index < 8 and ('**' .. ordinals[index + 1] .. ' float argument**.') or 'Scratch.'
    add_register('xmm' .. index, 128, 'SSE register (128 bits: 1 double / float in the low lane for scalar code). ' .. role .. ' Caller-saved.')
end
add_register('rip', 64, 'Instruction pointer: address of the next instruction. Not writable directly (jmp / call / ret). `[rel label]` = address relative to rip (position independent code).')

--------------------------------------------------------------------------------
-- System calls (Linux x86-64): rax = number, arguments in rdi rsi rdx r10 r8 r9, result in rax (-errno on error)
--------------------------------------------------------------------------------
-- { name, number, C return type, description, { { type, name, meaning } }, returns, note }
local fd_arg = { 'unsigned int', 'fd', 'file descriptor (0 stdin, 1 stdout, 2 stderr)' }
local path_arg = { 'const char *', 'pathname', 'path, a string ending with 0' }
local mode_arg = { 'umode_t', 'mode', 'permissions in octal, `0o644` / `0o755` in NASM' }
local open_flags = 'flags: O_RDONLY 0, O_WRONLY 1, O_RDWR 2, O_CREAT 0o100, O_EXCL 0o200, O_TRUNC 0o1000, O_APPEND 0o2000, O_NONBLOCK 0o4000, O_DIRECTORY 0o200000, O_CLOEXEC 0o2000000 (OR them)'
local sockaddr_note = 'struct sockaddr_in (16 bytes): `dw 2` (AF_INET), `dw port` in big endian (`xchg al, ah` / `ror ax, 8`), `dd address` (big endian), `dq 0`.'
local syscalls = {
    { 'read', 0, 'ssize_t', 'Reads up to count bytes from a file descriptor.', { fd_arg, { 'char *', 'buf', 'where the bytes are written' }, { 'size_t', 'count', 'size of buf' } },
        'number of bytes read, **0 at the end of the file**', 'Can read less than count (terminal: one line, pipe: what is there).' },
    { 'write', 1, 'ssize_t', 'Writes count bytes to a file descriptor.', { fd_arg, { 'const char *', 'buf', 'address of the bytes' }, { 'size_t', 'count', 'number of bytes' } },
        'number of bytes written (can be less than count)', 'Length of a string of the data section: `len equ $ - msg` right after `msg db "text", 10`.' },
    { 'open', 2, 'int', 'Opens (or creates) a file.', { path_arg, { 'int', 'flags', open_flags }, mode_arg },
        'the new file descriptor', 'mode is only read with O_CREAT. Newer code uses `openat` (AT_FDCWD = -100).' },
    { 'close', 3, 'int', 'Closes a file descriptor.', { fd_arg }, '0' },
    { 'stat', 4, 'int', 'Information about a file (size, mode, dates...).', { path_arg, { 'struct stat *', 'statbuf', 'buffer of 144 bytes' } }, '0',
        'st_size is at offset 48 (qword), st_mode at offset 24 (dword).' },
    { 'fstat', 5, 'int', 'Information about an opened file.', { fd_arg, { 'struct stat *', 'statbuf', 'buffer of 144 bytes' } }, '0', 'st_size at offset 48.' },
    { 'lstat', 6, 'int', 'Like stat, about the link itself (not its target).', { path_arg, { 'struct stat *', 'statbuf', 'buffer of 144 bytes' } }, '0' },
    { 'poll', 7, 'int', 'Waits for an event on file descriptors.', { { 'struct pollfd *', 'fds', 'array of { dd fd, dw events, dw revents }' }, { 'unsigned int', 'nfds', 'number of entries' }, { 'int', 'timeout', 'milliseconds, -1 = forever' } },
        'number of ready descriptors, 0 on timeout', 'POLLIN 1, POLLOUT 4.' },
    { 'lseek', 8, 'off_t', 'Moves the position in a file.', { fd_arg, { 'off_t', 'offset', 'bytes' }, { 'unsigned int', 'whence', 'SEEK_SET 0, SEEK_CUR 1, SEEK_END 2' } },
        'the new position', '`lseek(fd, 0, SEEK_END)` gives the size of the file.' },
    { 'mmap', 9, 'void *', 'Maps memory (allocation or file).', { { 'void *', 'addr', 'wanted address, 0 = the kernel chooses' }, { 'size_t', 'length', 'bytes' },
        { 'int', 'prot', 'PROT_READ 1, PROT_WRITE 2, PROT_EXEC 4 (OR them)' }, { 'int', 'flags', 'MAP_SHARED 1, MAP_PRIVATE 2, MAP_FIXED 0x10, MAP_ANONYMOUS 0x20' },
        { 'int', 'fd', 'file, -1 with MAP_ANONYMOUS' }, { 'off_t', 'offset', 'offset in the file, multiple of 4096' } },
        'the address of the mapping', 'malloc without libc: `mmap(0, size, 3, 0x22, -1, 0)` (read + write, private + anonymous). An error is a value in -4095 to -1: test with `cmp rax, -4095` / `jae .error`.' },
    { 'mprotect', 10, 'int', 'Changes the protection of pages.', { { 'void *', 'addr', 'start, aligned on 4096' }, { 'size_t', 'len', 'bytes' }, { 'int', 'prot', 'PROT_READ 1, PROT_WRITE 2, PROT_EXEC 4' } }, '0' },
    { 'munmap', 11, 'int', 'Frees a mapping made by mmap.', { { 'void *', 'addr', 'address returned by mmap' }, { 'size_t', 'length', 'same length as for mmap' } }, '0' },
    { 'brk', 12, 'unsigned long', 'Moves the end of the heap (program break).', { { 'unsigned long', 'brk', 'new end, 0 = only ask the current one' } },
        'the new break (the old one when it failed: no -errno here)', 'Allocate: `brk(0)` → current end, then `brk(end + size)`.' },
    { 'rt_sigaction', 13, 'int', 'Sets the handler of a signal.', { { 'int', 'sig', 'signal number (SIGINT 2, SIGSEGV 11, SIGTERM 15...)' },
        { 'const struct sigaction *', 'act', 'new action: dq handler, dq flags, dq restorer, dq mask' }, { 'struct sigaction *', 'oact', 'old action, 0 = not wanted' }, { 'size_t', 'sigsetsize', 'always 8' } },
        '0', 'Without libc the flags need SA_RESTORER (0x04000000) and a restorer that calls `rt_sigreturn` (15).' },
    { 'rt_sigprocmask', 14, 'int', 'Blocks / unblocks signals.', { { 'int', 'how', 'SIG_BLOCK 0, SIG_UNBLOCK 1, SIG_SETMASK 2' }, { 'const sigset_t *', 'set', 'mask (qword, bit n-1 = signal n)' },
        { 'sigset_t *', 'oset', 'old mask, 0 = not wanted' }, { 'size_t', 'sigsetsize', 'always 8' } }, '0' },
    { 'ioctl', 16, 'int', 'Device specific request (terminal size...).', { fd_arg, { 'unsigned int', 'cmd', 'request (TIOCGWINSZ 0x5413...)' }, { 'unsigned long', 'arg', 'argument / address' } },
        'depends on the request (often 0)' },
    { 'pread64', 17, 'ssize_t', 'Reads at a position without moving the offset.', { fd_arg, { 'char *', 'buf', 'buffer' }, { 'size_t', 'count', 'size of buf' }, { 'off_t', 'pos', 'position in the file' } }, 'number of bytes read' },
    { 'pwrite64', 18, 'ssize_t', 'Writes at a position without moving the offset.', { fd_arg, { 'const char *', 'buf', 'bytes' }, { 'size_t', 'count', 'number of bytes' }, { 'off_t', 'pos', 'position in the file' } }, 'number of bytes written' },
    { 'readv', 19, 'ssize_t', 'Reads into several buffers.', { fd_arg, { 'const struct iovec *', 'vec', 'array of { dq base, dq len }' }, { 'unsigned long', 'vlen', 'number of entries' } }, 'number of bytes read' },
    { 'writev', 20, 'ssize_t', 'Writes several buffers at once.', { fd_arg, { 'const struct iovec *', 'vec', 'array of { dq base, dq len }' }, { 'unsigned long', 'vlen', 'number of entries' } }, 'number of bytes written' },
    { 'access', 21, 'int', 'Checks if a file exists / can be used.', { path_arg, { 'int', 'mode', 'F_OK 0 (exists), X_OK 1, W_OK 2, R_OK 4' } }, '0 when allowed' },
    { 'pipe', 22, 'int', 'Creates a pipe.', { { 'int *', 'fildes', 'array of 2 dwords: [0] = read end, [1] = write end' } }, '0', 'The fds are dwords (int): read them with `mov edi, [fds]`.' },
    { 'sched_yield', 24, 'int', 'Gives the CPU to another thread.', {}, '0' },
    { 'dup', 32, 'int', 'Duplicates a file descriptor.', { fd_arg }, 'the new descriptor (the lowest free one)' },
    { 'dup2', 33, 'int', 'Duplicates oldfd onto newfd (closes newfd first).', { { 'unsigned int', 'oldfd', 'descriptor to copy' }, { 'unsigned int', 'newfd', 'wanted number (1 to redirect stdout)' } }, 'newfd' },
    { 'pause', 34, 'int', 'Sleeps until a signal arrives.', {}, '-EINTR once a handler ran' },
    { 'nanosleep', 35, 'int', 'Sleeps for a duration.', { { 'const struct timespec *', 'rqtp', 'duration: dq seconds, dq nanoseconds' }, { 'struct timespec *', 'rmtp', 'time left if interrupted, 0 = not wanted' } }, '0',
        'In the data: `delay dq 1, 500000000` = 1.5 s.' },
    { 'getpid', 39, 'pid_t', 'Process id of the caller.', {}, 'the pid (never fails)' },
    { 'sendfile', 40, 'ssize_t', 'Copies between two descriptors inside the kernel.', { { 'int', 'out_fd', 'destination' }, { 'int', 'in_fd', 'source (a file)' }, { 'off_t *', 'offset', 'position to read from, 0 = current' }, { 'size_t', 'count', 'bytes' } }, 'number of bytes copied' },
    { 'socket', 41, 'int', 'Creates a socket.', { { 'int', 'family', 'AF_UNIX 1, AF_INET 2, AF_INET6 10' }, { 'int', 'type', 'SOCK_STREAM 1 (TCP), SOCK_DGRAM 2 (UDP)' }, { 'int', 'protocol', '0 = the default one' } }, 'the socket descriptor' },
    { 'connect', 42, 'int', 'Connects a socket to an address.', { { 'int', 'fd', 'socket' }, { 'struct sockaddr *', 'uservaddr', 'address' }, { 'int', 'addrlen', '16 for sockaddr_in' } }, '0', sockaddr_note },
    { 'accept', 43, 'int', 'Waits for and accepts a connection.', { { 'int', 'fd', 'listening socket' }, { 'struct sockaddr *', 'upeer_sockaddr', 'address of the client, 0 = not wanted' }, { 'int *', 'upeer_addrlen', 'size of that buffer, 0 = not wanted' } }, 'the socket of the client' },
    { 'sendto', 44, 'ssize_t', 'Sends data on a socket.', { { 'int', 'fd', 'socket' }, { 'void *', 'buff', 'data' }, { 'size_t', 'len', 'bytes' }, { 'unsigned int', 'flags', '0' },
        { 'struct sockaddr *', 'addr', 'destination (UDP), 0 when connected' }, { 'int', 'addr_len', 'size of addr, 0 when connected' } }, 'number of bytes sent' },
    { 'recvfrom', 45, 'ssize_t', 'Receives data from a socket.', { { 'int', 'fd', 'socket' }, { 'void *', 'ubuf', 'buffer' }, { 'size_t', 'size', 'size of the buffer' }, { 'unsigned int', 'flags', '0' },
        { 'struct sockaddr *', 'addr', 'sender, 0 = not wanted' }, { 'int *', 'addr_len', '0 = not wanted' } }, 'number of bytes received, 0 = connection closed' },
    { 'shutdown', 48, 'int', 'Closes one direction of a connection.', { { 'int', 'fd', 'socket' }, { 'int', 'how', 'SHUT_RD 0, SHUT_WR 1, SHUT_RDWR 2' } }, '0' },
    { 'bind', 49, 'int', 'Gives an address (port) to a socket.', { { 'int', 'fd', 'socket' }, { 'struct sockaddr *', 'umyaddr', 'address' }, { 'int', 'addrlen', '16 for sockaddr_in' } }, '0', sockaddr_note },
    { 'listen', 50, 'int', 'Marks a socket as accepting connections.', { { 'int', 'fd', 'socket' }, { 'int', 'backlog', 'queue length' } }, '0' },
    { 'socketpair', 53, 'int', 'Two connected sockets.', { { 'int', 'family', 'AF_UNIX 1' }, { 'int', 'type', 'SOCK_STREAM 1' }, { 'int', 'protocol', '0' }, { 'int *', 'usockvec', 'array of 2 dwords' } }, '0' },
    { 'setsockopt', 54, 'int', 'Sets an option of a socket.', { { 'int', 'fd', 'socket' }, { 'int', 'level', 'SOL_SOCKET 1' }, { 'int', 'optname', 'SO_REUSEADDR 2' }, { 'char *', 'optval', 'address of the value (a dword 1)' }, { 'int', 'optlen', '4' } }, '0' },
    { 'clone', 56, 'long', 'Creates a thread / process (low level).', { { 'unsigned long', 'flags', 'CLONE_VM 0x100, CLONE_FS 0x200, CLONE_FILES 0x400, CLONE_THREAD 0x10000... + exit signal' },
        { 'unsigned long', 'newsp', 'stack of the child, 0 = the same' }, { 'int *', 'parent_tidptr', 'or 0' }, { 'int *', 'child_tidptr', 'or 0' }, { 'unsigned long', 'tls', 'or 0' } },
        'the child id in the parent, 0 in the child', 'Note the x86-64 order: child_tid before tls.' },
    { 'fork', 57, 'pid_t', 'Duplicates the process.', {}, '**the pid of the child in the parent, 0 in the child**', 'Then `test rax, rax` / `jz .child` / `js .error`.' },
    { 'vfork', 58, 'pid_t', 'fork that shares the memory until the child calls execve / exit.', {}, 'pid of the child in the parent, 0 in the child' },
    { 'execve', 59, 'int', 'Replaces the process by a program.', { { 'const char *', 'filename', 'path of the program' }, { 'const char *const *', 'argv', 'array of strings ending with 0 (argv[0] = name)' },
        { 'const char *const *', 'envp', 'environment, array ending with 0 (can be 0)' } }, '**does not return** on success, -errno otherwise' },
    { 'exit', 60, 'void', 'Ends the calling thread.', { { 'int', 'error_code', 'exit status (0 = success, 0-255)' } }, '**does not return**',
        'Ends only the calling thread: `exit_group` (231) ends the whole process (what the libc exit does). The stdio buffers of the libc are NOT flushed.' },
    { 'wait4', 61, 'pid_t', 'Waits for a child process.', { { 'pid_t', 'upid', 'child pid, -1 = any child' }, { 'int *', 'stat_addr', 'status (dword), 0 = not wanted' }, { 'int', 'options', '0, WNOHANG 1' }, { 'struct rusage *', 'ru', '0' } },
        'the pid of the child that ended', 'Exit code = (status >> 8) & 0xff.' },
    { 'kill', 62, 'int', 'Sends a signal.', { { 'pid_t', 'pid', 'target process' }, { 'int', 'sig', 'SIGINT 2, SIGKILL 9, SIGTERM 15, 0 = only check it exists' } }, '0' },
    { 'uname', 63, 'int', 'Name and version of the system.', { { 'struct new_utsname *', 'name', 'buffer of 6 * 65 bytes' } }, '0' },
    { 'fcntl', 72, 'int', 'Operation on a file descriptor.', { fd_arg, { 'unsigned int', 'cmd', 'F_DUPFD 0, F_GETFD 1, F_SETFD 2, F_GETFL 3, F_SETFL 4' }, { 'unsigned long', 'arg', 'value of the command' } }, 'depends on cmd' },
    { 'fsync', 74, 'int', 'Writes the data of a file to the disk.', { fd_arg }, '0' },
    { 'truncate', 76, 'int', 'Sets the size of a file.', { path_arg, { 'long', 'length', 'new size' } }, '0' },
    { 'ftruncate', 77, 'int', 'Sets the size of an opened file.', { fd_arg, { 'unsigned long', 'length', 'new size' } }, '0' },
    { 'getcwd', 79, 'int', 'Current directory.', { { 'char *', 'buf', 'buffer' }, { 'unsigned long', 'size', 'size of buf' } }, 'length of the path **with its ending 0** (not a pointer like the libc)' },
    { 'chdir', 80, 'int', 'Changes the current directory.', { { 'const char *', 'filename', 'path' } }, '0' },
    { 'fchdir', 81, 'int', 'Changes the current directory to an opened one.', { fd_arg }, '0' },
    { 'rename', 82, 'int', 'Renames / moves a file.', { { 'const char *', 'oldname', 'old path' }, { 'const char *', 'newname', 'new path' } }, '0' },
    { 'mkdir', 83, 'int', 'Creates a directory.', { path_arg, mode_arg }, '0' },
    { 'rmdir', 84, 'int', 'Removes an empty directory.', { path_arg }, '0' },
    { 'creat', 85, 'int', 'Creates a file (open with O_CREAT | O_WRONLY | O_TRUNC).', { path_arg, mode_arg }, 'the new file descriptor' },
    { 'link', 86, 'int', 'Creates a hard link.', { { 'const char *', 'oldname', 'existing file' }, { 'const char *', 'newname', 'new name' } }, '0' },
    { 'unlink', 87, 'int', 'Removes a file.', { path_arg }, '0' },
    { 'symlink', 88, 'int', 'Creates a symbolic link.', { { 'const char *', 'oldname', 'target' }, { 'const char *', 'newname', 'path of the link' } }, '0' },
    { 'readlink', 89, 'ssize_t', 'Reads the target of a symbolic link.', { path_arg, { 'char *', 'buf', 'buffer' }, { 'int', 'bufsiz', 'size of buf' } }, 'number of bytes written, **no ending 0 added**' },
    { 'chmod', 90, 'int', 'Changes the permissions.', { path_arg, mode_arg }, '0' },
    { 'fchmod', 91, 'int', 'Changes the permissions of an opened file.', { fd_arg, mode_arg }, '0' },
    { 'chown', 92, 'int', 'Changes the owner.', { path_arg, { 'uid_t', 'user', 'user id, -1 = unchanged' }, { 'gid_t', 'group', 'group id, -1 = unchanged' } }, '0' },
    { 'umask', 95, 'int', 'Sets the mask of the permissions of new files.', { { 'int', 'mask', 'bits removed (0o022)' } }, 'the old mask (never fails)' },
    { 'gettimeofday', 96, 'int', 'Current time.', { { 'struct timeval *', 'tv', 'dq seconds, dq microseconds' }, { 'struct timezone *', 'tz', '0' } }, '0' },
    { 'getuid', 102, 'uid_t', 'User id.', {}, 'the uid' },
    { 'getgid', 104, 'gid_t', 'Group id.', {}, 'the gid' },
    { 'geteuid', 107, 'uid_t', 'Effective user id.', {}, 'the euid' },
    { 'getegid', 108, 'gid_t', 'Effective group id.', {}, 'the egid' },
    { 'setpgid', 109, 'int', 'Sets the process group.', { { 'pid_t', 'pid', '0 = itself' }, { 'pid_t', 'pgid', '0 = same as pid' } }, '0' },
    { 'getppid', 110, 'pid_t', 'Pid of the parent.', {}, 'the pid of the parent' },
    { 'setsid', 112, 'pid_t', 'Starts a new session (daemon).', {}, 'the new session id' },
    { 'gettid', 186, 'pid_t', 'Thread id.', {}, 'the tid' },
    { 'time', 201, 'time_t', 'Seconds since 1970-01-01.', { { 'time_t *', 'tloc', 'also stored here, 0 = not wanted' } }, 'the time in seconds' },
    { 'futex', 202, 'long', 'Waits / wakes on an address (locks of threads).', { { 'u32 *', 'uaddr', 'address of the dword' }, { 'int', 'op', 'FUTEX_WAIT 0, FUTEX_WAKE 1 (+ 128 PRIVATE)' },
        { 'u32', 'val', 'expected value / number to wake' }, { 'const struct timespec *', 'utime', 'timeout, 0 = forever' }, { 'u32 *', 'uaddr2', '0' }, { 'u32', 'val3', '0' } }, 'depends on op' },
    { 'getdents64', 217, 'long', 'Reads the entries of a directory.', { fd_arg, { 'struct linux_dirent64 *', 'dirent', 'buffer' }, { 'unsigned int', 'count', 'size of the buffer' } },
        'number of bytes filled, 0 at the end', 'Entry: dq inode, dq offset, dw record length (at +16), db type (+18), name at +19.' },
    { 'clock_gettime', 228, 'int', 'Time of a clock.', { { 'clockid_t', 'which_clock', 'CLOCK_REALTIME 0, CLOCK_MONOTONIC 1' }, { 'struct timespec *', 'tp', 'dq seconds, dq nanoseconds' } }, '0' },
    { 'clock_nanosleep', 230, 'int', 'Sleeps on a clock.', { { 'clockid_t', 'which_clock', 'CLOCK_MONOTONIC 1' }, { 'int', 'flags', '0 = relative, TIMER_ABSTIME 1' },
        { 'const struct timespec *', 'rqtp', 'duration / time' }, { 'struct timespec *', 'rmtp', '0' } }, '0, **or the error as a positive number**' },
    { 'exit_group', 231, 'void', 'Ends the whole process (every thread).', { { 'int', 'error_code', 'exit status (0 = success, 0-255)' } }, '**does not return**', 'What the libc `exit` calls (after flushing stdio).' },
    { 'openat', 257, 'int', 'Opens a file relative to a directory.', { { 'int', 'dfd', 'directory fd, AT_FDCWD = -100 for the current one' }, path_arg, { 'int', 'flags', open_flags }, mode_arg }, 'the new file descriptor' },
    { 'mkdirat', 258, 'int', 'Creates a directory relative to a directory.', { { 'int', 'dfd', 'AT_FDCWD = -100' }, path_arg, mode_arg }, '0' },
    { 'unlinkat', 263, 'int', 'Removes a file / directory relative to a directory.', { { 'int', 'dfd', 'AT_FDCWD = -100' }, path_arg, { 'int', 'flag', '0, AT_REMOVEDIR 0x200 for a directory' } }, '0' },
    { 'dup3', 292, 'int', 'dup2 with flags.', { { 'unsigned int', 'oldfd', 'descriptor to copy' }, { 'unsigned int', 'newfd', 'wanted number' }, { 'int', 'flags', 'O_CLOEXEC 0o2000000' } }, 'newfd' },
    { 'pipe2', 293, 'int', 'pipe with flags.', { { 'int *', 'fildes', 'array of 2 dwords' }, { 'int', 'flags', 'O_NONBLOCK 0o4000, O_CLOEXEC 0o2000000' } }, '0' },
    { 'getrandom', 318, 'ssize_t', 'Random bytes from the kernel.', { { 'char *', 'buf', 'buffer' }, { 'size_t', 'count', 'bytes wanted' }, { 'unsigned int', 'flags', '0, GRND_NONBLOCK 1' } }, 'number of bytes filled' },
    { 'memfd_create', 319, 'int', 'Anonymous file in memory.', { { 'const char *', 'uname', 'name (debug only)' }, { 'unsigned int', 'flags', 'MFD_CLOEXEC 1' } }, 'the file descriptor' },
}
M.syscalls = syscalls

--------------------------------------------------------------------------------
-- Directives (NASM)
--------------------------------------------------------------------------------
-- { name, snippet, doc }
local directives = {
    { 'section', 'section ${1:.text}', 'Starts a section: `.text` (code, read / execute), `.data` (initialized data), `.rodata` (constants), `.bss` (zeroed data, reserved with resb...).' },
    { 'global', 'global ${1:_start}', 'Exports a label to the linker (`_start` without libc, `main` with gcc, the functions of a library).' },
    { 'extern', 'extern ${1:printf}', 'Declares a label defined elsewhere (libc function, other file). Call it with `call printf wrt ..plt` in a PIE.' },
    { 'db', '${1:name} db ${2:"text"}, ${3:10}, 0', 'Defines bytes (1 byte each): numbers, chars, strings. `10` = newline, `0` = end of a C string.' },
    { 'dw', '${1:name} dw ${2:0}', 'Defines words (2 bytes).' },
    { 'dd', '${1:name} dd ${2:0}', 'Defines dwords (4 bytes): int, float (`dd 1.5`).' },
    { 'dq', '${1:name} dq ${2:0}', 'Defines qwords (8 bytes): long, pointer, double (`dq 3.14`).' },
    { 'resb', '${1:buffer} resb ${2:256}', 'Reserves bytes in `.bss` (zeroed at start, no space in the file).' },
    { 'resw', '${1:name} resw ${2:1}', 'Reserves words (2 bytes each) in `.bss`.' },
    { 'resd', '${1:name} resd ${2:1}', 'Reserves dwords (4 bytes each) in `.bss`.' },
    { 'resq', '${1:name} resq ${2:1}', 'Reserves qwords (8 bytes each) in `.bss`.' },
    { 'equ', '${1:NAME} equ ${2:value}', 'Constant (no memory). Length of the data above: `len equ $ - msg`.' },
    { 'times', 'times ${1:count} ${2:db 0}', 'Repeats a line: `times 64 db 0`.' },
    { 'align', 'align ${1:16}', 'Pads up to a multiple of n (data, loops).' },
    { 'default rel', 'default rel', 'Every `[label]` becomes rip-relative: position independent code (PIE, the default of gcc).' },
    { 'bits 64', 'bits 64', 'Generates 64-bit code (the default with `-f elf64`).' },
    { '%define', '%define ${1:NAME} ${2:value}', 'Macro of one line (text replaced before assembling).' },
    { '%macro', '%macro ${1:name} ${2:1}\n\t$0\n%endmacro', 'Macro with arguments: `%1`, `%2`... inside, `%%label` = a label unique to each use.' },
    { '%include', '%include "${1:file.inc}"', 'Inserts another file.' },
    { 'struc', 'struc ${1:name}\n\t.${2:field} resq 1\nendstruc', 'Structure: offsets `name.field`, size `name_size`.' },
    { 'byte', 'byte', 'Size of a memory operand: 1 byte (`mov byte [rdi], 0`).' },
    { 'word', 'word', 'Size of a memory operand: 2 bytes.' },
    { 'dword', 'dword', 'Size of a memory operand: 4 bytes.' },
    { 'qword', 'qword', 'Size of a memory operand: 8 bytes (`inc qword [counter]`).' },
    { 'rel', 'rel', 'rip-relative address: `[rel label]` (position independent).' },
    { 'wrt ..plt', 'wrt ..plt', 'Calls a function of a shared library through the PLT: `call printf wrt ..plt` (PIE).' },
}
local sections = {
    { '.text', 'Code (read + execute).' }, { '.data', 'Initialized data (read + write): db dw dd dq.' },
    { '.rodata', 'Constants (read only): strings, tables.' }, { '.bss', 'Zeroed data (read + write), reserved with resb / resq: no space in the file.' },
}

--------------------------------------------------------------------------------
-- Snippets
--------------------------------------------------------------------------------
-- { label, snippet, doc }
local snippets = {
    { 'prologue', 'push rbp\nmov rbp, rsp\n$0',
        'Start of a function with a stack frame: saves the frame pointer of the caller, rbp = base of the new frame. After `push rbp` rsp is 16-byte aligned again (the `call` pushed 8 bytes). Undo with `epilogue`.' },
    { 'prologue (locals)', 'push rbp\nmov rbp, rsp\nsub rsp, ${1:16}                ; locals, a multiple of 16 (stack aligned)\n$0',
        'Prologue with room for local variables: `[rbp - 8]`, `[rbp - 16]`... Undo with `leave` / `ret`.' },
    { 'epilogue', 'mov rsp, rbp\npop rbp\nret', 'End of a function with a frame: frees the locals, restores rbp of the caller, returns (result in rax).' },
    { 'epilogue (leave)', 'leave\nret', 'Same as `mov rsp, rbp` / `pop rbp` / `ret`, shorter.' },
    { 'function', '${1:name}:\n\tpush rbp\n\tmov rbp, rsp\n\t$0\n\tpop rbp\n\tret', 'Function with its frame (arguments in rdi rsi rdx rcx r8 r9, result in rax).' },
    { 'function (locals)', '${1:name}:\n\tpush rbp\n\tmov rbp, rsp\n\tsub rsp, ${2:16}            ; locals\n\t$0\n\tleave\n\tret',
        'Function with local variables at `[rbp - 8]`... (keep the size a multiple of 16).' },
    { 'function (callee-saved)', '${1:name}:\n\tpush rbp\n\tmov rbp, rsp\n\tpush rbx\n\tpush r12             ; rbp + 2 pushes: rsp stays 16-byte aligned\n\t$0\n\tpop r12\n\tpop rbx\n\tpop rbp\n\tret',
        'Function that uses callee-saved registers (rbx r12-r15 must be given back unchanged). Keep an even number of pushes after `push rbp` to stay aligned for the calls.' },
    { 'save callee-saved', 'push rbx\npush r12\npush r13\npush r14\npush r15\n$0\npop r15\npop r14\npop r13\npop r12\npop rbx',
        'Saves / restores every callee-saved register (5 pushes = 40 bytes: add `sub rsp, 8` before a call to stay aligned).' },
    { 'align stack', 'and rsp, -16', 'Aligns rsp on 16 bytes before a `call` (rsp lowered by 0-15 bytes: keep rbp to restore it).' },
    { 'call (libc)', 'xor eax, eax                ; al = vector registers used (variadic)\ncall ${1:printf} wrt ..plt\n$0',
        'Calls a libc function (PIE): arguments in rdi rsi rdx rcx r8 r9 first. al = 0 for a variadic function without floats.' },
    { 'printf', 'lea rdi, [rel ${1:format}]     ; const char *format\nmov rsi, ${2:value}           ; 1st value\nxor eax, eax                ; no float argument\ncall printf wrt ..plt\n$0',
        'printf with one value. `format db "%d", 10, 0` in `.data`. The stack must be 16-byte aligned at the call.' },
    { 'syscall error check', 'test rax, rax\njs ${1:.error}                  ; rax in -4095 to -1 = -errno\n$0', 'Jumps when the last system call failed (its result is negative).' },
    { '_start', 'section .text\nglobal _start\n\n_start:\n\t$0\n\tmov rax, 60             ; sys_exit\n\txor edi, edi            ; status 0\n\tsyscall',
        'Program without libc (`nasm -f elf64 x.asm && ld x.o`). argc at `[rsp]`, argv at `[rsp + 8]`.' },
    { 'main', 'section .text\nglobal main\n\nmain:\n\tpush rbp\n\tmov rbp, rsp\n\t$0\n\txor eax, eax            ; return 0\n\tpop rbp\n\tret',
        'Entry point with libc (`nasm -f elf64 x.asm && gcc x.o`): argc in edi, argv in rsi.' },
    { 'section .data', 'section .data\n${1:message} db "${2:Hello}", 10\n${3:length} equ $ - ${1:message}', 'Initialized data with the length of a string.' },
    { 'section .bss', 'section .bss\n${1:buffer} resb ${2:256}', 'Zeroed data.' },
    { 'section .rodata', 'section .rodata\n${1:format} db "${2:%d}", 10, 0', 'Constants (a C string for printf).' },
    { 'loop (counter)', 'mov rcx, ${1:count}\n${2:.loop}:\n\t$0\n\tdec rcx\n\tjnz ${2:.loop}', 'Loop counted down in rcx (rcx is destroyed by `call` / `syscall`: use rbx / r12 then).' },
    { 'loop (while)', '${1:.while}:\n\tcmp ${2:rax}, ${3:0}\n\tj${4:e} ${5:.end}               ; leave when the condition is false\n\t$0\n\tjmp ${1:.while}\n${5:.end}:', 'While loop: test at the top.' },
    { 'if else', 'cmp ${1:rax}, ${2:0}\nj${3:ne} ${4:.else}                ; inverse condition\n\t$5\n\tjmp ${6:.end}\n${4:.else}:\n\t$0\n${6:.end}:', 'If / else with labels (jump on the inverse condition).' },
    { 'cmp jmp', 'cmp ${1:rax}, ${2:0}\nj${3:e} ${4:.label}', 'Compare then jump.\n\n**Signed** `jl jle jg jge`, **unsigned** `jb jbe ja jae`, `je jne` for both.' },
    { 'strlen', 'xor ${1:rax}, ${1:rax}\n${2:.strlen}:\n\tcmp byte [${3:rdi} + ${1:rax}], 0\n\tje ${4:.strlen_end}\n\tinc ${1:rax}\n\tjmp ${2:.strlen}\n${4:.strlen_end}:\n$0',
        'Length of the C string at rdi, in rax.' },
    { 'memcpy (rep movsb)', 'mov rdi, ${1:dst}\nmov rsi, ${2:src}\nmov rcx, ${3:count}\ncld\nrep movsb\n$0', 'Copies rcx bytes from rsi to rdi.' },
    { 'memset (rep stosb)', 'mov rdi, ${1:dst}\nmov al, ${2:0}\nmov rcx, ${3:count}\ncld\nrep stosb\n$0', 'Fills rcx bytes at rdi with al.' },
    { 'syscall (any)', 'mov rax, ${1:number}\nmov rdi, ${2:arg1}\nmov rsi, ${3:arg2}\nmov rdx, ${4:arg3}\nsyscall\n$0',
        'System call: number in rax, arguments in rdi rsi rdx **r10** r8 r9, result in rax (-errno on error), rcx and r11 destroyed. Type `sys_` for each call with its arguments.' },
}

--------------------------------------------------------------------------------
-- Documentation (markdown)
--------------------------------------------------------------------------------
local function code(lines) return { '', '```nasm', table.concat(lines, '\n'), '```' } end

local function aligned(text, comment) -- 'mov rax, 1' + 'sys_write' -> 'mov rax, 1              ; sys_write'
    return text .. string.rep(' ', math.max(1, comment_column - #text)) .. '; ' .. comment
end

local function instruction_doc(entry)
    local forms = {}
    for _, form in ipairs(entry.forms) do
        local syntax, effect = form:match('^(.-)%s*;%s*(.*)$')
        table.insert(forms, effect and aligned(syntax, effect) or form)
    end
    local lines = { '**Instruction**  `' .. entry.name .. '`' }
    vim.list_extend(lines, code(forms))
    vim.list_extend(lines, { '', '---', '', entry.desc })
    if entry.ops and #entry.ops > 0 then
        vim.list_extend(lines, { '', '**Operands**' })
        for _, op in ipairs(entry.ops) do table.insert(lines, '- `' .. op[1] .. '` — ' .. op[2]) end
    end
    if entry.res then vim.list_extend(lines, { '', '**Result**  ' .. entry.res }) end
    if entry.imp then vim.list_extend(lines, { '', '**Implicit**  ' .. entry.imp }) end
    if entry.flags then vim.list_extend(lines, { '', '**Flags**  ' .. entry.flags }) end
    if entry.note then vim.list_extend(lines, { '', '**Note**  ' .. entry.note }) end
    if entry.att then vim.list_extend(lines, { '', '**AT&T (GAS)**  `' .. entry.att .. '`' }) end
    return table.concat(lines, '\n')
end

local function syscall_prototype(call)
    local args = {}
    for _, arg in ipairs(call[5]) do table.insert(args, arg[1] .. (arg[1]:sub(-1) == '*' and '' or ' ') .. arg[2]) end
    return call[3] .. (call[3]:sub(-1) == '*' and '' or ' ') .. call[1] .. '(' .. (#args > 0 and table.concat(args, ', ') or 'void') .. ');'
end

local function syscall_doc(call)
    local lines = { '**System call**  `' .. call[1] .. '`  — `rax = ' .. call[2] .. '`', '', '```c', syscall_prototype(call), '```', '', '---', '', call[4] }
    if #call[5] > 0 then
        vim.list_extend(lines, { '', '**Arguments**' })
        for index, arg in ipairs(call[5]) do
            table.insert(lines, '- `' .. syscall_registers[index] .. '` ← `' .. arg[1] .. ' ' .. arg[2] .. '` — ' .. arg[3])
        end
    else
        vim.list_extend(lines, { '', '**Arguments**  none' })
    end
    vim.list_extend(lines, { '', '**Returns** in `rax`  ' .. call[6] .. ' — on error `-errno` (rax in -4095 to -1)',
        '', '**Destroyed**  `rcx`, `r11` (every other register is kept)' })
    if call[7] then vim.list_extend(lines, { '', '**Note**  ' .. call[7] }) end
    return table.concat(lines, '\n')
end

local function syscall_snippet(call)
    local lines = { aligned('mov rax, ' .. call[2], 'sys_' .. call[1]) }
    for index, arg in ipairs(call[5]) do
        local text = 'mov ' .. syscall_registers[index] .. ', ' .. arg[2] -- Width of the line once the default text is in
        local line = 'mov ' .. syscall_registers[index] .. ', ${' .. index .. ':' .. arg[2] .. '}'
        table.insert(lines, line .. string.rep(' ', math.max(1, comment_column - #text)) .. '; ' .. arg[1] .. (arg[1]:sub(-1) == '*' and '' or ' ') .. arg[2])
    end
    table.insert(lines, aligned('syscall', 'rax = ' .. call[6]:gsub('%*', ''):gsub(',.*$', '')))
    return table.concat(lines, '\n') .. '\n$0'
end

local function register_doc(reg)
    local size = reg.size == 128 and '128-bit' or (reg.size .. '-bit')
    return '**Register**  `' .. reg.name .. '`  (' .. size .. ')\n\n---\n\n' .. reg.doc
end

local function snippet_doc(label, body, doc)
    local text = body:gsub('%${%d+:([^}]*)}', '%1'):gsub('%$%d+', ''):gsub('\t', '    ')
    return '**Snippet**  `' .. label .. '`\n\n```nasm\n' .. vim.trim(text) .. '\n```\n\n---\n\n' .. doc
end

--------------------------------------------------------------------------------
-- Items of the completion
--------------------------------------------------------------------------------
local function markdown(value) return { kind = 'markdown', value = value } end

local function instruction_snippet(entry)
    if entry.snip then return entry.snip end
    if not entry.ops or #entry.ops == 0 then return entry.name end
    local args = {}
    for index, op in ipairs(entry.ops) do
        if index > 3 or (entry.name == 'imul' and index > 2) then break end
        table.insert(args, '${' .. index .. ':' .. op[1]:gsub('[%[%]%.]', '') .. '}')
    end
    return entry.name .. ' ' .. table.concat(args, ', ')
end

local cache = {}

-- context: 'mnemonic' (first word of a line), 'operand', 'section' (after 'section'), 'rax' (after 'mov rax,')
function M.items(context, kinds)
    if cache[context] then return cache[context] end
    local items = {}
    local function add(item) table.insert(items, item) end

    if context == 'mnemonic' then
        for _, entry in ipairs(instructions) do
            add({ label = entry.name, kind = kinds.Keyword, insertText = instruction_snippet(entry), insertTextFormat = 2,
                documentation = markdown(instruction_doc(entry)), data = { tag = 'ins', word = entry.name } })
        end
        for _, call in ipairs(syscalls) do
            add({ label = 'sys_' .. call[1], kind = kinds.Function, insertText = syscall_snippet(call), insertTextFormat = 2,
                documentation = markdown(syscall_doc(call)), data = { tag = 'sys', word = 'sys_' .. call[1] }, detail = 'rax = ' .. call[2] })
        end
        for _, snippet in ipairs(snippets) do
            add({ label = snippet[1], kind = kinds.Snippet, insertText = snippet[2], insertTextFormat = 2,
                documentation = markdown(snippet_doc(snippet[1], snippet[2], snippet[3])), data = { tag = 'snip', word = snippet[1] } })
        end
        for _, directive in ipairs(directives) do
            add({ label = directive[1], kind = kinds.Module, insertText = directive[2], insertTextFormat = 2,
                documentation = markdown('**Directive**  `' .. directive[1] .. '`\n\n---\n\n' .. directive[3]), data = { tag = 'dir', word = directive[1] } })
        end
    elseif context == 'section' then
        for _, section in ipairs(sections) do
            add({ label = section[1], kind = kinds.Module, documentation = markdown('**Section**  `' .. section[1] .. '`\n\n---\n\n' .. section[2]), data = { tag = 'dir', word = section[1] } })
        end
    else
        if context == 'rax' then -- 'mov rax, ' : the number of a system call
            for _, call in ipairs(syscalls) do
                add({ label = call[2] .. ' sys_' .. call[1], match = 'sys_' .. call[1] .. ' ' .. call[2], kind = kinds.Constant,
                    insertText = tostring(call[2]) .. '                  ; sys_' .. call[1], documentation = markdown(syscall_doc(call)), data = { tag = 'sys', word = 'sys_' .. call[1] } })
            end
            cache[context] = items
            return items
        end
        for _, name in ipairs(register_order) do
            add({ label = name, kind = kinds.Variable, documentation = markdown(register_doc(registers[name])), data = { tag = 'reg', word = name } })
        end
        for _, directive in ipairs(directives) do
            if directive[2] == directive[1] then -- Size keywords, rel, wrt ..plt
                add({ label = directive[1], kind = kinds.Keyword, documentation = markdown('**Keyword**  `' .. directive[1] .. '`\n\n---\n\n' .. directive[3]), data = { tag = 'dir', word = directive[1] } })
            end
        end
    end
    cache[context] = items
    return items
end

--------------------------------------------------------------------------------
-- Labels of the buffer (call / jmp targets), with the ';' comments written above them
--------------------------------------------------------------------------------
local label_cache = {}

function M.labels(buf)
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local cached = label_cache[buf]
    if cached and cached.tick == tick then return cached.labels end
    local labels, seen = {}, {}
    local lines = vim.api.nvim_buf_get_lines(buf, 0, 20000, false)
    for row, line in ipairs(lines) do
        local name = line:match('^%s*([%a_.$?@][%w_.$?@]*):') or line:match('^%s*global%s+([%w_.]+)') or line:match('^%s*extern%s+([%w_.]+)')
            or line:match('^%s*([%a_][%w_]*)%s+equ%s') or line:match('^%s*([%a_][%w_]*)%s+d[bwdq]%s')
            or line:match('^%s*([%a_][%w_]*)%s+res[bwdq]%s') or line:match('^%s*([%a_][%w_]*)%s+times%s')
        if name and not registers[name] and not seen[name] then
            seen[name] = true
            local comments = {}
            local above = row - 1
            while above >= 1 and lines[above]:match('^%s*;') do
                table.insert(comments, 1, (lines[above]:gsub('^%s*;+%s?', '')))
                above = above - 1
            end
            local trailing = line:match(';%s*(.*)$')
            if trailing then table.insert(comments, trailing) end
            table.insert(labels, { name = name, row = row, text = vim.trim(line), doc = table.concat(comments, '\n') })
        end
    end
    label_cache[buf] = { tick = tick, labels = labels }
    return labels
end

local function label_doc(label)
    local text = '**Label**  `' .. label.name .. '`  *line ' .. label.row .. '*\n\n```nasm\n' .. label.text .. '\n```'
    if label.doc ~= '' then text = text .. '\n\n---\n\n' .. label.doc end
    return text
end

function M.label_items(buf, kinds)
    local items = {}
    for _, label in ipairs(M.labels(buf)) do
        table.insert(items, { label = label.name, kind = kinds.Reference, documentation = markdown(label_doc(label)), data = { tag = 'lbl', word = label.name } })
    end
    return items
end

--------------------------------------------------------------------------------
-- Help of a word (hover / K)
--------------------------------------------------------------------------------
local by_name = nil

local function index_names()
    by_name = {}
    for _, entry in ipairs(instructions) do by_name[entry.name] = by_name[entry.name] or instruction_doc(entry) end
    for _, call in ipairs(syscalls) do by_name['sys_' .. call[1]] = syscall_doc(call) end
    for name, reg in pairs(registers) do by_name[name] = register_doc(reg) end
    for _, directive in ipairs(directives) do
        by_name[directive[1]] = by_name[directive[1]] or ('**Directive**  `' .. directive[1] .. '`\n\n---\n\n' .. directive[3])
    end
    for _, section in ipairs(sections) do by_name[section[1]] = '**Section**  `' .. section[1] .. '`\n\n---\n\n' .. section[2] end
end

-- The number put in rax / eax above a 'syscall' (looked for up to 15 lines above, until a label or another syscall)
local function syscall_above(buf, row)
    local first = math.max(0, row - 16)
    local lines = vim.api.nvim_buf_get_lines(buf, first, row - 1, false)
    for index = #lines, 1, -1 do
        local line = lines[index]:gsub(';.*$', '')
        if line:match('^%s*syscall') or line:match('^%s*[%w_.]+:') then return end
        local value = line:match('^%s*mov%s+[re]?ax%s*,%s*(%w+)') or line:match('^%s*xor%s+[re]?ax%s*,%s*[re]?ax')
        if value then
            local number = tonumber(value) or (line:match('xor') and 0)
            for _, call in ipairs(syscalls) do
                if call[2] == number then return call end
            end
            return
        end
    end
end

-- Markdown help of the word at (row: 1-based line) of buf, nil when unknown
function M.help(buf, word, row)
    if not by_name then index_names() end
    local lower = word:lower()
    if lower == 'syscall' and row then
        local call = syscall_above(buf, row)
        if call then return syscall_doc(call) .. '\n\n---\n\n' .. by_name.syscall end
    end
    if by_name[lower] then return by_name[lower] end
    for _, label in ipairs(M.labels(buf)) do
        if label.name == word then return label_doc(label) end
    end
end

return M
