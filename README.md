# pi-subagent-pixcopy

把 pi code（`npm:pi-code`）的 subagent 模型统一指向 **pix-copy 供应商的 `deepseek-v4.1-flash`**。

## 背景

pi-code 的 subagent 扩展（`extensions/subagent`）为每个 agent 启动一个独立 `pi` 子进程。子进程的模型选择顺序（`extensions/subagent/child.ts:165`）：

```
agent frontmatter model  >  Claude tier 别名解析  >  CLAUDE_CODE_SUBAGENT_MODEL  >  会话默认模型
```

两个关键陷阱：

1. **builtin `Explore` / `Plan` 豁免环境变量**
   `child.ts` 里 `exemptFromEnvModel = agent.source === 'builtin' && (name === 'Explore' || name === 'Plan')`，
   所以单设 `CLAUDE_CODE_SUBAGENT_MODEL` 对它们无效，会退回会话默认模型（本机是 anthropic，直接 401）。
2. **同名用户级 agent 覆盖 builtin**
   `~/.pi/agent/agents/*.md` 与 builtin 同名时，用户级胜出（`agents.ts` 的 `buildAgentMap`）。
   一旦 `source` 变成 `user`，豁免失效，frontmatter 的 `model` 与 `CLAUDE_CODE_SUBAGENT_MODEL` 都会生效。

## 本仓库内容

`agents/` 下三个与 builtin 同名的 agent 定义，均固定 `model: pix-copy/deepseek-v4.1-flash`：

| 文件 | name | tools |
|---|---|---|
| `agents/Explore.md` | `Explore` | read, grep, find, ls |
| `agents/Plan.md` | `Plan` | read, grep, find, ls |
| `agents/general-purpose.md` | `general-purpose` | 默认全量 |

## 安装

```bash
mkdir -p ~/.pi/agent/agents
cp agents/*.md ~/.pi/agent/agents/
```

可选（给未固定 model 的 agent 兜底）——在 `~/.claude/settings.json` 的 `env` 中加：

```json
{ "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "pix-copy/deepseek-v4.1-flash" } }
```

前提：`~/.pi/agent/models.json` 中已有 `pix-copy` 供应商及其 `deepseek-v4.1-flash` 模型。

## 验证

```bash
pi --list-models | grep pix-copy
```

用 JSON 模式跑一次，检查子代理实际使用的模型：

```bash
pi --mode json --no-session --model "bl-copy/deepseek-v4.1-flash" \
  "用 subagent 并行模式跑 3 个任务：Explore 列目录、Plan 给一句话方案、general-purpose 执行 bash echo \$PI_PROVIDER \$PI_MODEL"
```

观察 `tool_execution_end` 事件里 `details.results[].model`，应全部为
`pix-copy/deepseek-v4.1-flash`，且 `agentSource` 为 `user`。

实测输出（2026年10月28日）：

```
mode: parallel
 - Explore           | source= user | model= pix-copy/deepseek-v4.1-flash | exit= 0 | turns= 2
 - Plan              | source= user | model= pix-copy/deepseek-v4.1-flash | exit= 0 | turns= 3
 - general-purpose   | source= user | model= pix-copy/deepseek-v4.1-flash | exit= 0 | turns= 2
```

链式模式同样通过：

```
mode: chain
 - Explore | model= pix-copy/deepseek-v4.1-flash | exit= 0
 - Plan    | model= pix-copy/deepseek-v4.1-flash | exit= 0
```

## 注意

- 只覆盖 `Explore` / `Plan` / `general-purpose` 三个 agent；项目级 `.pi/agents/*.md` 会按需再覆盖同名项。
- `pix-copy` 的 `apiKey` 与 `baseUrl` 属于本地私密配置，本仓库不含任何密钥。
- 想改用别的供应商，把三个文件里的 `model:` 换成 `provider/model-id` 即可。
