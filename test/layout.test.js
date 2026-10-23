const fs = require("fs")
const path = require("path")

const root = path.join(__dirname, "..")
const src = fs.readFileSync(path.join(root, "Layout.js"), "utf8")
const api = new Function(src + "\nreturn { assign, normalize }")()

let failed = 0
function check(condition, message) {
  if (condition) {
    console.log("ok", message)
    return
  }
  failed += 1
  console.error("FAIL", message)
}

const layout = {
  screens: [
    {
      model: "Wide",
      serial: "0000000000000",
      home: "web",
      workspaces: [
        { name: "web", key: "code:87" },
        { name: "extra", key: "code:10" }
      ]
    },
    {
      model: "Tall",
      serial: "SERIAL123",
      home: "chat",
      workspaces: [{ name: "chat", key: "code:88" }]
    },
    {
      model: "Hero",
      serial: "0000000000000",
      home: "ui",
      workspaces: [
        { name: "ui", key: "code:81" },
        { name: "term", key: "code:90" }
      ]
    }
  ]
}

const live = [
  { name: "DP-2", description: "Maker Wide 0000000000000", serial: "0000000000000" },
  { name: "DP-9", description: "Maker Hero 0000000000000", serial: "0000000000000" },
  { name: "HDMI-A-1", description: "Maker Tall SERIAL123", serial: "SERIAL123" }
]

const placed = api.assign(layout, live)
check(placed.owner.term === "DP-9", "a renamed port still receives the matching panel")
check(placed.owner.web === "DP-2", "blank serials stay apart when the model differs")
check(placed.owner.chat === "HDMI-A-1", "a real serial stays on its panel")
check(placed.byConnector["DP-9"].join(",") === "ui,term", "names on one panel stay together")

const unplugged = api.assign(layout, live.filter((monitor) => monitor.name !== "HDMI-A-1"))
check(unplugged.owner.chat === undefined, "an unplugged panel does not claim a port")
check(unplugged.reserved.chat === true, "an unplugged name stays reserved")
check(unplugged.owner.term === "DP-9", "the other panels keep their names")

const unknown = api.assign(layout, live.concat([{ name: "DP-4", description: "Dell U2720Q ABC123", serial: "ABC123" }]))
check(!unknown.byConnector["DP-4"], "an unknown monitor gets no pinned names")

const twins = {
  screens: [
    { model: "Same", serial: "0", connector: "DP-1", home: "a", workspaces: [{ name: "a", key: "1" }] },
    { model: "Same", serial: "0", home: "b", workspaces: [{ name: "b", key: "2" }] }
  ]
}
const hinted = api.assign(twins, [
  { name: "DP-7", description: "Vendor Same 000", serial: "000" },
  { name: "DP-1", description: "Vendor Same 000", serial: "000" }
])
check(hinted.owner.a === "DP-1", "a recorded connector breaks an identical-panel tie")
check(hinted.owner.b === undefined, "the other identical panel is not guessed")

const duplicate = api.normalize({
  screens: [
    { model: "M", serial: "1", workspaces: ["one", "one", "two"] },
    { model: "N", serial: "2", workspaces: ["two", "three"] }
  ]
})
check(duplicate[0].names.join(",") === "one,two" && duplicate[1].names.join(",") === "three", "a name belongs to one screen")

const example = JSON.parse(fs.readFileSync(path.join(root, "layout.example.json"), "utf8"))
const examplePlan = api.assign(example, [{ name: "DP-1", description: "Example Maker Panel SERIAL", serial: "SERIAL" }])
check(examplePlan.owner.main === "DP-1" && examplePlan.home["DP-1"] === "main", "the example layout binds its home workspace")

if (failed) {
  console.error(failed + " failed")
  process.exit(1)
}
console.log("passed")
