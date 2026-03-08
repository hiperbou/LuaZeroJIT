local fails = 0

local function check(cond, msg)
  if not cond then
    print("FAIL: " .. msg)
    fails = fails + 1
  else
    print("PASS: " .. msg)
  end
end

local function test_logical()
  print("--- Logical Patterns ---")
  local zero = 0
  local one = 1
  
  -- (val or 0) + 1
  check((zero or 0) + 1 == 1, "(0 or 0) + 1 should be 1")
  check((nil or 0) + 1 == 1, "(nil or 0) + 1 should be 1")
  
  -- a and b or c
  check((zero and "a" or "b") == "b", "(0 and 'a' or 'b') should be 'b'")
  check((one and "a" or "b") == "a", "(1 and 'a' or 'b') should be 'a'")
  
  -- not 
  check(not zero == true, "not 0 should be true")
  check(not (zero == 0) == false, "not (0 == 0) should be false")
  check(not (zero ~= 0) == true, "not (0 ~= 0) should be true")
  
  -- nested logicals from failing.lua
  local grass_enabled = 0
  local sonic_speed = 5
  if (not grass_enabled) or (sonic_speed < 6) then
    check(true, "nested logical 1 passed")
  else
    check(false, "nested logical 1 failed")
  end
  
  grass_enabled = 1
  sonic_speed = 10
  if (not grass_enabled) or (sonic_speed < 6) then
    check(false, "nested logical 2 failed")
  else
    check(true, "nested logical 2 passed")
  end
end

local function test_inheritance()
  print("--- Inheritance Patterns ---")
  local function inheritsFrom( base )
    local new_class = {}
    local class_mt = { __index = base }
    setmetatable( new_class, class_mt )
    new_class.new = function( self, o )
       o = o or {}
       setmetatable( o, { __index = self } )
       return o
    end
    return new_class
  end

  local Base = { type = "base", val = 0 }
  function Base:isZero() return self.val == 0 end

  local Child = inheritsFrom(Base)
  local obj = Child:new({ val = 0 })
  
  check(obj.type == "base", "Inherited property access")
  if obj:isZero() then
    check(true, "Method call on 0-val")
  else
    check(false, "Method call on 0-val failed truthiness")
  end
  
  -- Test with 0 as metatable? (Not possible in Lua, but good to think about)
end

local function test_tables()
  print("--- Table Patterns ---")
  local t = {}
  t[0] = "zero"
  t[1] = "one"
  
  check(t[0] == "zero", "Indexing with 0")
  
  local count = 0
  for k, v in pairs(t) do
    if k == 0 then check(v == "zero", "Pairs with 0 key") end
    count = count + 1
  end
  check(count == 2, "Pairs count")
  
  -- Use 0 in a way that might trigger hash collisions or weirdness
  local t2 = {}
  for i=0, 100 do
    t2[i] = i
  end
  check(t2[0] == 0, "Large table indexing with 0")
end

local function run_all()
  test_logical()
  test_inheritance()
  test_tables()
end

print("--- Interpreter ---")
run_all()

print("--- JIT ---")
for i=1,100 do run_all() end

if fails > 0 then
  print("\n" .. fails .. " TESTS FAILED")
  os.exit(1)
else
  print("\nALL TESTS PASSED")
  os.exit(0)
end
