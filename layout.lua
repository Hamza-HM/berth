-- Same rules as Layout.js. Hyprland's Lua config has no JSON library,
-- so this reader accepts the layout file the bar plugin also reads.

local M = {}

local function blank_serial(serial)
  local value = tostring(serial or ""):match("^%s*(.-)%s*$") or ""
  if value == "" then return true end
  return value:match("^0+$") ~= nil
end

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

function M.matches(entry, monitor)
  local model = tostring(entry.model or "")
  local description = tostring(monitor.description or "")
  if model == "" or not description:find(model, 1, true) then return false end
  local wanted = tostring(entry.serial or "")
  local serial = tostring(monitor.serial or "")
  if not blank_serial(wanted) then return wanted == serial end
  return blank_serial(serial)
end

local function decode(text)
  local index = 1
  local length = #text

  local function peek()
    return text:sub(index, index)
  end

  local function skip()
    while true do
      local char = peek()
      if char == "" or not char:match("%s") then break end
      index = index + 1
    end
  end

  local function parse_string()
    index = index + 1
    local out = {}
    while index <= length do
      local char = peek()
      if char == "\"" then
        index = index + 1
        return table.concat(out)
      end
      if char == "\\" then
        local escaped = text:sub(index + 1, index + 1)
        local map = { ["\""] = "\"", ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
        table.insert(out, map[escaped] or escaped)
        index = index + 2
      else
        table.insert(out, char)
        index = index + 1
      end
    end
    return nil
  end

  local function parse_value()
    skip()
    local char = peek()
    if char == "\"" then return parse_string() end
    if char == "{" then
      index = index + 1
      local object = {}
      skip()
      if peek() == "}" then
        index = index + 1
        return object
      end
      while true do
        skip()
        local key = parse_string()
        skip()
        index = index + 1
        object[key] = parse_value()
        skip()
        local mark = peek()
        index = index + 1
        if mark == "}" then return object end
      end
    end
    if char == "[" then
      index = index + 1
      local array = {}
      skip()
      if peek() == "]" then
        index = index + 1
        return array
      end
      while true do
        table.insert(array, parse_value())
        skip()
        local mark = peek()
        index = index + 1
        if mark == "]" then return array end
      end
    end
    if text:sub(index, index + 3) == "true" then index = index + 4 return true end
    if text:sub(index, index + 4) == "false" then index = index + 5 return false end
    if text:sub(index, index + 3) == "null" then index = index + 4 return nil end
    local token = text:match("^-?%d+%.?%d*[eE]?[+%-]?%d*", index)
    if token and token ~= "" then
      index = index + #token
      return tonumber(token)
    end
    return nil
  end

  return parse_value()
end

function M.normalize(raw)
  local screens = raw and raw.screens or {}
  local taken = {}
  local out = {}
  for _, screen in ipairs(screens) do
    if type(screen) == "table" and screen.model then
      local names = {}
      local keys = {}
      for _, item in ipairs(screen.workspaces or {}) do
        local name, key = "", ""
        if type(item) == "table" then
          name = trim(item.name)
          key = trim(item.key)
        else
          name = trim(item)
        end
        if name ~= "" and not taken[name] then
          taken[name] = true
          table.insert(names, name)
          table.insert(keys, key)
        end
      end
      local home = trim(screen.home)
      local found = false
      for _, name in ipairs(names) do
        if name == home then found = true end
      end
      if not found then home = names[1] or "" end
      table.insert(out, {
        make = trim(screen.make),
        model = trim(screen.model),
        serial = trim(screen.serial),
        connector = trim(screen.connector),
        home = home,
        names = names,
        keys = keys,
      })
    end
  end
  return out
end

local function push_row(rows, name, key, connector, home)
  table.insert(rows, { name = name, key = key or "", connector = connector or "", home = home and true or false })
end

function M.assign(raw, monitors)
  local entries = M.normalize(raw)
  local groups = {}

  local function group_for(entry)
    for _, group in ipairs(groups) do
      if M.matches(entry, group.sample) then return group end
    end
    local created = {
      sample = { description = entry.model, serial = entry.serial },
      entries = {},
      monitors = {},
    }
    table.insert(groups, created)
    return created
  end

  for _, entry in ipairs(entries) do
    table.insert(group_for(entry).entries, entry)
  end

  for _, monitor in ipairs(monitors or {}) do
    if monitor.name and monitor.name ~= "" then
      for _, group in ipairs(groups) do
        if M.matches(group.entries[1], monitor) then
          table.insert(group.monitors, monitor)
          break
        end
      end
    end
  end

  local rows = {}
  local owner = {}
  local reserved = {}

  local function bind(entry, monitor)
    for index, name in ipairs(entry.names) do
      owner[name] = monitor.name
      push_row(rows, name, entry.keys[index], monitor.name, name == entry.home)
    end
    entry.bound = true
  end

  for _, group in ipairs(groups) do
    if #group.entries == 1 and #group.monitors == 1 then
      bind(group.entries[1], group.monitors[1])
    else
      local used = {}
      for _, entry in ipairs(group.entries) do
        if entry.connector ~= "" then
          for _, monitor in ipairs(group.monitors) do
            if not used[monitor.name] and monitor.name == entry.connector then
              bind(entry, monitor)
              used[monitor.name] = true
              break
            end
          end
        end
      end
    end
  end

  for _, entry in ipairs(entries) do
    for index, name in ipairs(entry.names) do
      reserved[name] = true
      if not owner[name] then
        push_row(rows, name, entry.keys[index], "", name == entry.home)
      end
    end
  end

  return { rows = rows, owner = owner, reserved = reserved }
end

function M.read(path)
  local handle = io.open(path, "r")
  if not handle then return { screens = {} } end
  local text = handle:read("*a")
  handle:close()
  return decode(text) or { screens = {} }
end

function M.path()
  return (os.getenv("HOME") or "") .. "/.config/omarchy/plugins/hamza.berth/layout.json"
end

return M
