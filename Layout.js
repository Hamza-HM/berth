// Which workspaces belong to which physical monitor.
//
// Ports change when a cable moves. Make, model, and serial do not.
// A serial of all zeros is ignored, and the model has to appear in
// Hyprland's description so two panels from the same maker stay distinct.
// Two live monitors that match one entry are left unpinned unless the entry
// recorded the connector it was bound to.

function blankSerial(serial) {
  var value = String(serial || "").trim()
  if (!value) return true
  for (var i = 0; i < value.length; i++) {
    if (value.charAt(i) !== "0") return false
  }
  return true
}

function normalize(raw) {
  var screens = raw && raw.screens
  if (!Array.isArray(screens)) return []
  var taken = {}
  var out = []
  for (var i = 0; i < screens.length; i++) {
    var screen = screens[i]
    if (!screen || !screen.model) continue
    var names = []
    var keys = []
    var list = screen.workspaces || []
    for (var n = 0; n < list.length; n++) {
      var item = list[n]
      var name = ""
      var key = ""
      if (item && typeof item === "object") {
        name = String(item.name || "")
        key = String(item.key || "")
      } else {
        name = String(item || "")
      }
      if (!name || taken[name]) continue
      taken[name] = true
      names.push(name)
      keys.push(key)
    }
    var home = String(screen.home || "")
    if (names.indexOf(home) === -1) home = names.length ? names[0] : ""
    out.push({
      make: String(screen.make || ""),
      model: String(screen.model || ""),
      serial: String(screen.serial || ""),
      connector: String(screen.connector || ""),
      home: home,
      names: names,
      keys: keys
    })
  }
  return out
}

function matches(entry, monitor) {
  var model = String(entry.model || "")
  var description = String(monitor.description || "")
  if (!model || description.indexOf(model) === -1) return false
  var wanted = String(entry.serial || "")
  var serial = String(monitor.serial || "")
  if (!blankSerial(wanted)) return wanted === serial
  return blankSerial(serial)
}

function bind(result, entry, monitor) {
  var connector = String(monitor.name || "")
  if (!connector) return
  result.byConnector[connector] = entry.names.slice()
  result.home[connector] = entry.home
  for (var i = 0; i < entry.names.length; i++) {
    result.owner[entry.names[i]] = connector
    result.rows.push({
      name: entry.names[i],
      key: entry.keys[i] || "",
      connector: connector,
      home: entry.names[i] === entry.home
    })
  }
}

function reserve(result, entry) {
  for (var i = 0; i < entry.names.length; i++) {
    result.reserved[entry.names[i]] = true
    if (!result.owner[entry.names[i]]) {
      result.rows.push({
        name: entry.names[i],
        key: entry.keys[i] || "",
        connector: "",
        home: entry.names[i] === entry.home
      })
    }
  }
}

function assign(raw, monitors) {
  var entries = normalize(raw)
  var live = monitors || []
  var result = {
    byConnector: {},
    owner: {},
    reserved: {},
    home: {},
    rows: []
  }
  var groups = []

  for (var i = 0; i < entries.length; i++) {
    var found = -1
    for (var g = 0; g < groups.length; g++) {
      if (matches(entries[i], groups[g].sample)) {
        found = g
        break
      }
    }
    if (found === -1) {
      groups.push({ sample: { description: entries[i].model, serial: entries[i].serial }, entries: [entries[i]], monitors: [] })
    } else {
      groups[found].entries.push(entries[i])
    }
  }

  for (var m = 0; m < live.length; m++) {
    var monitor = live[m]
    if (!monitor || !monitor.name) continue
    for (var k = 0; k < groups.length; k++) {
      if (matches(groups[k].entries[0], monitor)) {
        groups[k].monitors.push(monitor)
        break
      }
    }
  }

  for (var n = 0; n < groups.length; n++) {
    var group = groups[n]
    if (group.entries.length === 1 && group.monitors.length === 1) {
      bind(result, group.entries[0], group.monitors[0])
      group.entries[0].bound = true
      continue
    }
    var used = {}
    for (var e = 0; e < group.entries.length; e++) {
      var entry = group.entries[e]
      if (!entry.connector) continue
      for (var c = 0; c < group.monitors.length; c++) {
        var candidate = group.monitors[c]
        if (used[candidate.name] || candidate.name !== entry.connector) continue
        bind(result, entry, candidate)
        used[candidate.name] = true
        entry.bound = true
        break
      }
    }
  }

  for (var s = 0; s < entries.length; s++) {
    reserve(result, entries[s])
  }
  return result
}
