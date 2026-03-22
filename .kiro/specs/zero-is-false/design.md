# Design Document: zero-is-false

## Overview

This feature modifies LuaJIT so that numeric zero (`0`, `0.0`, `-0.0`) is treated as falsy in all boolean contexts, matching the convention of C, Python, JavaScript, and many other languages. Standard Lua treats every number as truthy; this is a deliberate, breaking semantic change scoped to this fork.

The change is implemented in four ordered phases, each gated by a full test-suite pass:

| Phase | Build script | Scope |
|-------|-------------|-------|
| 1 | `w64build_amalg_32bit_nojit.bat` | 32-bit interpreter only |
| 2 | `w64build_amalg_32bit.bat` | 32-bit interpreter + JIT |
| 3 | `w64build_amalg_64bit_nojit.bat` | 64-bit interpreter only |
| 4 | `w64build_amalg_64bit.bat` | 64-bit interpreter + JIT |

---

## Architecture

LuaJIT evaluates boolean conditions through two distinct execution paths that must both be updated:

1. **Bytecode interpreter** (`src/vm_x86.dasc`) — handles all execution when JIT is disabled or a trace has not yet been compiled. Truthiness is tested inline in the IST/ISFC/ISTC/ISF/NOT bytecode handlers using the `LJ_TISTRUECOND` constant.

2. **JIT compiler** — two sub-components:
   - **Trace recorder** (`src/lj_record.c`) — records bytecode into SSA IR; uses `tref_istruecond()` to decide the IR type of a boolean result.
   - **Code generator** (`src/lj_asm_x86.h`) — lowers IR to native x86/x64 machine code.

The single source-of-truth for the truthiness rule in C code is the `tvistruecond(o)` macro in `src/lj_obj.h`. The interpreter's assembly code mirrors this rule using the `LJ_TISTRUECOND` constant directly.

### Execution flow for a conditional

```
Lua source: if x then ... end
     |
     v
Bytecode: IST / ISFC (test + conditional branch)
     |
     +--[interpreter]--> vm_x86.dasc: cmp [BASE+RD*8+4], LJ_TISTRUECOND
     |                                jae/jb (branch or fall-through)
     |
     +--[JIT recorder]--> lj_record.c: tref_istruecond(rc) -> emit guard IR
     |
     +--[JIT codegen]---> lj_asm_x86.h: emit CMP/JCC for the guard
```

---

## Components and Interfaces

### 1. `src/lj_obj.h` — Truthiness macro (shared by all phases)

**Current state:**
```c
#define LJ_TISTRUECOND   LJ_TFALSE   /* (~1u) */
#define tvistruecond(o)  (itype(o) < LJ_TISTRUECOND)
```

`itype(o)` returns the internal tag of a `TValue`. Numbers (both integer and double) have tags `<= LJ_TISNUM` which is `<= LJ_TNUMX (~13u)`, far below `LJ_TFALSE (~1u)`. So currently all numbers are truthy.

**Required change:** `tvistruecond` must return false when the value is a numeric zero. The existing `tviszero` macro already handles all three zero cases:

```c
/* 64-bit: */  #define tviszero(o)  (((o)->u64 << 1) == 0)
/* 32-bit: */  #define tviszero(o)  (((o)->u32.lo | ((o)->u32.hi << 1)) == 0)
```

New definition:
```c
#define tvistruecond(o)  (itype(o) < LJ_TISTRUECOND && \
                          !(tvisnumber(o) && tviszero(o)))
```

This change propagates automatically to all C-level callers of `tvistruecond`, including the JIT recorder's `tref_istruecond` path (which calls back into C for constant folding) and the post-processing hooks in `lj_record.c`.

### 2. `src/vm_x86.dasc` — Interpreter bytecode handlers (Phases 1 & 3)

The interpreter does **not** call `tvistruecond` at runtime; it replicates the logic in assembly. The relevant handlers are:

**IST / ISFC / ISTC / ISF** (lines ~3797–3817):
```asm
mov  RB, [BASE+RD*8+4]   ; load type tag of operand
add  PC, 4
cmp  RB, LJ_TISTRUECOND  ; compare tag against threshold
jae/jb >1                ; branch if false/true
```

