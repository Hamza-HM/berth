// Window ownership for the workspace labels.
//
// Quickshell's toplevel list only keeps the workspace you are on, so an
// occupied name disappears the moment you leave it. This map is the list
// Hyprland actually has: one startup snapshot, then open, close, and move.

function normalizeAddress(address) {
  var value = String(address || "").trim().toLowerCase()
  if (value.indexOf("0x") === 0) value = value.slice(2)
  return value
}

function copyMap(source) {
  var next = {}
  if (!source) return next
  for (var key in source) next[key] = source[key]
  return next
}

function usableWorkspace(name) {
  var value = String(name || "")
  if (!value || value.indexOf("special:") === 0) return ""
  return value
}

function note(clients, address, workspace) {
  var id = normalizeAddress(address)
  var name = usableWorkspace(workspace)
  if (!id || !name) return clients
  if (clients && clients[id] === name) return clients
  var next = copyMap(clients)
  next[id] = name
  return next
}

function drop(clients, address) {
  var id = normalizeAddress(address)
  if (!id || !clients || clients[id] === undefined) return clients
  var next = copyMap(clients)
  delete next[id]
  return next
}

function count(clients, workspace) {
  var total = 0
  if (!clients) return 0
  for (var key in clients) {
    if (clients[key] === workspace) total += 1
  }
  return total
}

function fromHyprctl(list) {
  var next = {}
  if (!Array.isArray(list)) return next
  for (var i = 0; i < list.length; i++) {
    var client = list[i]
    if (!client || client.mapped === false) continue
    var workspace = client.workspace
    var name = usableWorkspace(workspace && workspace.name)
    var id = normalizeAddress(client.address)
    if (!id || !name) continue
    next[id] = name
  }
  return next
}

// Events that land while the startup snapshot is in flight must win.
// A close during that window is remembered so the snapshot cannot put it back.
function mergeSeed(current, seeded, dropped) {
  var next = copyMap(current)
  if (!seeded) return next
  for (var id in seeded) {
    if (dropped && dropped[id]) continue
    if (next[id] === undefined) next[id] = seeded[id]
  }
  return next
}

function applyEvent(clients, name, parts) {
  var fields = parts || []
  if (name === "openwindow" || name === "movewindow") return note(clients, fields[0], fields[1])
  if (name === "movewindowv2") return note(clients, fields[0], fields[2])
  if (name === "closewindow") return drop(clients, fields[0])
  return clients
}
