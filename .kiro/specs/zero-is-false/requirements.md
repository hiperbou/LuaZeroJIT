# Requirements Document

## Introduction

This feature modifies LuaJIT so that the integer and floating-point number zero (`0`, `0.0`, `-0.0`) evaluates as falsy in boolean contexts, matching the behavior of many other languages (C, Python, JavaScript, etc.). Standard Lua treats all numbers as truthy; this is a deliberate, breaking semantic change scoped to this fork.

The implementation is phased in strict order, with all 4 test files in `test/` run individually as a gate before advancing to the next phase:

- Phase 1: 32-bit, JIT disabled (`src/w64build_amalg_32bit_nojit.bat`) — modify the C/assembly interpreter; all tests must pass before Phase 2.
- Phase 2: 32-bit, JIT enabled (`src/w64build_amalg_32bit.bat`) — extend the change into the 32-bit JIT; all tests must pass before Phase 3.
- Phase 3: 64-bit, JIT disabled (`src/w64build_amalg_64bit_nojit.bat`) — verify interpreter correctness on x86-64; all tests must pass before Phase 4.
- Phase 4: 64-bit, JIT enabled (`src/w64build_amalg_64bit.bat`) — extend the change to the 64-bit JIT path; all tests must pass to complete the feature.

## Glossary

- **Interpreter**: The LuaJIT bytecode interpreter, implemented in `src/vm_x86.dasc` and driven by C code in `src/lj_vm.h` and related files.
- **JIT**: The Just-In-Time compiler component of LuaJIT that compiles hot Lua traces to native machine code.
- **Truthy**: A value that causes a conditional branch to be taken (i.e., `if val then` executes the body).
- **Falsy**: A value that causes a conditional branch NOT to be taken.
- **Boolean context**: Any place where a value is tested for truth: `if`, `while`, `repeat/until`, `and`, `or`, `not`, ternary-style `a and b or c`.
- **tvistruecond**: The C macro in `src/lj_obj.h` that determines whether a `TValue` is truthy. Currently defined as `(itype(o) < LJ_TISTRUECOND)` where `LJ_TISTRUECOND == LJ_TFALSE`.
- **LJ_TISTRUECOND**: The type-tag threshold constant used by `tvistruecond`. Values with `itype < LJ_TISTRUECOND` are truthy.
- **ISTC / ISFC / IST / ISF**: LuaJIT bytecode instructions that test a value for truth/falsity and optionally copy it.
- **BC_NOT**: LuaJIT bytecode instruction that applies logical negation.
- **Zero**: The numeric value `0` (integer), `0.0` (double), or `-0.0` (negative zero double). All three must be treated as falsy.
- **Non-zero number**: Any number value that is not zero; must remain truthy.
- **32-bit build**: A LuaJIT build compiled with `CC="gcc -m32"` and `LUAJIT_DISABLE_GC64`, using `src/w64build_amalg_32bit.bat`.
- **32-bit no-JIT build**: A LuaJIT build compiled with `CC="gcc -m32"`, `LUAJIT_DISABLE_GC64`, and `LUAJIT_DISABLE_JIT`, using `src/w64build_amalg_32bit_nojit.bat`. Used for interpreter-only testing.
- **64-bit build**: A LuaJIT build compiled for x86-64, using a new `src/w64build_amalg_64bit.bat` that prepends `D:\hiperbou\w64devkit\w64devkit\bin` to `PATH`.
- **64-bit no-JIT build**: A LuaJIT build compiled for x86-64 with `XCFLAGS=-DLUAJIT_DISABLE_JIT` (no `-m32`, no `LUAJIT_DISABLE_GC64`), using `src/w64build_amalg_64bit_nojit.bat`. Used for interpreter-only testing on 64-bit.
- **tviszero**: Existing macro in `src/lj_obj.h` that tests whether a `TValue` holds a numeric zero (integer 0 or double ±0.0).
- **tvisint**: Macro that returns true when a `TValue` holds a dual-number integer (`LJ_DUALNUM` mode).
- **tvisnumber**: Macro that returns true when a `TValue` holds any number (integer or double).

