-- Workspace rules and keys. bindings.lua loads this with one dofile.
-- The layout file is the list of names. This file does not name monitors.

local berth = dofile((os.getenv("HOME") or "") .. "/.config/omarchy/plugins/hamza.berth/layout.lua")

local function live_monitors()
  local list = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    table.insert(list, {
      name = monitor.name,
      description = monitor.description or "",
      serial = monitor.serial or "",
    })
  end
  return list
end

local function berth_plan()
  return berth.assign(berth.read(berth.path()), live_monitors())
end

local function apply_workspace_rules(plan)
  for _, workspace in ipairs(plan.rows) do
    if workspace.connector ~= "" then
      hl.workspace_rule({
        workspace = "name:" .. workspace.name,
        monitor = workspace.connector,
        persistent = true,
        default = workspace.home or false,
      })
    end
  end
end

local function refresh_rules()
  apply_workspace_rules(berth_plan())
end

local initial = berth_plan()
apply_workspace_rules(initial)
hl.on("monitor.added", refresh_rules)
hl.on("monitor.removed", refresh_rules)

for _, workspace in ipairs(initial.rows) do
  if workspace.key ~= "" then
    local id = "name:" .. workspace.name
    if workspace.key == "code:10" or workspace.key == "code:11" then
      hl.unbind("SUPER + " .. workspace.key)
    end
    o.bind("SUPER + " .. workspace.key, "Workspace " .. workspace.name, hl.dsp.focus({ workspace = id }))
    if workspace.key ~= "code:10" and workspace.key ~= "code:11" then
      o.bind(
        "SUPER + SHIFT + " .. workspace.key,
        "Move window to " .. workspace.name,
        hl.dsp.window.move({ workspace = id })
      )
    end
  end
end
