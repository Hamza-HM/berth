// Draft and save for the setup panel. Keys are filled in numpad order.
// A name past the tenth workspace stays on the bar and has no key.

var numpadKeys = [
  { key: "code:87", label: "Numpad 1" },
  { key: "code:88", label: "Numpad 2" },
  { key: "code:89", label: "Numpad 3" },
  { key: "code:83", label: "Numpad 4" },
  { key: "code:84", label: "Numpad 5" },
  { key: "code:85", label: "Numpad 6" },
  { key: "code:79", label: "Numpad 7" },
  { key: "code:80", label: "Numpad 8" },
  { key: "code:81", label: "Numpad 9" },
  { key: "code:90", label: "Numpad 0" }
]

var bindingsLine = "dofile((os.getenv(\"HOME\") or \"\") .. \"/.config/omarchy/plugins/hamza.berth/hyprland.lua\")"

// Qt's nativeScanCode is already the Hyprland code: number. Do not add 8.
var modifierKeys = {
  16777248: true,
  16777249: true,
  16777250: true,
  16777251: true,
  16777252: true,
  16777253: true,
  16777254: true,
  16777299: true,
  16777300: true,
  16781571: true
}

function keyFromScan(scan, qtKey) {
  if (modifierKeys[qtKey]) return ""
  var code = Number(scan)
  if (!isFinite(code) || code <= 0) return ""
  return "code:" + code
}

function setRowKey(sections, sectionIndex, rowIndex, key) {
  var wanted = String(key || "")
  if (!wanted) return { ok: false, message: "Press a key." }
  for (var s = 0; s < (sections || []).length; s++) {
    var rows = sections[s].workspaces || []
    for (var r = 0; r < rows.length; r++) {
      if (s === sectionIndex && r === rowIndex) continue
      if (String(rows[r].key || "") !== wanted) continue
      var name = String(rows[r].name || "").trim() || "another workspace"
      return { ok: false, message: keyLabel(wanted) + " is already used by " + name + "." }
    }
  }
  var next = []
  for (var i = 0; i < sections.length; i++) next.push(copySection(sections[i]))
  if (!next[sectionIndex] || !next[sectionIndex].workspaces[rowIndex]) return { ok: false, message: "That row is gone." }
  next[sectionIndex].workspaces[rowIndex].key = wanted
  return { ok: true, sections: next }
}

var keyNames = {
  "code:10": "1", "code:11": "2", "code:12": "3", "code:13": "4", "code:14": "5",
  "code:15": "6", "code:16": "7", "code:17": "8", "code:18": "9", "code:19": "0",
  "code:24": "Q", "code:25": "W", "code:26": "E", "code:27": "R", "code:28": "T",
  "code:29": "Y", "code:30": "U", "code:31": "I", "code:32": "O", "code:33": "P",
  "code:38": "A", "code:39": "S", "code:40": "D", "code:41": "F", "code:42": "G",
  "code:43": "H", "code:44": "J", "code:45": "K", "code:46": "L",
  "code:52": "Z", "code:53": "X", "code:54": "C", "code:55": "V", "code:56": "B",
  "code:57": "N", "code:58": "M",
  "code:65": "Space", "code:36": "Enter", "code:22": "Backspace", "code:23": "Tab",
  "code:86": "Numpad +", "code:82": "Numpad -", "code:63": "Numpad *", "code:106": "Numpad /",
  "code:104": "Numpad Enter", "code:91": "Numpad ."
}

function keyLabel(key) {
  var value = String(key || "")
  for (var i = 0; i < numpadKeys.length; i++) {
    if (numpadKeys[i].key === value) return numpadKeys[i].label
  }
  if (keyNames[value]) return keyNames[value]
  return value ? value : "Click only"
}

function bindingsInstalled(text) {
  return String(text || "").indexOf("plugins/hamza.berth/hyprland.lua") !== -1
}

function withBindings(text) {
  if (bindingsInstalled(text)) return String(text || "")
  var base = String(text || "")
  if (base && base.charAt(base.length - 1) !== "\n") base += "\n"
  return base + "\n-- Berth. The plugin owns the workspace rules and keys.\n" + bindingsLine + "\n"
}

