-- test_jit_zero.lua
-- Phase 2 TDD: JIT-specific tests for zero-is-false semantics.
-- Runs hot loops (200+ iterations) to trigger JIT compilation.
-- Must pass on BOTH no-JIT and JIT builds.
--
-- Covers:
--   BC_IST  / BC_ISFC  (true-branch opcode paths)
--   BC_ISF  / BC_ISTC  (false-branch opcode paths)
--   BC_NOT  (logical NOT on numeric zero)
--   Mixed zero/non-zero alternation inside a single hot loop

local fails = 0

local function check(cond, msg)
  if not cond then
    print("FAIL: " .. msg)
    fails = fails + 1
  else
    print("PASS: " .. msg)
  end
end

-- -----------------------------------------------------------------------
-- BC_IST / BC_ISFC  — true-branch specialization
-- The JIT must emit an IR_NE guard for non-zero (truecond path)
-- and an IR_EQ guard for zero (zerocond path), so that the trace stays on the
-- true branch only when the value is actually non-zero.
-- -----------------------------------------------------------------------

local function test_ist_int_zero()
  -- Feature: zero-is-false, Bug 1a: IST integer zero treated as truthy by JIT
  local count = 0
  local x = 0      -- integer zero
  for i = 1, 200 do
    if x then            -- BC_IST: should NOT branch (zero is falsy)
      count = count + 1
    end
  end
  check(count == 0, "BC_IST: integer 0 is falsy in JIT loop (count=" .. count .. ")")
end

local function test_ist_float_zero()
  -- Feature: zero-is-false, Bug 1b: IST float zero treated as truthy by JIT
  local count = 0
  local x = 0.0   -- double zero
  for i = 1, 200 do
    if x then
      count = count + 1
    end
  end
  check(count == 0, "BC_IST: float 0.0 is falsy in JIT loop (count=" .. count .. ")")
end

local function test_ist_neg_float_zero()
  -- Feature: zero-is-false, Bug 1c: IST -0.0 treated as truthy by JIT
  local count = 0
  local x = -0.0
  for i = 1, 200 do
    if x then
      count = count + 1
    end
  end
  check(count == 0, "BC_IST: float -0.0 is falsy in JIT loop (count=" .. count .. ")")
end

local function test_ist_nonzero_truthy()
  -- Feature: zero-is-false, Property 2: non-zero numbers stay truthy in JIT
  local count = 0
  local x = 42
  for i = 1, 200 do
    if x then
      count = count + 1
    end
  end
  check(count == 200, "BC_IST: integer 42 is truthy in JIT loop (count=" .. count .. ")")
end

-- -----------------------------------------------------------------------
-- BC_ISF / BC_ISTC — false-branch specialization
-- The JIT must emit IR_EQ guard for zero to stay on the false-branch trace.
-- Bug: existing code emits IR_NE in BOTH arms (copy-paste mistake).
-- -----------------------------------------------------------------------

local function test_isf_int_zero()
  -- Feature: zero-is-false, Bug 2a: ISF integer zero — false branch not taken by JIT
  local count = 0
  local x = 0
  for i = 1, 200 do
    if not x then         -- BC_ISF: should branch (zero is falsy)
      count = count + 1
    end
  end
  check(count == 200, "BC_ISF: integer 0 takes false branch in JIT loop (count=" .. count .. ")")
end

local function test_isf_float_zero()
  -- Feature: zero-is-false, Bug 2b: ISF float zero — false branch not taken by JIT
  local count = 0
  local x = 0.0
  for i = 1, 200 do
    if not x then
      count = count + 1
    end
  end
  check(count == 200, "BC_ISF: float 0.0 takes false branch in JIT loop (count=" .. count .. ")")
end

local function test_isf_neg_float_zero()
  -- Feature: zero-is-false, Bug 2c: ISF -0.0
  local count = 0
  local x = -0.0
  for i = 1, 200 do
    if not x then
      count = count + 1
    end
  end
  check(count == 200, "BC_ISF: float -0.0 takes false branch in JIT loop (count=" .. count .. ")")
end

local function test_isf_nonzero_stays_truthy()
  -- Feature: zero-is-false, Property 2: non-zero does NOT take false branch
  local count = 0
  local x = 7
  for i = 1, 200 do
    if not x then
      count = count + 1
    end
  end
  check(count == 0, "BC_ISF: integer 7 does not take false branch in JIT loop (count=" .. count .. ")")
end

-- -----------------------------------------------------------------------
-- BC_NOT — logical NOT on numeric zero
-- JIT must specialise on the runtime value: zero => TREF_TRUE, non-zero => TREF_FALSE
-- Bug: existing code only checks type-tag, so (not 0) returns false instead of true.
-- -----------------------------------------------------------------------

local function test_not_int_zero()
  -- Feature: zero-is-false, Bug 3a: BC_NOT integer zero returns wrong value in JIT
  local results = {}
  local x = 0
  for i = 1, 200 do
    results[i] = not x
  end
  -- spot-check a sample
  check(results[1]   == true, "BC_NOT: (not 0) == true, iter 1")
  check(results[100] == true, "BC_NOT: (not 0) == true, iter 100")
  check(results[200] == true, "BC_NOT: (not 0) == true, iter 200")
end

