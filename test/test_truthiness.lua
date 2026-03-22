
local function test_truthiness()
  local cases = {
    -- Falsy values
    { val = nil, expected = false, name = "nil" },
    { val = false, expected = false, name = "false" },
    { val = 0, expected = false, name = "0 (int)" },
    { val = 0.0, expected = false, name = "0.0 (double)" },
    { val = -0.0, expected = false, name = "-0.0 (double)" },
    
    -- Truthy values
    { val = true, expected = true, name = "true" },
    { val = 1, expected = true, name = "1 (int)" },
    { val = -1, expected = true, name = "-1 (int)" },
    { val = 0.1, expected = true, name = "0.1 (double)" },
    { val = "0", expected = true, name = "'0' (string)" },
    { val = "", expected = true, name = "'' (empty string)" },
    { val = {}, expected = true, name = "{} (table)" },
    { val = function() end, expected = true, name = "function" },
  }

  for _, c in ipairs(cases) do
    -- Test in IF
    local if_res
    if c.val then if_res = true else if_res = false end
    assert(if_res == c.expected, "Failed IF check for " .. c.name)

    -- Test with NOT
    assert((not c.val) == (not c.expected), "Failed NOT check for " .. c.name)

    -- Test with OR (The original failure case)
    local or_res = c.val or "fallback"
    if c.expected then
      assert(or_res == c.val, "Failed OR check (truthy) for " .. c.name)
    else
      assert(or_res == "fallback", "Failed OR check (falsy) for " .. c.name)
    end

    -- Test with AND
    local communities_res = c.val and "truthy"
    if c.expected then
      assert(communities_res == "truthy", "Failed AND check (truthy) for " .. c.name)
    else
      assert(communities_res == c.val, "Failed AND check (falsy) for " .. c.name)
    end
  end
  
  -- Extra check for the specific failure reported
  local deferred_priority_updates = nil
  deferred_priority_updates = deferred_priority_updates or {}
  assert(type(deferred_priority_updates) == "table", "Failed to initialize global via OR")

  print("All truthiness tests passed!")
end

test_truthiness()