function copySection(section) {
  var workspaces = []
  var rows = section && section.workspaces ? section.workspaces : []
  for (var i = 0; i < rows.length; i++) {
    workspaces.push({ name: String(rows[i].name || ""), key: String(rows[i].key || "") })
  }
  return {
    connector: String(section.connector || ""),
    model: String(section.model || ""),
    serial: String(section.serial || ""),
    make: String(section.make || ""),
    twin: !!section.twin,
    bound: !!section.bound,
    homeIndex: Math.max(0, Number(section.homeIndex) || 0),
    workspaces: workspaces
  }
}

function hardwareMatch(entry, monitor, matches) {
  var description = String(monitor.description || "")
  if (!description) description = [monitor.make, monitor.model, monitor.serial].join(" ")
  return matches(entry, { description: description, serial: String(monitor.serial || "") })
}

function draft(entries, monitors, matches) {
  var live = (monitors || []).slice().sort(function(a, b) {
    return (Number(a.x) || 0) - (Number(b.x) || 0) || (Number(a.y) || 0) - (Number(b.y) || 0)
  })
  var sections = []
  for (var i = 0; i < live.length; i++) {
    var monitor = live[i]
    var group = []
    for (var e = 0; e < (entries || []).length; e++) {
      if (hardwareMatch(entries[e], monitor, matches)) group.push(entries[e])
    }
    var twin = false
    for (var n = 0; n < live.length; n++) {
      if (n !== i && hardwareMatch(group[0] || { model: monitor.model, serial: monitor.serial }, live[n], matches)) twin = true
    }
    if (!group.length) {
      for (var t = 0; t < live.length; t++) {
        if (t !== i && String(live[t].model || "") === String(monitor.model || "") && String(live[t].serial || "") === String(monitor.serial || "") && String(monitor.model || "")) twin = true
      }
    }
    var entry = null
    if (!twin && group.length === 1) entry = group[0]
    else {
      for (var g = 0; g < group.length; g++) {
        if (group[g].connector && group[g].connector === monitor.name) {
          entry = group[g]
          break
        }
      }
    }
    var workspaces = []
    var homeIndex = 0
    if (entry) {
      for (var w = 0; w < entry.names.length; w++) {
        workspaces.push({ name: entry.names[w], key: entry.keys[w] || "" })
        if (entry.names[w] === entry.home) homeIndex = w
      }
    }
    if (!workspaces.length) workspaces.push({ name: "", key: "" })
    sections.push({
      connector: String(monitor.name || ""),
      model: entry ? entry.model : String(monitor.model || ""),
      serial: String(monitor.serial || ""),
      make: entry ? entry.make : String(monitor.make || ""),
      twin: twin,
      bound: !!entry,
      homeIndex: homeIndex,
      workspaces: workspaces
    })
  }
  return sections
}

function addWorkspace(sections, index) {
  var next = []
  for (var i = 0; i < sections.length; i++) next.push(copySection(sections[i]))
  if (!next[index]) return next
  next[index].workspaces.push({ name: "", key: "" })
  return next
}

function removeWorkspace(sections, sectionIndex, rowIndex) {
  var next = []
  for (var i = 0; i < sections.length; i++) next.push(copySection(sections[i]))
  var section = next[sectionIndex]
  if (!section || !section.workspaces[rowIndex]) return next
  var homeIndex = section.homeIndex
  section.workspaces.splice(rowIndex, 1)
  if (homeIndex === rowIndex) section.homeIndex = 0
  else if (homeIndex > rowIndex) section.homeIndex = homeIndex - 1
  return next
}

function setHome(sections, sectionIndex, rowIndex) {
  var next = []
  for (var i = 0; i < sections.length; i++) next.push(copySection(sections[i]))
  if (!next[sectionIndex]) return next
  next[sectionIndex].homeIndex = Math.max(0, Number(rowIndex) || 0)
  return next
}

function freeNumpad(used) {
  var pool = []
  for (var k = 0; k < numpadKeys.length; k++) {
    if (!used[numpadKeys[k].key]) pool.push(numpadKeys[k].key)
  }
  return pool
}

