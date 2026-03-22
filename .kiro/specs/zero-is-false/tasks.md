# Implementation Plan: zero-is-false

## Overview

Implement zero-as-falsy semantics in LuaJIT in four strictly ordered phases, each gated by a full pass of all four test files. The change touches the C truthiness macro, the x86 interpreter assembly handlers, and the JIT trace recorder.

## Tasks

- [x] 1. Create missing build scripts
  - [x] 1.1 Create `src/w64build_amalg_32bit_nojit.bat`
    - Copy `w64build_amalg_32bit.bat` as a base; add `XCFLAGS=-DLUAJIT_DISABLE_JIT` to the `mingw32-make amalg` invocation alongside the existing `-m32` and `LUAJIT_DISABLE_GC64` flags
    - Include the same success/failure banner and `exit /b 1` on error
    - _Requirements: 4b.1, 4b.2, 4b.3_
  - [x] 1.2 Create `src/w64build_amalg_64bit_nojit.bat`
    - Prepend `D:\hiperbou\w64devkit\w64devkit\bin` to `PATH`; invoke `mingw32-make clean && mingw32-make amalg` without `-m32` and without `LUAJIT_DISABLE_GC64`; add `XCFLAGS=-DLUAJIT_DISABLE_JIT`
    - Include success/failure banner and `exit /b 1` on error
    - _Requirements: 4c.1, 4c.2, 4c.3, 4c.4_
  - [x] 1.3 Create `src/w64build_amalg_64bit.bat`
    - Prepend `D:\hiperbou\w64devkit\w64devkit\bin` to `PATH`; invoke `mingw32-make clean && mingw32-make amalg` without `-m32` and without `LUAJIT_DISABLE_GC64`
    - Include success/failure banner and `exit /b 1` on error
    - _Requirements: 4.2, 4.3, 4.4_

- [x] 2. Phase 1 — 32-bit interpreter (JIT disabled)
  - [x] 2.1 Patch `tvistruecond` in `src/lj_obj.h`
    - Add a helper macro `tvisnumzero` that handles both the DUALNUM integer-zero case (`tvisint(o) && intV(o) == 0`) and the double-zero case (`tvisnum(o) && tviszero(o)`)
    - Rewrite `tvistruecond(o)` to `(itype(o) < LJ_TISTRUECOND && !tvisnumzero(o))`
    - This single change propagates to all C-level callers automatically
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.12, 1.13_
  - [x] 2.2 Patch the IST/ISFC/ISTC/ISF handlers in `src/vm_x86.dasc`
    - After the `cmp RB, LJ_TISTRUECOND` / `jae/jb >1` tag check, insert a secondary zero-value check for the case where the tag indicates a number
    - For 32-bit DUALNUM: if `RB == LJ_TISNUM` (integer), check `[BASE+RD*8] == 0`; if `RB < LJ_TISNUM` (double), check `([BASE+RD*8] | (RB << 1)) == 0`
    - For IST/ISTC (branch-if-true): a numeric zero must fall through to label `>1` (no branch) instead of branching
    - For ISF/ISFC (branch-if-false): a numeric zero must take the branch instead of falling through
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  - [x] 2.3 Patch the BC_NOT handler in `src/vm_x86.dasc`
    - The current handler uses `checktp RD, LJ_TISTRUECOND` / `adc RB, LJ_TTRUE` which only checks the type tag
    - After the tag check determines the value is a number (truthy by tag), add a zero-value check; if the number is zero, produce `LJ_TTRUE` instead of `LJ_TFALSE`
    - _Requirements: 1.5, 1.6, 1.7_
  - [x] 2.4 Build Phase 1 and run gate tests
    - Run `src\w64build_amalg_32bit_nojit.bat` and verify it exits 0
    - Run each test file individually: `test\luajit.exe test\test_zero.lua`, then `test\luajit.exe test\test_truthiness.lua`, then `test\luajit.exe test\test_zero_extra.lua`, then `test\luajit.exe test\test_patterns.lua`
    - All four must pass before proceeding to task 3
    - _Requirements: 1.14, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  - [x] 2.5 Write property tests for interpreter zero-falsy behavior
    - Create `test/test_properties.lua` with inline property runners (no external PBT library needed)
    - **Property 1: Zero values are falsy** — assert `not 0`, `not 0.0`, `not (-0.0)` each return `true`
    - **Property 2: Non-zero numbers are truthy** — for 100 random non-zero floats and integers, assert `if x then true else false end == true`
    - **Property 4: Not-consistency (triple negation)** — for a table of test numbers including 0, assert `(not x) == (not (not (not x)))`
    - **Property 5: And/or short-circuit consistency** — for the same table, assert `(x and true or false) == (not (not x))`
    - **Validates: Requirements 1.1–1.13, 6.2, 6.3, 6.4, 6.5**

