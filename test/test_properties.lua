-- Property-based tests for zero-is-false semantics.
-- Each property runs over a fixed set of representative inputs.
-- Feature: zero-is-false

local fails = 0
local function check(cond, msg)
  if not cond then
    print("FAIL: " .. msg)
    fails = fails + 1
  end
end

-- Representative test numbers: zeros, non-zeros, edge cases.
local test_numbers = {
  0, 0.0, -0.0,           -- zeros (falsy)
  1, -1, 2, 100, -100,    -- non-zero integers
  0.1, -0.1, 1.5, 1e10,   -- non-zero floats
  math.huge, -math.huge,  -- infinities (truthy)
}

-- Helper: boolean result of a value in a conditional.
local function bool_result(x)
  if x then return true else return false end
end

-- -- Feature: zero-is-false, Property 1: Zero values are falsy
local zeros = {0, 0.0, -0.0}
for _, z in ipairs(zeros) do
  check(not z, "Property 1: zero should be falsy: " .. tostring(z))
end

-- -- Feature: zero-is-false, Property 2: Non-zero numbers are truthy
math.randomseed(42)
for i = 1, 100 do
  local x = (math.random() + 0.001) * (math.random() > 0.5 and 1 or -1) * 1e6
  check(bool_result(x), "Property 2: non-zero number should be truthy: " .. tostring(x))
end
-- Also check fixed non-zero values
for _, x in ipairs({1, -1, 0.1, -0.1, 1e10, math.huge}) do
  check(bool_result(x), "Property 2: non-zero number should be truthy: " .. tostring(x))
end

-- -- Feature: zero-is-false, Property 4: Not-consistency (triple negation)
for _, x in ipairs(test_numbers) do
  check(
    (not x) == (not (not (not x))),
    "Property 4: triple negation failed for: " .. tostring(x)
  )
end

-- -- Feature: zero-is-false, Property 5: And/or short-circuit consistency
for _, x in ipairs(test_numbers) do
  check(
    (x and true or false) == (not (not x)),
    "Property 5: and/or/not consistency failed for: " .. tostring(x)
  )
end

if fails > 0 then
  print(fails .. " PROPERTY TESTS FAILED")
  os.exit(1)
else
  print("ALL PROPERTY TESTS PASSED (Properties 1, 2, 4, 5)")
  os.exit(0)
end
