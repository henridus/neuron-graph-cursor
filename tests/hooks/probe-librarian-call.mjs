// Sonde ciblee: appelle un outil librarian arbitraire.
// Usage: node probe-librarian-call.mjs <toolName> <jsonArgs>
import { spawn } from "node:child_process";

const EXE = "C:\\Users\\henri\\AppData\\Local\\librarian-mcp\\librarian-mcp.exe";
const VAULT = "C:\\Users\\henri\\OneDrive\\Obsidian\\AgentMemory";
const tool = process.argv[2];
const args = process.argv[3] ? JSON.parse(process.argv[3]) : {};

const child = spawn(EXE, [VAULT], { stdio: ["pipe", "pipe", "pipe"] });
let buf = "";
const pending = new Map();
let nextId = 1;

function send(method, params, notif = false) {
  const msg = { jsonrpc: "2.0", method, ...(params ? { params } : {}) };
  if (!notif) {
    const id = nextId++;
    msg.id = id;
    return new Promise((r) => { pending.set(id, r); child.stdin.write(JSON.stringify(msg) + "\n"); });
  }
  child.stdin.write(JSON.stringify(msg) + "\n");
  return Promise.resolve();
}
child.stdout.on("data", (c) => {
  buf += c.toString();
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const l = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!l) continue;
    let o; try { o = JSON.parse(l); } catch { continue; }
    if (o.id && pending.has(o.id)) { pending.get(o.id)(o); pending.delete(o.id); }
  }
});
child.stderr.on("data", () => {});
const textOf = (r) => { try { return r.result.content.map((c) => c.text).join("\n"); } catch { return JSON.stringify(r.result ?? r.error); } };

const main = async () => {
  await send("initialize", { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "probe", version: "1.0" } });
  await send("notifications/initialized", null, true);
  const res = await send("tools/call", { name: tool, arguments: args });
  console.log(textOf(res));
  child.kill(); process.exit(0);
};
setTimeout(() => { console.error("TIMEOUT"); child.kill(); process.exit(1); }, 30000);
main().catch((e) => { console.error(e); child.kill(); process.exit(1); });
