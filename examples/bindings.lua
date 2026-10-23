-- Named workspaces. The monitor each name belongs to comes from the Berth
-- layout, matched by model and serial. Add this to hypr/bindings.lua.

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

local function apply_workspace_rules()
  for _, workspace in ipairs(berth_plan().rows) do
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

apply_workspace_rules()
hl.on("monitor.added", function() apply_workspace_rules() end)
hl.on("monitor.removed", function() apply_workspace_rules() end)

for _, workspace in ipairs(berth_plan().rows) do
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