---

## Requirements

### Requirement 1: Zero is Falsy in the Interpreter (Phase 1 — 32-bit, JIT disabled)

**User Story:** As a developer using this LuaJIT fork, I want integer and float zero to evaluate as false in boolean contexts in the interpreter, so that I can write idiomatic zero-checks without explicit `== 0` comparisons.

> Phase gate: build with `src/w64build_amalg_32bit_nojit.bat`. All 4 test files must pass individually before proceeding to Phase 2.

#### Acceptance Criteria

1. WHEN the Interpreter evaluates `if 0 then` or `if 0.0 then` or `if -0.0 then`, THE Interpreter SHALL take the false branch.
2. WHEN the Interpreter evaluates `if x then` where `x` holds the integer value `0`, THE Interpreter SHALL take the false branch.
3. WHEN the Interpreter evaluates `if x then` where `x` holds the double value `0.0` or `-0.0`, THE Interpreter SHALL take the false branch.
4. WHEN the Interpreter evaluates `if x then` where `x` holds any non-zero number, THE Interpreter SHALL take the true branch.
5. WHEN the Interpreter evaluates `not 0`, THE Interpreter SHALL return `true`.
6. WHEN the Interpreter evaluates `not 0.0`, THE Interpreter SHALL return `true`.
7. WHEN the Interpreter evaluates `not x` where `x` is a non-zero number, THE Interpreter SHALL return `false`.
8. WHEN the Interpreter evaluates `0 and expr`, THE Interpreter SHALL return `0` without evaluating `expr`.
9. WHEN the Interpreter evaluates `0 or expr`, THE Interpreter SHALL evaluate and return `expr`.
10. WHEN the Interpreter evaluates `1 and expr`, THE Interpreter SHALL evaluate and return `expr`.
11. WHEN the Interpreter evaluates `1 or expr`, THE Interpreter SHALL return `1` without evaluating `expr`.
12. THE Interpreter SHALL continue to treat `nil` and `false` as falsy.
13. THE Interpreter SHALL continue to treat non-zero numbers, strings, tables, functions, userdata, and threads as truthy.
14. WHEN the Phase 1 build (`src/w64build_amalg_32bit_nojit.bat`) is complete, THE System SHALL pass `test/test_zero.lua`, `test/test_truthiness.lua`, `test/test_zero_extra.lua`, and `test/test_patterns.lua` each as a separate `luajit.exe` invocation before Phase 2 begins.

### Requirement 2: Zero is Falsy in the 32-bit JIT (Phase 2 — 32-bit, JIT enabled)

**User Story:** As a developer using this LuaJIT fork, I want zero to evaluate as false in JIT-compiled code on 32-bit x86, so that the behavior is consistent between interpreted and compiled execution.

> Phase gate: build with `src/w64build_amalg_32bit.bat`. All 4 test files must pass individually before proceeding to Phase 3.

#### Acceptance Criteria

1. WHEN the 32-bit JIT compiles a boolean test on a value that is zero at runtime, THE JIT SHALL generate code that takes the false branch.
2. WHEN the 32-bit JIT compiles a boolean test on a value that is a non-zero number at runtime, THE JIT SHALL generate code that takes the true branch.
3. WHEN the 32-bit JIT compiles a `not` operation on zero, THE JIT SHALL generate code that produces `true`.
4. WHEN the 32-bit JIT compiles short-circuit `and`/`or` expressions involving zero, THE JIT SHALL generate code consistent with zero being falsy.
5. WHILE JIT compilation is active, THE System SHALL produce results identical to the Interpreter for all boolean contexts involving zero.
6. IF a JIT trace exits due to a zero-falsy guard, THE System SHALL fall back to the Interpreter and continue execution correctly.
7. WHEN the Phase 2 build (`src/w64build_amalg_32bit.bat`) is complete, THE System SHALL pass `test/test_zero.lua`, `test/test_truthiness.lua`, `test/test_zero_extra.lua`, and `test/test_patterns.lua` each as a separate `luajit.exe` invocation before Phase 3 begins.