function rowKey(sections, sectionIndex, rowIndex) {
  var used = {}
  var plan = []
  for (var s = 0; s < (sections || []).length; s++) {
    var rows = sections[s].workspaces || []
    for (var r = 0; r < rows.length; r++) {
      if (!String(rows[r].name || "").trim()) continue
      var key = String(rows[r].key || "")
      if (key) used[key] = true
      plan.push({ s: s, r: r, key: key })
    }
  }
  var pool = freeNumpad(used)
  var cursor = 0
  for (var i = 0; i < plan.length; i++) {
    var item = plan[i]
    var assigned = item.key || (cursor < pool.length ? pool[cursor++] : "")
    if (item.s === sectionIndex && item.r === rowIndex) return assigned
  }
  return ""
}

function screenFromEntry(entry) {
  var workspaces = []
  for (var i = 0; i < entry.names.length; i++) {
    var row = { name: entry.names[i] }
    if (entry.keys[i]) row.key = entry.keys[i]
    workspaces.push(row)
  }
  var screen = {
    make: entry.make,
    model: entry.model,
    serial: entry.serial,
    home: entry.home,
    workspaces: workspaces
  }
  if (entry.connector) screen.connector = entry.connector
  return screen
}

function fillKeys(screens) {
  var used = {}
  for (var s = 0; s < screens.length; s++) {
    var rows = screens[s].workspaces
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].key) used[rows[i].key] = true
    }
  }
  var pool = freeNumpad(used)
  var cursor = 0
  for (var n = 0; n < screens.length; n++) {
    var list = screens[n].workspaces
    for (var r = 0; r < list.length; r++) {
      if (list[r].key) continue
      list[r].key = cursor < pool.length ? pool[cursor++] : ""
    }
  }
  return screens
}

function save(sections, previousEntries, monitors, matches) {
  var screens = []
  var seen = {}
  var duplicate = ""
  for (var i = 0; i < (sections || []).length; i++) {
    var section = sections[i]
    var rows = []
    var source = section.workspaces || []
    for (var r = 0; r < source.length; r++) {
      var name = String(source[r].name || "").trim()
      if (!name) continue
      if (seen[name]) duplicate = name
      seen[name] = true
      var row = { name: name }
      if (source[r].key) row.key = String(source[r].key)
      rows.push(row)
    }
    if (!rows.length) continue
    var preferred = ""
    if (typeof section.homeIndex === "number" && source[section.homeIndex]) {
      preferred = String(source[section.homeIndex].name || "").trim()
    } else {
      preferred = String(section.home || "").trim()
    }
    var homeFound = false
    for (var h = 0; h < rows.length; h++) if (rows[h].name === preferred) homeFound = true
    var screen = {
      make: String(section.make || ""),
      model: String(section.model || ""),
      serial: String(section.serial || ""),
      home: homeFound ? preferred : rows[0].name,
      workspaces: rows
    }
    if (section.twin) screen.connector = String(section.connector || "")
    screens.push(screen)
  }

  for (var p = 0; p < (previousEntries || []).length; p++) {
    var entry = previousEntries[p]
    var covered = false
    for (var m = 0; m < (monitors || []).length; m++) {
      if (!hardwareMatch(entry, monitors[m], matches)) continue
      for (var s = 0; s < (sections || []).length; s++) {
        var edited = sections[s]
        if (String(edited.connector || "") !== String(monitors[m].name || "")) continue
        var typed = false
        var editedRows = edited.workspaces || []
        for (var er = 0; er < editedRows.length; er++) {
          if (String(editedRows[er].name || "").trim()) typed = true
        }
        if (edited.bound || typed) covered = true
      }
    }
    if (covered) continue
    for (var u = 0; u < entry.names.length; u++) {
      if (seen[entry.names[u]]) duplicate = entry.names[u]
      seen[entry.names[u]] = true
    }
    screens.push(screenFromEntry(entry))
  }

  if (duplicate) return { ok: false, message: duplicate + " is used more than once." }
  return { ok: true, layout: { screens: fillKeys(screens) } }
}
