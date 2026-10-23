local berth = dofile((arg[0]:match("(.*/)") or "./") .. "../layout.lua")

local failed = 0
local function check(condition, message)
  if condition then
    print("ok", message)
    return
  end
  failed = failed + 1
  print("FAIL", message)
end

local layout = {
  screens = {
    {
      model = "Hero",
      serial = "0000000000000",
      home = "ui",
      workspaces = {
        { name = "ui", key = "code:81" },
        { name = "term", key = "code:90" },
      },
    },
    {
      model = "Tall",
      serial = "SERIAL123",
      home = "chat",
      workspaces = { { name = "chat", key = "code:88" } },
    },
  },
}

local live = {
  { name = "DP-9", description = "Maker Hero 0000000000000", serial = "0000000000000" },
  { name = "HDMI-A-1", description = "Maker Tall SERIAL123", serial = "SERIAL123" },
}

local plan = berth.assign(layout, live)
check(plan.owner.term == "DP-9", "a renamed port still receives the matching panel")
check(plan.owner.chat == "HDMI-A-1", "a real serial stays on its panel")
check(plan.reserved.chat == true, "matched names are reserved")

local unplugged = berth.assign(layout, { live[1] })
check(unplugged.owner.chat == nil, "an unplugged panel does not claim a port")
check(unplugged.reserved.chat == true, "an unplugged name stays reserved")

local example = berth.read((arg[0]:match("(.*/)") or "./") .. "../layout.example.json")
local example_plan = berth.assign(example, {
  { name = "DP-1", description = "Example Maker Panel SERIAL", serial = "SERIAL" },
})
check(example_plan.owner.main == "DP-1", "the example layout binds its home workspace")

if failed > 0 then
  os.exit(1)
end
print("passed")