### Requirement 3b: Zero is Falsy in the 64-bit Interpreter (Phase 3 — 64-bit, JIT disabled)

**User Story:** As a developer using this LuaJIT fork, I want zero to evaluate as false in the interpreter on 64-bit x86-64, so that the interpreter-only behavior is verified on the 64-bit target before enabling the 64-bit JIT.

> Phase gate: build with `src/w64build_amalg_64bit_nojit.bat`. All 4 test files must pass individually before proceeding to Phase 4.

#### Acceptance Criteria

1. WHEN the 64-bit no-JIT build is used, THE Interpreter SHALL treat `0`, `0.0`, and `-0.0` as falsy in all boolean contexts.
2. WHEN the 64-bit no-JIT build is used, THE Interpreter SHALL treat non-zero numbers as truthy.
3. WHEN the Phase 3 build (`src/w64build_amalg_64bit_nojit.bat`) is complete, THE System SHALL pass `test/test_zero.lua`, `test/test_truthiness.lua`, `test/test_zero_extra.lua`, and `test/test_patterns.lua` each as a separate `luajit.exe` invocation before Phase 4 begins.

### Requirement 3: Zero is Falsy in the 64-bit JIT (Phase 4 — 64-bit, JIT enabled)

**User Story:** As a developer using this LuaJIT fork, I want zero to evaluate as false in JIT-compiled code on 64-bit x86-64, so that the behavior is consistent across all execution modes.

> Phase gate: build with `src/w64build_amalg_64bit.bat`. All 4 test files must pass individually to complete the feature.

#### Acceptance Criteria

1. WHEN the 64-bit JIT compiles a boolean test on a value that is zero at runtime, THE JIT SHALL generate code that takes the false branch.
2. WHEN the 64-bit JIT compiles a boolean test on a value that is a non-zero number at runtime, THE JIT SHALL generate code that takes the true branch.
3. WHEN the 64-bit JIT compiles a `not` operation on zero, THE JIT SHALL generate code that produces `true`.
4. WHEN the 64-bit JIT compiles short-circuit `and`/`or` expressions involving zero, THE JIT SHALL generate code consistent with zero being falsy.
5. WHILE 64-bit JIT compilation is active, THE System SHALL produce results identical to the Interpreter for all boolean contexts involving zero.
6. IF a JIT trace exits due to a zero-falsy guard, THE System SHALL fall back to the Interpreter and continue execution correctly.
7. WHEN the Phase 4 build (`src/w64build_amalg_64bit.bat`) is complete, THE System SHALL pass `test/test_zero.lua`, `test/test_truthiness.lua`, `test/test_zero_extra.lua`, and `test/test_patterns.lua` each as a separate `luajit.exe` invocation.

### Requirement 4: Build System Support

**User Story:** As a developer building this LuaJIT fork, I want build scripts for both 32-bit and 64-bit targets, so that I can compile and test both configurations easily.

#### Acceptance Criteria

1. THE 32-bit build script (`src/w64build_amalg_32bit.bat`) SHALL build LuaJIT successfully with the zero-is-false change applied.
2. THE 64-bit build script (`src/w64build_amalg_64bit.bat`) SHALL prepend `D:\hiperbou\w64devkit\w64devkit\bin` to `PATH` before invoking the build.
3. THE 64-bit build script SHALL invoke `mingw32-make amalg` with appropriate 64-bit flags (no `-m32`, no `LUAJIT_DISABLE_GC64`).
4. IF either build fails, THE build script SHALL print a clear failure message and exit with a non-zero exit code.

### Requirement 4b: 32-bit Interpreter-Only Build Script

