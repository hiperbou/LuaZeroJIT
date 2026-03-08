local fails = 0

local function check(cond, msg)
  if not cond then
    print("FAIL: " .. msg)
    fails = fails + 1
  else
    print("PASS: " .. msg)
  end
end

local function test_truthiness()
  print("--- Truthiness ---")
  local cases = {
    { val = 0, expected = false, name = "int 0" },
    { val = 0.0, expected = false, name = "float 0.0" },
    { val = -0.0, expected = false, name = "float -0.0" },
    { val = 1, expected = true, name = "int 1" },
    { val = 0.1, expected = true, name = "float 0.1" },
    { val = -1, expected = true, name = "int -1" },
    { val = nil, expected = false, name = "nil" },
    { val = false, expected = false, name = "false" },
    { val = true, expected = true, name = "true" },
    { val = "", expected = true, name = "empty string" },
    { val = {}, expected = true, name = "table" },
  }

  for _, c in ipairs(cases) do
    if c.val then
      check(c.expected == true, c.name .. " evaluated to true")
    else
      check(c.expected == false, c.name .. " evaluated to false")
    end

    check((not c.val) == (not c.expected), "not " .. c.name)
  end
end

local function test_short_circuit()
  print("--- Short Circuit ---")
  check((0 or 1) == 1, "0 or 1 -> 1")
  check((0 and 1) == 0, "0 and 1 -> 0")
  check((1 or 0) == 1, "1 or 0 -> 1")
  check((1 and 0) == 0, "1 and 0 -> 0")
  check((nil or 0) == 0, "nil or 0 -> 0")
  check((0 or nil) == nil, "0 or nil -> nil")
end

local function test_jit()
  print("--- JIT loop ---")
  for i=1,200 do
    local x = (i % 2 == 0) and 0 or 1
    if x then
      if x ~= 1 then error("Expected 1 at i=" .. i) end
    else
      if x ~= 0 then error("Expected 0 at i=" .. i) end
    end
  end
  print("PASS: JIT loop")
end

local function run_all()
  test_truthiness()
  test_short_circuit()
  test_jit()
end

print("Interpreter:")
run_all()

print("\nJIT:")
-- Force JIT
if jit then
  jit.opt.start("hotloop=10")
end
run_all()

if fails > 0 then
  print("\n" .. fails .. " TESTS FAILED")
  os.exit(1)
else
  print("\nALL TESTS PASSED")
  os.exit(0)
end