- [ ] 3. Phase 2 — 32-bit JIT enabled
  - [ ] 3.1 Patch the JIT trace recorder in `src/lj_record.c` for BC_IST/BC_ISFC/BC_ISTC/BC_ISF
    - In the `case BC_ISTC: case BC_ISFC:` and `case BC_IST: case BC_ISF:` block (around line 2424), after type specialization, check whether `rc` has a number IR type (`tref_isnumber(rc)`)
    - For BC_IST/BC_ISTC (true branch): emit `emitir(IRTG(IR_NE, tref_type(rc)), rc, zero_k)` where `zero_k` is `lj_ir_kint(J, 0)` for integers or `lj_ir_knum_zero(J)` for doubles; this guard asserts non-zero to stay on the true-branch trace
    - For BC_ISF/BC_ISFC (false branch): emit `emitir(IRTG(IR_EQ, tref_type(rc)), rc, zero_k)` to assert zero to stay on the false-branch trace
    - Handle mixed int/num by widening with `IR_CONV` before comparing, consistent with `lj_record_objcmp`
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 2.6_
  - [~] 3.2 Patch the JIT trace recorder in `src/lj_record.c` for BC_NOT
    - In the `case BC_NOT:` block (around line 2447), after `tref_istruecond(rc)` determines the result, add a check: if `rc` has a number IR type, emit a guard `IR_EQ(rc, zero_k)` and set `rc = TREF_TRUE`, or `IR_NE(rc, zero_k)` and set `rc = TREF_FALSE`, depending on the runtime value
    - _Requirements: 2.3, 2.5_
  - [~] 3.3 Build Phase 2 and run gate tests
    - Run `src\w64build_amalg_32bit.bat` and verify it exits 0
    - Run each test file individually: `test\luajit.exe test\test_zero.lua`, then `test\luajit.exe test\test_truthiness.lua`, then `test\luajit.exe test\test_zero_extra.lua`, then `test\luajit.exe test\test_patterns.lua`
    - All four must pass before proceeding to task 4
    - _Requirements: 2.7, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  - [~] 3.4 Write property test for JIT/interpreter consistency
    - In `test/test_properties.lua`, add a hot-loop section that runs the same boolean tests 200 times to trigger JIT compilation
    - **Property 6: Interpreter/JIT consistency** — compare `bool_result(x)` inside the hot loop against a pre-computed interpreter baseline for all test numbers
    - **Validates: Requirements 2.5, 6.1**

- [ ] 4. Checkpoint — Phase 1 and Phase 2 complete
  - Ensure all tests pass for both 32-bit builds, ask the user if questions arise.

- [ ] 5. Phase 3 — 64-bit interpreter (JIT disabled)
  - [~] 5.1 Verify `tvistruecond` patch covers 64-bit (GC64) layout
    - Review the `tvisnumzero` macro added in task 2.1 against the 64-bit `tviszero` definition (`((o)->u64 << 1) == 0`) and the GC64 integer-zero representation
    - If the 64-bit integer-zero case is not covered by `tviszero` (because the tag bits are non-zero), extend `tvisnumzero` with the GC64-specific integer check, guarded by `#if LJ_GC64`
    - _Requirements: 3b.1, 3b.2_
  - [~] 5.2 Verify or patch the 64-bit IST/ISF/ISTC/ISFC handlers in `src/vm_x86.dasc`
    - The `.if X64` / `.if not X64` guards in `vm_x86.dasc` control which assembly is emitted; review the 64-bit path of the IST/ISF/ISTC/ISFC handlers
    - For 64-bit, the full 8-byte slot can be tested: load the 64-bit slot value and check `(slot << 1) == 0` for double zero; for integer zero in GC64, check the payload bits
    - Apply the same secondary zero-check pattern as task 2.2 but using 64-bit register operations
    - _Requirements: 3b.1, 3b.2_
  - [~] 5.3 Verify or patch the 64-bit BC_NOT handler in `src/vm_x86.dasc`
    - Review the 64-bit path of the BC_NOT handler and apply the same zero-value secondary check as task 2.3 using 64-bit operations
    - _Requirements: 3b.1_
  - [~] 5.4 Build Phase 3 and run gate tests
    - Run `src\w64build_amalg_64bit_nojit.bat` and verify it exits 0
    - Run each test file individually: `test\luajit.exe test\test_zero.lua`, then `test\luajit.exe test\test_truthiness.lua`, then `test\luajit.exe test\test_zero_extra.lua`, then `test\luajit.exe test\test_patterns.lua`
    - All four must pass before proceeding to task 6
    - _Requirements: 3b.3, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [ ] 6. Phase 4 — 64-bit JIT enabled
  - [~] 6.1 Verify the JIT recorder patches from task 3.1 and 3.2 cover 64-bit IR types
    - The recorder patches use `tref_isnumber(rc)` and `tref_type(rc)` which are type-agnostic; confirm they correctly handle `IRT_NUM` and `IRT_INT` on 64-bit
    - If GC64 introduces a different integer IR type or zero-constant representation, adjust `zero_k` selection accordingly
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [~] 6.2 Build Phase 4 and run gate tests
    - Run `src\w64build_amalg_64bit.bat` and verify it exits 0
    - Run each test file individually: `test\luajit.exe test\test_zero.lua`, then `test\luajit.exe test\test_truthiness.lua`, then `test\luajit.exe test\test_zero_extra.lua`, then `test\luajit.exe test\test_patterns.lua`
    - All four must pass to complete the feature
    - _Requirements: 3.7, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  - [~] 6.3 Run property tests against 64-bit JIT build
    - Run `test\luajit.exe test\test_properties.lua` against the Phase 4 binary
    - **Property 6: Interpreter/JIT consistency** — verify no JIT/interpreter mismatch on 64-bit
    - **Validates: Requirements 3.5, 6.1**

- [ ] 7. Final checkpoint — Ensure all tests pass
  - Ensure all four test files pass against all four build configurations, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each phase gate (tasks 2.4, 3.3, 5.4, 6.2) must pass completely before the next phase begins
- The `tvistruecond` patch in task 2.1 is shared across all phases; get it right before touching assembly
- The 32-bit DUALNUM integer-zero case requires a separate check from the double-zero case — `tviszero` alone is not sufficient for integers in 32-bit mode
- Property tests validate universal correctness; unit tests in `test/` validate specific examples and patterns