**BC_NOT** (lines ~3845–3852):
```asm
xor  RB, RB
checktp RD, LJ_TISTRUECOND
adc  RB, LJ_TTRUE
mov  [BASE+RA*8+4], RB
```

Both handlers use only the type tag. They do not inspect the value bits, so they cannot detect numeric zero by tag alone.

**Required change:** After the tag check passes (value is a number), add a secondary check for zero. For the IST/ISTC case (branch if true), a number that is zero must fall through instead of branching. For ISF/ISFC (branch if false), a number that is zero must branch.

The zero check for 32-bit uses the existing `tviszero` logic:
- Integer zero: `[BASE+RD*8+4] == LJ_TISNUM && [BASE+RD*8] == 0`
- Double ±0.0: `([BASE+RD*8] | ([BASE+RD*8+4] << 1)) == 0`

For 64-bit (x64), the full 8-byte slot can be tested: `(slot << 1) == 0`.

The assembly patch inserts a conditional branch after the tag check to handle the number-is-zero case, redirecting to the opposite outcome from what the tag check alone would produce.

### 3. `src/lj_record.c` — JIT trace recorder (Phases 2 & 4)

The recorder handles `BC_ISTC`, `BC_ISFC`, `BC_IST`, `BC_ISF`, and `BC_NOT` at lines ~2424–2450. It uses `tref_istruecond(rc)` to determine the IR type of the boolean result.

`tref_istruecond` in `lj_ir.h`:
```c
#define tref_istruecond(tr)  (!tref_typerange((tr), IRT_NIL, IRT_FALSE))
```

This checks the IR type, not the runtime value. Numbers have IR type `IRT_NUM` or `IRT_INT`, which are outside `[IRT_NIL, IRT_FALSE]`, so they are always considered truthy by the recorder.

**Required change:** When recording a boolean test on a number-typed TRef, the recorder must emit a guard that checks whether the runtime value is zero. If the value is zero, the guard fails and the trace exits to the interpreter (which handles the zero-is-false case correctly after Phase 1).

Concretely, for `BC_IST`/`BC_ISTC` when `rc` has a number type:
- Emit `IR_NE(rc, zero_constant)` as a guard (assert non-zero to stay on the true branch)
- If the guard fails at runtime (value is zero), the trace exits and the interpreter takes the false branch

For `BC_ISF`/`BC_ISFC` when `rc` has a number type:
- Emit `IR_EQ(rc, zero_constant)` as a guard (assert zero to stay on the false branch)

For `BC_NOT` when `rc` has a number type:
- The result is `TREF_TRUE` if zero, `TREF_FALSE` if non-zero
- Emit a guard and specialize the result accordingly

The zero constant for integers is `lj_ir_kint(J, 0)`; for doubles, `lj_ir_knum_zero(J)`. Mixed int/num cases require a conversion.

### 4. Build scripts (all phases)

Four `.bat` files in `src/`:

| Script | Flags |
|--------|-------|
| `w64build_amalg_32bit_nojit.bat` | `-m32`, `LUAJIT_DISABLE_GC64`, `XCFLAGS=-DLUAJIT_DISABLE_JIT` |
| `w64build_amalg_32bit.bat` | `-m32`, `LUAJIT_DISABLE_GC64` |
| `w64build_amalg_64bit_nojit.bat` | no `-m32`, no `LUAJIT_DISABLE_GC64`, `XCFLAGS=-DLUAJIT_DISABLE_JIT` |
| `w64build_amalg_64bit.bat` | no `-m32`, no `LUAJIT_DISABLE_GC64` |

The 64-bit scripts prepend `D:\hiperbou\w64devkit\w64devkit\bin` to `PATH`. All scripts call `mingw32-make clean && mingw32-make amalg`, print a success/failure banner, and exit with a non-zero code on failure.

---

## Data Models

### TValue layout (32-bit, non-GC64)

```
 63          32 31           0
 [  itype (it) | value (lo)  ]
```

