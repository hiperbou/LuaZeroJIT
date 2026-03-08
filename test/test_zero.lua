local fails = 0

local function check(cond, msg)
  if not cond then
    print("FAIL: " .. msg)
    fails = fails + 1
  else
    print("PASS: " .. msg)
  end
end

local function test()
  -- Literal 0
  if 0 then check(false, "0 evaluated to true") else check(true, "0 evaluated to false") end
  -- Variable 0
  local x = 0
  if x then check(false, "x=0 evaluated to true") else check(true, "x=0 evaluated to false") end
  -- Variable 1
  local y = 1
  if y then check(true, "y=1 evaluated to true") else check(false, "y=1 evaluated to false") end
  
  -- not 0 / not 1
  check(not 0 == true, "not 0 should be true")
  check(not 1 == false, "not 1 should be false")
  
  -- Short circuit and/or
  check((0 and "yes") == 0, "0 and 'yes' should return 0")
  check((0 or "yes") == "yes", "0 or 'yes' should return 'yes'")
  
  check((1 and "yes") == "yes", "1 and 'yes' should return 'yes'")
  check((1 or "yes") == 1, "1 or 'yes' should return 1")
end

-- Test interpreter
print("--- Interpreter ---")
test()

-- Test JIT
print("--- JIT ---")
for i=1,100 do test() end

if fails > 0 then
  print("\n" .. fails .. " TESTS FAILED")
  os.exit(1)
else
  print("\nALL TESTS PASSED")
  os.exit(0)
end
