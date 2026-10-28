#!/usr/bin/env bash
# 验证 pi subagent 是否运行在 pix-copy/deepseek-v4.1-flash 上
set -u
OUT="$(mktemp -t pi-subagent-verify-XXXXXX.jsonl)"

pi --mode json --no-session --model "bl-copy/deepseek-v4.1-flash" \
  "用 subagent 并行模式跑 3 个任务：1) agent=Explore, task=列出 ~/.pi/agent/agents 目录下的文件名；2) agent=Plan, task=用一句话说明 pi agent frontmatter 里 model 字段的作用；3) agent=general-purpose, task=执行 bash: echo PROVIDER=\$PI_PROVIDER MODEL=\$PI_MODEL 并原样返回" \
  > "$OUT" 2>&1

node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n");
let found = false;
for (const line of lines) {
  let e; try { e = JSON.parse(line) } catch { continue }
  if (e.type !== "tool_execution_end" || e.toolName !== "subagent") continue;
  found = true;
  const d = e.result.details;
  console.log("mode:", d.mode);
  for (const r of d.results) console.log(" -", r.agent, "| source=", r.agentSource, "| model=", r.model, "| exit=", r.exitCode);
}
if (!found) { console.error("未捕获到 subagent 调用事件"); process.exit(1) }
' "$OUT"