local function test_not_float_zero()
  -- Feature: zero-is-false, Bug 3b: BC_NOT float zero
  local results = {}
  local x = 0.0
  for i = 1, 200 do
    results[i] = not x
  end
  check(results[1]   == true, "BC_NOT: (not 0.0) == true, iter 1")
  check(results[100] == true, "BC_NOT: (not 0.0) == true, iter 100")
  check(results[200] == true, "BC_NOT: (not 0.0) == true, iter 200")
end

local function test_not_neg_float_zero()
  -- Feature: zero-is-false, Bug 3c: BC_NOT -0.0
  local results = {}
  local x = -0.0
  for i = 1, 200 do
    results[i] = not x
  end
  check(results[1]   == true, "BC_NOT: (not -0.0) == true, iter 1")
  check(results[200] == true, "BC_NOT: (not -0.0) == true, iter 200")
end

local function test_not_nonzero()
  -- Feature: zero-is-false, Property 2: (not non-zero) == false in JIT
  local results = {}
  local x = 5
  for i = 1, 200 do
    results[i] = not x
  end
  check(results[1]   == false, "BC_NOT: (not 5) == false, iter 1")
  check(results[200] == false, "BC_NOT: (not 5) == false, iter 200")
end

-- -----------------------------------------------------------------------
-- Mixed zero/non-zero alternation in a single hot loop
-- Forces the JIT to exit on the unexpected value and re-specialise.
-- This exercises guard exits + interpreter fallback.
-- -----------------------------------------------------------------------

local function test_mixed_ist_alternating()
  -- Feature: zero-is-false, Property 6: JIT/interpreter consistency when value alternates
  local errors = 0
  for i = 1, 200 do
    local x = (i % 2 == 0) and 0 or 1   -- alternates 1, 0, 1, 0 ...
    local expected_truthy = (x ~= 0)
    local actual_truthy
    if x then actual_truthy = true else actual_truthy = false end
    if actual_truthy ~= expected_truthy then
      errors = errors + 1
    end
  end
  check(errors == 0, "Mixed IST alternating: no JIT/interp mismatch (errors=" .. errors .. ")")
end

local function test_mixed_isf_alternating()
  -- Feature: zero-is-false, Property 6: false-branch consistency when value alternates
  local errors = 0
  for i = 1, 200 do
    local x = (i % 2 == 0) and 0 or 1
    local expected_falsy = (x == 0)
    local actual_falsy
    if not x then actual_falsy = true else actual_falsy = false end
    if actual_falsy ~= expected_falsy then
      errors = errors + 1
    end
  end
  check(errors == 0, "Mixed ISF alternating: no JIT/interp mismatch (errors=" .. errors .. ")")
end

local function test_mixed_not_alternating()
  -- Feature: zero-is-false, Property 4: (not x) consistency when value alternates
  local errors = 0
  for i = 1, 200 do
    local x = (i % 2 == 0) and 0 or 1
    local expected = (x == 0)   -- not x == true when x == 0
    local actual = not x
    if actual ~= expected then
      errors = errors + 1
    end
  end
  check(errors == 0, "Mixed NOT alternating: no JIT/interp mismatch (errors=" .. errors .. ")")
end

-- -----------------------------------------------------------------------
-- ISTC / ISFC — copy-and-test variants (the value is both tested and stored)
-- These map to slightly different bytecode but the same recorder code path.
-- -----------------------------------------------------------------------

local function test_istc_zero()
  -- Feature: zero-is-false, Bug 1d: ISTC with zero should not copy/branch
  local count = 0
  for i = 1, 200 do
    local x = 0
    local y = x and "yes" or "no"  -- ISTC path: copy x if truthy
    if y == "no" then count = count + 1 end
  end
  check(count == 200, "BC_ISTC: (0 and 'yes' or 'no') == 'no' in JIT loop (count=" .. count .. ")")
end

local function test_isfc_zero()
  -- Feature: zero-is-false, Bug 2d: ISFC with zero should copy and branch to false
  local count = 0
  for i = 1, 200 do
    local x = 0
    local y = x or "fallback"       -- ISFC path: copy x if falsy? No: OR copies right side
    if y == "fallback" then count = count + 1 end
  end
  check(count == 200, "BC_ISFC: (0 or 'fallback') == 'fallback' in JIT loop (count=" .. count .. ")")
end

-- -----------------------------------------------------------------------
-- Run all tests
-- -----------------------------------------------------------------------

print("=== test_jit_zero.lua ===")
print("--- BC_IST (true-branch specialization) ---")
test_ist_int_zero()
test_ist_float_zero()
test_ist_neg_float_zero()
test_ist_nonzero_truthy()

print("--- BC_ISF (false-branch specialization) ---")
test_isf_int_zero()
test_isf_float_zero()
test_isf_neg_float_zero()
test_isf_nonzero_stays_truthy()

print("--- BC_NOT (logical NOT on numbers) ---")
test_not_int_zero()
test_not_float_zero()
test_not_neg_float_zero()
test_not_nonzero()

print("--- Mixed alternating (JIT/interp consistency) ---")
test_mixed_ist_alternating()
test_mixed_isf_alternating()
test_mixed_not_alternating()

print("--- BC_ISTC / BC_ISFC (copy-and-test variants) ---")
test_istc_zero()
test_isfc_zero()

if fails > 0 then
  print("\n" .. fails .. " TESTS FAILED")
  os.exit(1)
else
  print("\nALL TESTS PASSED")
  os.exit(0)
end