- `itype` for integer: `LJ_TISNUM` = `~13u` = `0xFFFFFFF2`
- `itype` for double: any value `< LJ_TISNUM` (the double's upper 32 bits)
- Integer zero: `it == LJ_TISNUM && lo == 0`
- Double +0.0: `it == 0x00000000 && lo == 0x00000000`
- Double -0.0: `it == 0x80000000 && lo == 0x00000000`

The `tviszero` macro covers all three:
```c
/* 32-bit */ ((lo) | ((it) << 1)) == 0
```
- Integer 0: `0 | (LJ_TISNUM << 1)` — this is non-zero! The 32-bit `tviszero` actually checks `(lo | (hi << 1)) == 0`, where `hi` is the upper 32 bits of the double representation. For an integer, `hi = LJ_TISNUM` which is non-zero, so the macro returns false for integers in 32-bit mode.

**Important:** In 32-bit `LJ_DUALNUM` mode, integer zero has `itype == LJ_TISNUM` (non-zero upper bits), so `tviszero` returns false for it. The zero check for integers must be done separately: `tvisint(o) && intV(o) == 0`.

The combined check for "is numeric zero":
```c
#define tvisnumzero(o) \
  (tvisint(o) ? (intV(o) == 0) : (tvisnum(o) && tviszero(o)))
```

### TValue layout (64-bit, GC64)

```
 63    47 46  43 42                0
 [1..1 | itype | payload (47 bits) ]
```

For 64-bit, `tviszero` uses `((o)->u64 << 1) == 0`, which correctly identifies both `+0.0` (all bits zero) and `-0.0` (only sign bit set, shifted out). Integer zero in GC64 mode has the integer tag in the upper bits, so the same separate check applies.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Zero values are falsy

*For any* numeric value that is zero (integer `0`, double `0.0`, or double `-0.0`), evaluating it in a boolean context (`if`, `while`, `and`, `or`, `not`) SHALL cause the system to treat it as false.

**Validates: Requirements 1.1, 1.2, 1.3, 2.1, 3b.1, 3.1, 6.4, 6.5**

### Property 2: Non-zero numbers are truthy

*For any* numeric value `x` where `x ~= 0` (and `x` is not NaN), evaluating it in a boolean context SHALL cause the system to treat it as true.

**Validates: Requirements 1.4, 2.2, 3b.2, 3.2, 1.13**

### Property 3: Nil and false remain falsy

*For any* value that is `nil` or `false`, evaluating it in a boolean context SHALL cause the system to treat it as false, unchanged from standard Lua semantics.

**Validates: Requirements 1.12**

### Property 4: Not-consistency (triple negation)

*For any* numeric value `x`, the expression `(not x) == (not (not (not x)))` SHALL hold. Equivalently, `not` applied once is equivalent to `not` applied three times — triple negation is the same as single negation.

**Validates: Requirements 6.2, 1.5, 1.6, 1.7**

### Property 5: And/or short-circuit consistency

*For any* numeric value `x` and any value `y`, the expression `(x and true or false) == (not (not x))` SHALL hold. This verifies that `and`/`or` short-circuit behavior is consistent with the `not` operator's view of truthiness.

**Validates: Requirements 1.8, 1.9, 1.10, 1.11, 2.4, 3.4, 6.3**

### Property 6: Interpreter/JIT consistency

*For any* numeric value `x`, the boolean result of `if x then` SHALL be identical whether the code is executed by the interpreter or by JIT-compiled code. No numeric value may produce a different truthiness result depending on execution mode.

**Validates: Requirements 2.5, 3.5, 6.1**

---

## Error Handling

### Trace exits on zero-falsy guard

When the JIT recorder emits a guard for a number-typed boolean test (e.g., `IR_NE(rc, 0)` for a true-branch), and the runtime value is zero, the guard fails. LuaJIT's standard trace exit mechanism fires: the JIT exits to the interpreter at the snapshot corresponding to the guard, and the interpreter continues execution with the correct zero-is-false semantics (already implemented in Phase 1).

This is the expected and correct behavior. No special error handling is needed; the trace exit is a normal optimization boundary.

### NaN handling

NaN is not zero (`tviszero` returns false for NaN because `NaN != 0.0` and the bit pattern is non-zero). NaN remains truthy, consistent with standard Lua. The `tviszero` macro correctly excludes NaN.

### Integer overflow in zero check

The `tviszero` macro for 32-bit uses bitwise operations that are well-defined for all integer and double bit patterns. No overflow or undefined behavior is possible.

### Build failures

Each build script checks `errorlevel` after `mingw32-make` and prints a clear failure banner before exiting with code 1. This ensures CI or manual runs can detect build failures immediately.

---

## Testing Strategy

### Dual testing approach

Both unit/example tests and property-based tests are used. The existing test files in `test/` serve as the example/integration tests. Property-based tests verify universal correctness across all numeric inputs.

### Unit / example tests (existing)

The four test files in `test/` are run individually as a gate at the end of each phase:

- `test/test_zero.lua` — basic zero truthiness, `not`, `and`, `or`
- `test/test_truthiness.lua` — comprehensive truthiness table including nil, false, strings, tables
- `test/test_zero_extra.lua` — JIT loop stress test, short-circuit patterns
- `test/test_patterns.lua` — real-world patterns: inheritance, table indexing, nested logicals

Each file is run as a separate `luajit.exe` invocation. All four must pass before advancing to the next phase.

### Property-based tests

Property-based testing is done using a Lua property-testing library. Since LuaJIT does not ship with a PBT framework, a minimal inline generator is used in a dedicated test file `test/test_properties.lua`. Each property runs at least 100 random inputs.

**Property test configuration:**
- Minimum 100 iterations per property
- Each test is tagged with a comment: `-- Feature: zero-is-false, Property N: <text>`
- Integer inputs: random integers including 0, positive, negative
- Float inputs: random doubles including 0.0, -0.0, subnormals, large values, NaN (excluded from zero-falsy check)

**Property 1 test** — `-- Feature: zero-is-false, Property 1: Zero values are falsy`
```lua
-- For each of: 0 (int), 0.0, -0.0
-- assert: if val then false else true end  =>  true
local zeros = {0, 0.0, -0.0}
for _, z in ipairs(zeros) do
  assert(not z, "zero should be falsy: " .. tostring(z))
end
```

**Property 2 test** — `-- Feature: zero-is-false, Property 2: Non-zero numbers are truthy`
```lua
-- For 100 random non-zero numbers
for i = 1, 100 do
  local x = math.random() * 1e10 + 1  -- guaranteed non-zero
  assert(x, "non-zero number should be truthy: " .. tostring(x))
end
```

**Property 4 test** — `-- Feature: zero-is-false, Property 4: Not-consistency (triple negation)`
```lua
-- For 100 random numbers including zero
for _, x in ipairs(test_numbers) do
  assert((not x) == (not (not (not x))),
    "triple negation failed for: " .. tostring(x))
end
```

**Property 5 test** — `-- Feature: zero-is-false, Property 5: And/or short-circuit consistency`
```lua
for _, x in ipairs(test_numbers) do
  assert((x and true or false) == (not (not x)),
    "and/or/not consistency failed for: " .. tostring(x))
end
```

**Property 6 test** — `-- Feature: zero-is-false, Property 6: Interpreter/JIT consistency`
```lua
-- Run the same boolean tests in a hot loop (triggers JIT) and compare
-- results against a pre-computed interpreter baseline
local function bool_result(x) if x then return true else return false end end
local baseline = {}
for _, x in ipairs(test_numbers) do baseline[x] = bool_result(x) end
-- Force JIT compilation
for i = 1, 200 do
  for _, x in ipairs(test_numbers) do
    assert(bool_result(x) == baseline[x],
      "JIT/interpreter mismatch for: " .. tostring(x))
  end
end
```

### Phase-by-phase test execution

```
Phase 1 (32-bit no-JIT):
  w64build_amalg_32bit_nojit.bat
  luajit.exe test/test_zero.lua
  luajit.exe test/test_truthiness.lua
  luajit.exe test/test_zero_extra.lua
  luajit.exe test/test_patterns.lua

Phase 2 (32-bit JIT):
  w64build_amalg_32bit.bat
  [same 4 test files]

Phase 3 (64-bit no-JIT):
  w64build_amalg_64bit_nojit.bat
  [same 4 test files]

Phase 4 (64-bit JIT):
  w64build_amalg_64bit.bat
  [same 4 test files]
```

All four files must pass before advancing to the next phase.
