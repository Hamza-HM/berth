const fs = require("fs")
const path = require("path")

const src = fs.readFileSync(path.join(__dirname, "..", "Clients.js"), "utf8")
const api = new Function(src + "\nreturn { normalizeAddress, note, drop, count, fromHyprctl, mergeSeed, applyEvent }")()

let failed = 0
function check(condition, message) {
  if (condition) {
    console.log("ok", message)
    return
  }
  failed += 1
  console.error("FAIL", message)
}

check(api.normalizeAddress("0xABC") === "abc", "addresses compare without the 0x prefix")

let clients = api.note({}, "0x10", "term")
clients = api.applyEvent(clients, "movewindowv2", ["0x10", "4", "web"])
check(api.count(clients, "web") === 1 && api.count(clients, "term") === 0, "a move updates the workspace")

clients = api.drop(clients, "10")
check(api.count(clients, "web") === 0, "a close removes the window")

const seeded = api.fromHyprctl([
  { address: "0x1", mapped: true, workspace: { name: "chat" } },
  { address: "0x2", mapped: false, workspace: { name: "chat" } },
  { address: "0x3", mapped: true, workspace: { name: "special:scratch" } }
])
check(api.count(seeded, "chat") === 1, "the startup snapshot skips unmapped and special workspaces")

const merged = api.mergeSeed({ aa: "dev" }, { aa: "chat", bb: "web" }, { bb: true })
check(merged.aa === "dev" && merged.bb === undefined, "events during the snapshot win, and a close is not restored")

if (failed) {
  console.error(failed + " failed")
  process.exit(1)
}
console.log("passed")