**User Story:** As a developer testing the interpreter-only phase of this fork, I want a dedicated 32-bit build script with JIT disabled, so that I can compile and run tests against the pure interpreter without JIT interference.

#### Acceptance Criteria

1. THE 32-bit no-JIT build script (`src/w64build_amalg_32bit_nojit.bat`) SHALL build LuaJIT with `-m32`, `LUAJIT_DISABLE_GC64`, and `XCFLAGS=-DLUAJIT_DISABLE_JIT`.
2. WHEN the no-JIT build completes successfully, THE build script SHALL produce a `luajit.exe` that runs entirely in interpreter mode.
3. IF the no-JIT build fails, THE build script SHALL print a clear failure message and exit with a non-zero exit code.

### Requirement 4c: 64-bit Interpreter-Only Build Script

**User Story:** As a developer testing the interpreter-only phase of this fork on 64-bit, I want a dedicated 64-bit build script with JIT disabled, so that I can compile and run interpreter-only tests on x86-64 without JIT interference.

#### Acceptance Criteria

1. THE 64-bit no-JIT build script (`src/w64build_amalg_64bit_nojit.bat`) SHALL prepend `D:\hiperbou\w64devkit\w64devkit\bin` to `PATH` before invoking the build.
2. THE 64-bit no-JIT build script SHALL invoke `mingw32-make amalg` without `-m32` and without `LUAJIT_DISABLE_GC64`, and with `XCFLAGS=-DLUAJIT_DISABLE_JIT`.
3. WHEN the 64-bit no-JIT build completes successfully, THE build script SHALL produce a `luajit.exe` that runs entirely in interpreter mode on x86-64.
4. IF the 64-bit no-JIT build fails, THE build script SHALL print a clear failure message and exit with a non-zero exit code.

### Requirement 5: Test Suite Compatibility

**User Story:** As a developer, I want the existing test files to pass with the zero-is-false semantics at the end of each implementation phase, so that I can verify correctness before advancing.

#### Acceptance Criteria

1. WHEN `test/test_zero.lua` is executed individually, THE System SHALL report all tests as passed.
2. WHEN `test/test_truthiness.lua` is executed individually, THE System SHALL report all assertions as passed.
3. WHEN `test/test_zero_extra.lua` is executed individually, THE System SHALL report all tests as passed.
4. WHEN `test/test_patterns.lua` is executed individually, THE System SHALL report all tests as passed.
5. THE test runner SHALL execute each file in `test/` as a separate `luajit.exe` invocation so that verbose output from each test is visible and a failure in one test cannot be obscured by output from another.
6. THE test suite SHALL be run against the build produced at the end of each phase (Phase 1: `w64build_amalg_32bit_nojit.bat`, Phase 2: `w64build_amalg_32bit.bat`, Phase 3: `w64build_amalg_64bit_nojit.bat`, Phase 4: `w64build_amalg_64bit.bat`) and all 4 files must pass before the next phase begins.
7. THE test suite SHALL verify that `0 and expr` returns `0`, `0 or expr` returns `expr`, `not 0` returns `true`, and `if 0 then` takes the false branch.

### Requirement 6: Round-Trip and Consistency Properties

**User Story:** As a developer, I want the zero-is-false semantics to be internally consistent, so that there are no surprising edge cases between interpreter and JIT modes.

#### Acceptance Criteria

1. FOR ALL numeric values `x`, THE System SHALL produce the same boolean result for `if x then` in both interpreter and JIT modes.
2. FOR ALL numeric values `x`, THE System SHALL satisfy: `(not x) == (not (not (not x)))` (double negation consistency).
3. FOR ALL numeric values `x`, THE System SHALL satisfy: `(x and true or false) == (not (not x))` (and/or consistency with not).
4. THE System SHALL treat integer `0` and double `0.0` as equivalent in boolean contexts (both falsy).
5. THE System SHALL treat double `-0.0` as falsy, consistent with `0.0`.
