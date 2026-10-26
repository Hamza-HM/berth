const fs = require("fs")
const path = require("path")

function load(file, names) {
  const src = fs.readFileSync(path.join(__dirname, "..", file), "utf8")
  return new Function(src + "\nreturn { " + names.join(", ") + " }")()
}

const layout = load("Layout.js", ["matches", "normalize"])
const setup = load("Setup.js", ["draft", "save", "addWorkspace", "removeWorkspace", "setHome", "rowKey", "keyLabel", "keyFromScan", "setRowKey", "bindingsInstalled", "withBindings"])

let failed = 0
function check(condition, message) {
  if (condition) {
    console.log("ok", message)
    return
  }
  failed += 1
  console.error("FAIL", message)
}

const stored = layout.normalize({
  screens: [
    { model: "Wide", serial: "000", home: "web", workspaces: [{ name: "web", key: "code:87" }, { name: "extra", key: "" }] },
    { model: "Tall", serial: "SERIAL", home: "chat", workspaces: [{ name: "chat", key: "code:88" }] }
  ]
})
const monitors = [
  { name: "DP-2", model: "Wide", description: "Maker Wide 000", serial: "000", x: 100, y: 0 },
  { name: "HDMI-A-1", model: "Tall", description: "Maker Tall SERIAL", serial: "SERIAL", x: 0, y: 0 }
]
const sections = setup.draft(stored, monitors, layout.matches)
check(sections[0].model === "Tall" && sections[0].workspaces[0].name === "chat", "screens are ordered from left to right")
check(sections[1].workspaces.map((row) => row.name).join(",") === "web,extra", "a matched screen keeps its names")
check(!sections[1].twin, "different models are not treated as a pair")

const added = setup.addWorkspace(sections, 1)
check(added[1].workspaces.length === 3 && added[1].workspaces[2].name === "", "a screen can grow by one row")
const homed = setup.setHome(added, 1, 1)
const removed = setup.removeWorkspace(homed, 1, 0)
check(removed[1].homeIndex === 0 && removed[1].workspaces[0].name === "extra", "removing a row keeps home on the name that remains")

homed[1].workspaces[1].name = "api"
homed[1].workspaces[2].name = "notes"
const saved = setup.save(homed, stored, monitors, layout.matches)
check(saved.ok && saved.layout.screens.filter((screen) => screen.model === "Wide")[0].home === "api", "renaming the home row keeps that row as home")
const wide = saved.layout.screens.filter((screen) => screen.model === "Wide")[0]
check(saved.ok && wide.workspaces[1].key === "code:89" && wide.workspaces[2].key === "code:83", "new names receive the next free numpad keys")
check(wide.workspaces[0].key === "code:87", "an existing key stays where it was")

const unplugged = setup.save(sections.filter((section) => section.model === "Wide"), stored, monitors.filter((monitor) => monitor.name === "DP-2"), layout.matches)
const kept = unplugged.layout.screens.map((screen) => screen.model).sort().join(",")
check(unplugged.ok && kept === "Tall,Wide", "a screen that is unplugged keeps its names")

const twins = setup.draft(stored, [
  { name: "DP-7", model: "Wide", description: "Maker Wide 000", serial: "000", x: 0, y: 0 },
  { name: "DP-8", model: "Wide", description: "Maker Wide 000", serial: "000", x: 10, y: 0 }
], layout.matches)
check(twins[0].twin && twins[0].workspaces.length === 1 && twins[0].workspaces[0].name === "", "identical screens are not guessed")
const untouched = setup.save(twins, stored, [
  { name: "DP-7", model: "Wide", description: "Maker Wide 000", serial: "000" },
  { name: "DP-8", model: "Wide", description: "Maker Wide 000", serial: "000" }
], layout.matches)
check(untouched.layout.screens.some((screen) => screen.model === "Wide"), "saving before a pair is chosen does not drop the old names")

const clash = setup.save([
  { connector: "DP-2", model: "Wide", serial: "000", twin: false, bound: true, home: "web", workspaces: [{ name: "web", key: "code:87" }] },
  { connector: "HDMI-A-1", model: "Tall", serial: "SERIAL", twin: false, bound: true, home: "web", workspaces: [{ name: "web", key: "" }] }
], [], monitors, layout.matches)
check(!clash.ok && clash.message.indexOf("web") === 0, "a repeated name is refused")

check(setup.rowKey(homed, 1, 1) === "code:89", "a new name shows the key it will receive")
check(setup.keyFromScan(10, 49) === "code:10", "the number row is stored as a Hyprland keycode")
check(setup.keyFromScan(87, 0) === "code:87", "the numpad is stored as a Hyprland keycode")
check(setup.keyFromScan(86, 43) === "code:86" && setup.keyLabel("code:86") === "Numpad +", "numpad plus is stored as code 86")
check(setup.keyFromScan(42, 16777248) === "", "a modifier by itself is not a shortcut")
const keyed = setup.setRowKey(homed, 1, 1, "code:20")
check(keyed.ok && keyed.sections[1].workspaces[1].key === "code:20", "a row can take a new key")
const clashKey = setup.setRowKey(keyed.sections, 1, 2, "code:87")
check(!clashKey.ok, "a key already used by another workspace is refused")
check(setup.keyLabel("code:87") === "Numpad 1" && setup.keyLabel("code:38") === "A" && setup.keyLabel("") === "Click only", "keys are shown as numpad labels")
check(!setup.bindingsInstalled("hl.unbind()") && setup.bindingsInstalled(setup.withBindings("")), "the keybinding line is added once")
check(setup.withBindings(setup.withBindings("keep\n")).split("hyprland.lua").length === 2, "a second save does not add the line again")

if (failed) {
  console.error(failed + " failed")
  process.exit(1)
}
console.log("passed")
