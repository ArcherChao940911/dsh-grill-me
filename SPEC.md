# dsh-grill 插件实现规格说明书（SPEC）

| 项 | 值 |
| --- | --- |
| 文档版本 | v1.0 |
| 状态 | 待开发（Ready for Development） |
| 目标 | 为 DeepSeek Harness（dsh）开发插件，使其具备「grill」能力 |
| 上游来源 | [mattpocock/skills](https://github.com/mattpocock/skills) |
| 依赖框架 | dsh / Cordis（`@deepseek-ai/cordis`） |

---

## 1. 概述（Overview）

本规格定义如何把 mattpocock/skills 仓库中的 **grill 家族**能力移植到 dsh（DeepSeek Harness），以插件形式交付。

「grill」是一套**面试式需求澄清技术**：agent 把你的想法建模成一棵决策树，按「前沿（frontier）→ 轮次（round）」的方式逐轮追问，直到你与 agent 对目标达成共识、且没有遗留的隐性假设。

交付物是一个可分发、可 hack 的 dsh 插件，注册 4 个 skill：

| Skill | 分类 | 调用方式 | 职责 |
| --- | --- | --- | --- |
| `grilling` | 核心 primitive | model + user | 面试循环本体 |
| `grill-me` | 入口 | user-only | 无状态入口，委托 `grilling` |
| `grill-with-docs` | 入口 | user-only | 有状态入口，委托 `grilling` + `domain-modeling`，写 `CONTEXT.md` 和 ADR |
| `domain-modeling` | 依赖 | model + user | 领域模型写作纪律 |

---

## 2. 目标与非目标

### 2.1 目标（In scope）

1. dsh 用户可通过 `/grill-me`、`/grill-with-docs` 触发面试。
2. dsh 模型在任务合适时可自动触发 `grilling`（model-invocable）。
3. `grill-with-docs` 能在面试中实时写入 `CONTEXT.md`（术语表）与 `docs/adr/`（ADR）。
4. 插件可分发、可本地 hack（skill 正文是普通 Markdown 文件）。

### 2.2 非目标（Out of scope，本期不做）

- `wayfinder` / `to-spec` / `to-tickets` / `triage` 等依赖 grilling 的上游 skill（后续按需）。
- 修改 dsh 内核或 skill provider 的发现逻辑。
- 多 context 仓库的 `CONTEXT-MAP.md` 高级布局（由 `domain-modeling` 正文覆盖，但本期不专项实现）。
- 官方 docs 提到的「skill 调 skill 可能不加载」的框架级修复（本期以兜底方案规避，见 §10）。

---

## 3. 背景知识

### 3.1 grill 机制（来自 mattpocock/skills）

三个核心概念：

- **Design tree（设计树）**：把主题建模成决策树，每个决策分支出挂在它下面的子决策。
- **Frontier（前沿）**：所有「前置条件已解决」的决策集合，即此刻唯一能诚实提问的问题。
- **Round（轮次）**：一轮 = 一次性问完整个 frontier，等用户答完再进入下一轮。

每轮提问格式固定：

```
❓ **Q1** - **<问题标题>**: <问题正文，可能多段，含多个选项>

➡️ <你的推荐答案>

---

❓ **Q2** - **<问题标题>**: <问题正文>

➡️ <你的推荐答案>
```

**事实 vs 决策分工（最关键规则）**：

- **事实（facts）是 agent 的活**：需要查文件/工具才知道的东西，派 sub-agent 去查，绝不问用户。不阻塞——只有依赖该调查的问题才等待，其余照常提问。
- **决策（decisions）是用户的活**：必须逐条抛给用户并等待。agent 替用户做决策 = 违反 skill。

**结束条件**：frontier 清空（每个分支都访问过），且**用户确认达成共识**之后才允许行动。

### 3.2 dsh 的 skills 子系统（已核对官方文档）

- 一切皆插件（Cordis）。插件是导出 `apply(ctx)`、`name`、可选 `inject` 的 TS 模块。
- skills 服务：包名 `dsh-skill`，通过 `ctx.skills` 访问。
- 注册方法：`ctx.skills.register(skill: SkillRegistration): () => void`（返回 disposer）。
- 模型可调用的工具：`skill({ name })`，加载完整 skill 正文返回给模型。
- 本地 provider 扫描目录（rank 从高到低）：

| rank | 来源 | 根目录 |
| --- | --- | --- |
| 100 | project-dsh | `<projectRoot>/.dsh/skills` |
| 200 | project-agents | `<projectRoot>/.agents/skills` |
| 300 | custom | `Config.customSkillDirs` |
| 400 | user-dsh | `<dshHome>/skills` |
| 500 | user-agents | `<agentsHome>/skills` |
| 600 | bundled | `Config.bundledSkillDir`（配置后） |

- 本地 provider 接受的目录形态：`<name>/SKILL.md`（目录 bundle）或 `<name>.md`（扁平文件）；**不支持递归 `**/SKILL.md`**。
- 名称约束：kebab-case `^[a-z0-9]+(?:-[a-z0-9]+)*$`。

---

## 4. 需求

### 4.1 功能需求（FR）

- **FR-1** 插件加载后，`ctx.skills` 目录中出现 `grilling`、`grill-me`、`grill-with-docs`、`domain-modeling` 四个 skill。
- **FR-2** `grilling` 与 `domain-modeling` 的 `modelInvocable=true`、`userInvocable=true`。
- **FR-3** `grill-me` 与 `grill-with-docs` 的 `modelInvocable=false`、`userInvocable=true`。
- **FR-4** 用户输入 `/grill-me` 后，模型按 grilling 的格式（❓ + ➡️ + `---` 分隔）发起面试。
- **FR-5** 用户输入 `/grill-with-docs` 后，模型在面试中把术语写入 `CONTEXT.md`、把符合条件的决策写入 `docs/adr/`。
- **FR-6** 面试期间，可查的事实由 agent 自行查证（读文件/sub-agent），不向用户提问。

### 4.2 非功能需求（NFR）

- **NFR-1** 插件为 TS 模块，符合 Cordis 插件规范（`apply`/`inject`/`name`）。
- **NFR-2** skill 正文以 Markdown 文件独立存放，便于 hack（符合 mattpocock「make them your own」理念）。
- **NFR-3** 插件卸载时正确清理注册（依赖框架自动 disposer，无泄漏）。
- **NFR-4** 兼容本地/workspace 插件加载（run-from-source 流程）。

---

## 5. 架构设计

```
┌─────────────────────────────────────────────────────┐
│ dsh (Cordis)                                        │
│                                                     │
│   ┌──────────────┐        ┌───────────────────────┐ │
│   │ dsh-grill 插件│  apply  │ ctx.skills (registry) │ │
│   │ src/index.ts │ ──────▶ │  register() ×4        │ │
│   └──────────────┘        └──────────┬────────────┘ │
│        │ 读取                          │ 目录快照      │
│        ▼                              ▼              │
│   skills/*/SKILL.md        dsh-tool-skill (skill 工具)│
│   (4 个 Markdown 正文)        └─▶ 模型按需加载正文     │
└─────────────────────────────────────────────────────┘
```

**数据流**：

1. 插件 `apply` 阶段，同步读取 `skills/<name>/SKILL.md`，解析 YAML frontmatter + 正文。
2. 对每个 skill 调 `ctx.skills.register({...})`，把 `disable-model-invocation` 映射为 `invocation.modelInvocable`。
3. dsh 的 skill 工具在模型侧暴露 `skill({name})`；用户侧暴露 `/grill-me`、`/grill-with-docs` 命令。
4. `grill-me`/`grill-with-docs` 的正文是「调用 grilling(/domain-modeling)」的委托指令，模型执行时经 `skill` 工具加载真正的面试正文。

---

## 6. 详细设计

### 6.1 数据结构（SkillRegistration 字段映射）

| SkillRegistration 字段 | 来源 | 说明 |
| --- | --- | --- |
| `name` | frontmatter `name` | kebab-case |
| `description` | frontmatter `description` | 路由描述，模型目录只展示 name+description |
| `content` | 正文（去 frontmatter） | 指令正文 |
| `source` | 常量 `'runtime'` | 官方 `SkillSource` 允许 `'runtime'` |
| `invocation.modelInvocable` | `!disable-model-invocation` | 缺省 true |
| `invocation.userInvocable` | 常量 `true` | 四个 skill 均对用户可见 |

### 6.2 frontmatter → 调用策略映射

| frontmatter | modelInvocable | userInvocable |
| --- | --- | --- |
| 无 `disable-model-invocation` | true | true |
| `disable-model-invocation: true` | false | true |

> 注：dsh 本地 provider 的 kebab-case 键为 `disable-model-invocation` 与 `user-invocable`；本插件走 `ctx.skills.register` 运行时注册，直接给归一化后的 `invocation` 对象，无需依赖 provider 解析。

### 6.3 四个 skill 的完整内容

（与 `dsh-grill-plugin/skills/<name>/SKILL.md` 完全一致，见 §11 附录全文。）

### 6.4 插件实现

**文件**：`dsh-grill-plugin/src/index.ts`

要点：

1. `export const name = 'dsh-grill'`
2. `export const inject = ['skills']`（确保 `ctx.skills` 就绪）
3. `parseSkill(md)`：正则切分 `---\n...\n---\n`，取 `name`/`description`/`disable-model-invocation`，正文 trim。
4. `loadSkills()`：`fileURLToPath(import.meta.url)` 定位 `../skills`，遍历含 `SKILL.md` 的子目录。
5. `apply(ctx)`：逐 skill `ctx.skills.register({ name, description, content, source: 'runtime', invocation: { modelInvocable, userInvocable: true } })`。

**实现代码见**：`dsh-grill-plugin/src/index.ts`（已生成，见附录 §11）。

### 6.5 目录清单

```
dsh-grill-plugin/
├── src/index.ts                 # 插件入口
├── skills/
│   ├── grilling/SKILL.md        # 核心 primitive
│   ├── grill-me/SKILL.md        # 入口（user-only）
│   ├── grill-with-docs/SKILL.md # 入口（user-only）
│   └── domain-modeling/SKILL.md # 依赖
└── cordis.yml                   # 插件加载 overlay 示例
```

---

## 7. 实现计划（里程碑）

| 阶段 | 内容 | 产出 | 验证方式 |
| --- | --- | --- | --- |
| M0 | 前置确认 | 确认 dsh 版本、`ctx.skills` 可用、inject 名 | 启动 `pnpm dsh web`，加载 hello-plugin |
| M1 | 落地 skill 文件 | 4 个 `SKILL.md` 就位（已完成） | 目检 frontmatter 正确 |
| M2 | 插件代码 | `src/index.ts` + `cordis.yml` | 插件加载无报错，`ctx.skills.list()` 出现 4 个 skill |
| M3 | 委托链路打通 | `/grill-me` → `grilling` 正常触发 | 实测面试格式（❓/➡️/`---`） |
| M4 | 文档产出验证 | `/grill-with-docs` 写 `CONTEXT.md`/ADR | 面试中 `CONTEXT.md` 实时生成 |
| M5 | 兜底加固 | 内联 grilling 正文到 grill-me（可选） | 弱模型下委托不失效 |
| M6 | 打包与文档 | README/SPEC 定稿 | 他人可照文档复现 |

---

## 8. 验收标准（Acceptance Criteria）

- **AC-1** 加载插件后，`ctx.skills.snapshot()` 返回的目录包含 4 个 skill，名称分别为 `grilling`、`grill-me`、`grill-with-docs`、`domain-modeling`。
- **AC-2** `grill-me`、`grill-with-docs` 的 `invocation.modelInvocable === false`；`grilling`、`domain-modeling` 为 `true`。
- **AC-3** 运行 `/grill-me`，首轮输出为编号问题列表，每个问题带独立 `➡️` 推荐行，问题间以 `---` 分隔；可用编号作答。
- **AC-4** 运行 `/grill-with-docs`，面试中术语被解析时 `CONTEXT.md` 立即更新（非结尾一次性生成）。
- **AC-5** 面试中属于「可查事实」的问题由 agent 读文件/sub-agent 解决，不反问用户。
- **AC-6** frontier 清空后，agent 停下并请求用户确认「已达成共识」，不擅自开始实施。
- **AC-7** 插件卸载后目录中 4 个 skill 消失，无残留。

---

## 9. 测试用例

| # | 输入 | 预期 |
| --- | --- | --- |
| T1 | 加载插件 | 日志无异常，目录含 4 skill |
| T2 | `/grill-me` + 「我想做一个用户登录功能」 | 首轮 3-8 个编号问题，同轮问题互不依赖 |
| T3 | 对 T2 首轮按编号作答 | 第二轮只问第一轮未解锁的问题，明显建立在前序答案上 |
| T4 | 面试中问「现有数据库用的是哪种」 | agent 读代码/配置自己查，不反问用户 |
| T5 | `/grill-with-docs` + 「帮我梳理这个项目的领域术语」 | 会话中 `CONTEXT.md` 逐条生成术语 |
| T6 | 决策满足 ADR 三关 | 写入 `docs/adr/0001-*.md`；不满足则不写 |
| T7 | frontier 清空后 | agent 停下请求确认，不自动写代码 |
| T8 | 卸载插件 | 目录无残留 skill |

---

## 10. 风险与待验证点

| # | 风险/待验证 | 影响 | 缓解措施 |
| --- | --- | --- | --- |
| R1 | `inject: ['skills']` 服务名与你的 dsh 版本不一致 | 插件加载失败 | 以 `ctx.skills` 能取到为准，必要时改服务名；M0 先验证 |
| R2 | `SkillRegistration` 必填字段（如 `source`）与官方 TS 类型有差异 | 编译/运行时类型错误 | 以 `ctx.skills.register` 实际签名为准；`source:'runtime'` 为官方允许值 |
| R3 | `import.meta.url` 读文件在插件被打包/转译后失效 | 找不到 SKILL.md | 改为内联正文字符串（备用方案） |
| R4 | 「skill 调 skill」委托（grill-me → grilling）在部分模型下不加载 | 得到即兴问答而非真 grilling | M5 兜底：把 grilling 正文内联进 grill-me |
| R5 | 弱模型跳过「确认门」直接实施 | 用户未确认就开建 | 在 `AGENTS.md`/`CLAUDE.md` 加「未经允许不得实施」 |
| R6 | `grill-with-docs` 在两个依赖任一未加载时降级 | 有面试但无文档产出 | 让模型明确回答「是否加载了 grilling 与 domain-modeling」 |

---

## 11. 附录

### 11.1 源文件对照（已下载至 `grill-files/`）

| 源文件 | 说明 |
| --- | --- |
| `docs_productivity_grilling.md` | grilling 官方文档页 |
| `docs_productivity_grill-me.md` | grill-me 官方文档页 |
| `docs_engineering_grill-with-docs.md` | grill-with-docs 官方文档页 |
| `skill_grilling_SKILL.md` 等 | 4 个 skill 定义原文 |
| `agent_*_openai.yaml` | Codex 元数据（dsh 不用，仅参考） |
| `changeset_grilling-*.md` | 历史改动（`---` 分隔、去 em-dash） |

### 11.2 四个 SKILL.md 全文

#### `skills/grilling/SKILL.md`

```markdown
---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
```

#### `skills/grill-me/SKILL.md`

```markdown
---
name: grill-me
description: A relentless interview to sharpen a plan or design.
disable-model-invocation: true
---

Call the Skill tool with "grilling".
```

#### `skills/grill-with-docs/SKILL.md`

```markdown
---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Call the Skill tool twice, for "grilling" and "domain-modeling".
```

#### `skills/domain-modeling/SKILL.md`

```markdown
---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when discussing codebase terminology, writing or editing a CONTEXT.md, or recording or editing an ADR.
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline: challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* `CONTEXT.md` for vocabulary is not this skill: that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)

## File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily: only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account': do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up: capture them as they happen.

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR.
```

### 11.3 插件入口代码（`src/index.ts`，已生成）

```ts
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import type { Context } from '@deepseek-ai/cordis'

export const name = 'dsh-grill'
export const inject = ['skills']

interface ParsedSkill {
  name: string
  description: string
  content: string
  modelInvocable: boolean
}

function parseSkill(md: string): ParsedSkill {
  const m = md.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/)
  if (!m) throw new Error('Skill file missing YAML frontmatter')
  const front = m[1]
  const content = m[2].trim()

  const name = front.match(/^name:\s*(.+)$/m)?.[1]?.trim()
  const description = front.match(/^description:\s*(.+)$/m)?.[1]?.trim()
  if (!name || !description) throw new Error('Skill missing name or description')

  const disableModel = /^disable-model-invocation:\s*true\s*$/m.test(front)
  return { name, description, content, modelInvocable: !disableModel }
}

function loadSkills(): ParsedSkill[] {
  const here = dirname(fileURLToPath(import.meta.url))
  const skillsRoot = join(here, '..', 'skills')
  const out: ParsedSkill[] = []
  for (const dir of readdirSync(skillsRoot)) {
    const file = join(skillsRoot, dir, 'SKILL.md')
    if (existsSync(file)) out.push(parseSkill(readFileSync(file, 'utf8')))
  }
  return out
}

export function apply(ctx: Context) {
  for (const skill of loadSkills()) {
    ctx.skills.register({
      name: skill.name,
      description: skill.description,
      content: skill.content,
      source: 'runtime',
      invocation: {
        modelInvocable: skill.modelInvocable,
        userInvocable: true,
      },
    })
  }
}
```

### 11.4 cordis.yml（已生成，路径需替换为实际绝对路径）

```yaml
- insert:
    - id: dsh-grill
      name: 'C:/AI-SKLII/dsh-grill-me(plan)/dsh-grill-plugin/src/index.ts'
```

### 11.5 dsh skills API 速查（开发时对照）

- 注册：`ctx.skills.register(skill: SkillRegistration): () => void`
- 列表：`await ctx.skills.list(options): Promise<SkillSummary[]>`
- 快照：`await ctx.skills.snapshot(options): Promise<SkillCatalogSnapshot>`
- 取全文：`await ctx.skills.get(name, options): Promise<SkillDefinition | undefined>`
- 关键类型：`SkillInvocationPolicy = { modelInvocable: boolean; userInvocable: boolean }`
- 模型工具：`skill({ name })` → 返回 `<skill_content name="...">`、`<skill_resources>`、`<skill_instructions>`

---

## 12. DSH 开发插件基本要求

### 12.1 插件形态要求

Cordis 对插件的形态有严格要求，插件必须是以下两种标准格式之一：

#### 函数式插件（推荐）

```typescript
// ✅ 正确的函数式插件
export function apply(ctx) {
  console.log('插件已加载');
}
```

#### 类式插件

```typescript
// ✅ 正确的类式插件
import { Service } from 'cordis';
class MyService extends Service {
  constructor(ctx) {
    super(ctx, 'myService');
  }
}
```

**常见错误**：
- 拼写错误（例如将 `apply` 写成了 `appply`）
- 导出了一个普通的对象/变量而不是函数

### 12.2 依赖注入（inject）声明

如果插件声明了依赖，`inject` 数组中的服务名称必须是字符串，且这些服务在上下文中必须真实存在。

```typescript
// ✅ 正确的依赖声明
export const inject = ['tools', 'llm'];
```

**排查建议**：确认 `inject` 中填写的 key（如 `ctx.tools`）是否拼写正确，且对应的核心服务或前置插件已经正确加载。

### 12.3 配置文件（如 cordis.patch.yml）

如果是通过配置文件（如 `cordis.patch.yml` 或 `agent.cordis.yml`）来注册或启用插件，错误可能出在 YAML 的语法或层级结构上。

**排查建议**：
- 检查缩进是否正确，YAML 对缩进非常敏感
- 确认插件的 `id` 和 `name` 字段是否完整且格式正确

```yaml
# ✅ 正确的配置文件格式
- id: tool-foo
  name: '@someone/dsh-tool-foo'
```

### 12.4 副作用（Effect）注册

如果在插件内部使用了 `ctx.effect()` 进行注册，确保传入的是一个返回清理函数的函数。

```typescript
// ✅ 正确的 effect 注册
ctx.effect(() => {
  ctx.systemPrompt.sections.register('my-section', () => ({ content: '...' }));
  
  // 必须返回一个 disposer（清理函数）
  return () => console.log('已撤销');
});
```

### 12.5 插件导出格式总结

| 导出项 | 类型 | 必需 | 说明 |
| --- | --- | --- | --- |
| `name` | `string` | 是 | 插件名称，用于标识插件 |
| `inject` | `string[]` | 否 | 依赖的服务列表，确保在 `apply` 调用前这些服务已就绪 |
| `apply` | `function` | 是 | 插件入口函数，接收 `Context` 参数 |

### 12.6 常见错误及解决方案

| 错误信息 | 可能原因 | 解决方案 |
| --- | --- | --- |
| `invalid arguments: "plugin" must match exactly one oneOf branch` | 插件对象结构不符合预期 | 检查插件是否导出了正确的 `apply` 函数或 `Service` 子类 |
| `service "x" is not declared` | 使用了未声明的服务 | 在 `inject` 中添加服务名或使用 `ctx.get('x')` 并检查 undefined |
| `cannot get property "timer" without inject` | 使用了 timer 服务但未声明 | 添加 `inject: ['timer']` |
| Client parse failure | 使用了 JSX、TypeScript、import 或不可用的全局变量 | 确保代码是纯 JavaScript，不使用 import/require/JSX |

---

## 13. 当前工作进展与下一步规划

### 13.1 已完成工作

#### 13.1.1 项目结构搭建
- ✅ 创建了 `dsh-grill-plugin` 目录结构
- ✅ 创建了 `src/index.ts` 插件入口文件
- ✅ 创建了 `skills/` 目录，包含 4 个 SKILL.md 文件
- ✅ 创建了 `cordis.yml` 配置文件示例

#### 13.1.2 Skill 文件实现
- ✅ 实现了 `grilling` skill（核心面试 primitive）
- ✅ 实现了 `grill-me` skill（用户入口，委托 grilling）
- ✅ 实现了 `grill-with-docs` skill（用户入口，委托 grilling + domain-modeling）
- ✅ 实现了 `domain-modeling` skill（领域模型写作纪律）

#### 13.1.3 插件代码实现
- ✅ 实现了 `parseSkill()` 函数，解析 YAML frontmatter
- ✅ 实现了 `loadSkills()` 函数，从文件系统加载技能
- ✅ 实现了 `apply()` 函数，注册技能到 `ctx.skills`
- ✅ 实现了命令注册功能（`grill-me` 和 `grill-with-docs`）
- ✅ 实现了用户提问功能（通过 `userQuestions` 服务）

#### 13.1.4 文档编写
- ✅ 编写了 SPEC.md 规格说明书
- ✅ 编写了 README.md 项目说明
- ✅ 添加了 DSH 开发插件基本要求章节

### 13.2 当前遇到的问题

#### 13.2.1 Cordis 插件加载问题
- ❌ 使用 `cordis_define` 工具时遇到 `plugin` 参数验证错误
- ❌ 错误信息：`invalid arguments: "plugin" must match exactly one oneOf branch (matched 0)`

**问题分析**：
1. `cordis_define` 工具期望的 `plugin` 参数格式可能与实际不符
2. 可能需要使用其他方式加载插件（如通过 `cordis.yml` 配置文件）
3. 可能需要检查插件代码是否符合 Cordis 规范

#### 13.2.2 服务依赖问题
- ⚠️ `commands` 和 `userQuestions` 服务可能不存在或不可用
- ⚠️ 需要确认这些服务是否在当前 DSH 环境中可用

### 13.3 下一步规划

#### 13.3.1 短期目标（1-2天）

1. **解决插件加载问题**
   - 尝试通过 `cordis.yml` 配置文件加载插件
   - 检查插件代码是否符合 Cordis 规范
   - 查阅 DSH 官方文档，了解正确的插件加载方式

2. **验证服务可用性**
   - 检查 `commands` 服务是否存在
   - 检查 `userQuestions` 服务是否存在
   - 如果服务不存在，调整插件实现方案

3. **基本功能测试**
   - 测试插件是否能正确加载
   - 测试技能是否能正确注册
   - 测试命令是否能正确执行

#### 13.3.2 中期目标（3-5天）

1. **完善插件功能**
   - 实现完整的面试流程
   - 实现文档生成功能（CONTEXT.md 和 ADR）
   - 优化用户体验

2. **错误处理和边界情况**
   - 添加更完善的错误处理
   - 处理服务不可用的情况
   - 处理用户输入异常

3. **性能优化**
   - 优化技能加载性能
   - 优化命令执行性能
   - 减少内存占用

#### 13.3.3 长期目标（1-2周）

1. **功能扩展**
   - 支持更多 grill 相关技能
   - 支持自定义面试模板
   - 支持面试结果导出

2. **文档完善**
   - 编写详细的用户手册
   - 编写开发者文档
   - 编写 API 文档

3. **测试和质量保证**
   - 编写单元测试
   - 编写集成测试
   - 进行性能测试

### 13.4 风险评估

| 风险项 | 影响程度 | 发生概率 | 缓解措施 |
| --- | --- | --- | --- |
| Cordis 框架不兼容 | 高 | 中 | 查阅官方文档，调整插件实现方式 |
| 服务不可用 | 中 | 高 | 添加服务存在性检查，提供降级方案 |
| 性能问题 | 中 | 低 | 优化代码，减少不必要的计算 |
| 用户体验不佳 | 中 | 中 | 收集用户反馈，持续改进 |

### 13.5 成功标准

#### 13.5.1 功能成功标准
- 插件能正确加载，无报错
- 4 个技能能正确注册到 `ctx.skills`
- `/grill-me` 命令能触发面试流程
- `/grill-with-docs` 命令能触发带文档生成的面试流程

#### 13.5.2 质量成功标准
- 代码符合 Cordis 插件规范
- 无内存泄漏或资源未释放问题
- 错误处理完善，用户体验良好

#### 13.5.3 文档成功标准
- SPEC.md 文档完整、准确
- README.md 文档清晰、易懂
- 用户手册详细、实用
