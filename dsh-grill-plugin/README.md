# mattpocock/skills 项目解读 & grill 能力整理 & dsh 插件方案

## 一、项目整体解读

[mattpocock/skills](https://github.com/mattpocock/skills) 是 Matt Pocock 开源的一套「agent skills」集合，定位是 **"Skills for Real Engineers"**（给真实工程师用的技能，而非 vibe coding）。核心理念：

- **小、易改、可组合**：每个 skill 是独立目录，互不依赖（除少数 primitive 外），可单独安装、单独 hack。
- **与模型无关**：本质上是「prompt + 触发元数据」，任何 harness 都能跑。
- **反流程绑架**：区别于 GSD / BMAD / Spec-Kit 这类「替你掌控流程」的框架，Matt 的 skill 把控制权留在你手里。

### 目录结构约定

每个 skill 是一个目录，含两类文件：

```
skills/<分类>/<名字>/
├── SKILL.md            # skill 定义：YAML frontmatter + Markdown 指令正文
└── agents/
    └── openai.yaml     # harness 专属元数据（display_name / 调用策略）
```

另外每个 skill 在 `docs/<分类>/<名字>.md` 有一份「给人读」的文档（what it does / when to reach for it / common questions / it's working if / where it fits）。

### 两类调用方式（贯穿全项目的关键分法）

| 类型 | 谁触发 | 标记方式 | 职责 |
| --- | --- | --- | --- |
| **User-invoked**（用户调用） | 只能用户输入 `/xxx` | Claude Code: `disable-model-invocation: true`；Codex: `policy.allow_implicit_invocation: false` | 编排（orchestration） |
| **Model-invoked**（模型调用） | 用户或模型自动 | 无该标记 | 可复用的纪律（discipline） |

**规则：用户调用型 skill 可以调用模型调用型 skill，但绝不能调用另一个用户调用型 skill。**

---

## 二、grill 相关内容分离与整理

grill 家族一共 **3 个 skill + 1 个硬依赖**，形成清晰的「primitive + 两个入口」结构：

```
                    ┌─ grill-me ──────────┐
用户入口（user-invoked）                      ├──> grilling（primitive，model-invoked）
                    └─ grill-with-docs ────┤
                                            └──> domain-modeling（写文档的纪律）
```

### 1. `grilling` —— 核心 primitive（面试循环）

**定位**：可复用的「面试技术」唯一真源。所有需要 interview 的 skill 都调用它，而不是自己重写。

**机制（三个核心概念）**：

- **Design tree（设计树）**：把主题建模成一棵决策树——每个决策分支出挂在其下的子决策。
- **Frontier（前沿）**：所有「前置条件已解决」的决策集合，即此刻唯一能诚实提问的问题。
- **Round（轮次）**：一轮 = 一次性问完整个 frontier，等用户答完再问下一轮。

**提问格式（每轮固定）**：

```
❓ **Q1** - **<问题标题>**: <问题正文，可能多段，含多个选项>

➡️ <你的推荐答案>

---

❓ **Q2** - **<问题标题>**: <问题正文>

➡️ <你的推荐答案>
```

每轮之间用 `---` 分隔；用户可以按编号作答（"1 yes, 2 选第二个, 3 no"）。

**事实 vs 决策的分工（最关键的设计）**：
- **事实（facts）是 agent 的活**：需要查文件/工具才能知道的东西，派 sub-agent 去查，绝不问用户。不阻塞——只有依赖该调查的问题才等待，其余照常提问。
- **决策（decisions）是用户的活**：必须逐条抛给用户并等待。agent 替用户做决策 = 违反 skill，不是「灵活发挥」。

**结束条件**：frontier 清空（设计树每个分支都访问过），且**用户确认「已达成共识」**之后才允许行动。agent 一上来就开建 = 坏了。

### 2. `grill-me` —— 无状态入口

- 一行 skill：`Call the Skill tool with "grilling".`
- **无状态**：不写任何文件，不留 workspace，适合「没在仓库里」「想法还不是代码」的场景（商业决策、写作、下一步做什么都行）。
- `disable-model-invocation: true`：模型不会自己触发，只有用户输入 `/grill-me`。

### 3. `grill-with-docs` —— 有状态入口（带文档产出）

- 一行 skill：`Call the Skill tool twice, for "grilling" and "domain-modeling".`
- **有状态**：面试过程中边聊边把成果写进仓库：
  - 术语 → 实时写进 `CONTEXT.md`（术语表 glossary，纯词汇，不含实现细节）
  - 决策 → 通过三关（难以逆转 / 无上下文会惊讶 / 真实权衡）才写进 `docs/adr/` 的 ADR
- 硬依赖：`grilling`（提供面试）+ `domain-modeling`（提供写作纪律），缺一不可。

### 4. `domain-modeling` —— grill-with-docs 的依赖

负责「主动打磨领域模型」：挑战术语、造边界场景、把 glossary 和决策即时落盘。核心规则：
- `CONTEXT.md` = 纯 glossary，不是 spec、不是草稿本。
- ADR 三关全满足才写，否则跳过（大多数决策不产生 ADR）。

### 5. 相关联（非 grill 本体，供参考）

`wayfinder`（超大工作量，多 session）、`to-spec`（grill 之后把对话合成 spec）、`prototype`（无法靠聊天定夺的问题 → 建一次性原型）、`triage` / `to-questionnaire` / `improve-codebase-architecture`（内部会调用 grilling）。

### 6. 已知坑（源自官方 docs，移植时要注意）

- **skill 之间互相点名不一定触发加载**：`grill-with-docs` 点名 `grilling`+`domain-modeling`，但「skill 调 skill」在部分 harness/模型下会失效，表现为「一次问完所有问题、没有推荐答案」——这是模型在即兴发挥而非真跑 grilling。
- **问一轮会丢失追问**是常见质疑，官方答案：frontier 保证同轮问题互不依赖，所以不会。
- **确认门（confirmation gate）**：弱模型会「interview 完直接开建」，需要在自己 AGENTS.md/CLAUDE.md 里补一句「未经允许不得实施」。

---

## 三、dsh（DeepSeek Harness）插件开发方案

### dsh 的 skills 机制（已核对官方文档）

- 一切皆插件（Cordis 框架），插件是导出 `apply(ctx)` 的 TS 模块。
- skills 是 `ctx.skills` 服务，注册用 `ctx.skills.register({...})`，字段：`name`（kebab-case）、`description`、`content`、`invocation: { modelInvocable, userInvocable }`、`source`。
- 前端 matter 与 mattpocock 高度对齐：dsh 本地 provider 读 `disable-model-invocation` 与 `user-invocable` 两个 kebab-case 键，缺省按 true 处理——**这意味着 mattpocock 的 SKILL.md 几乎可以直接用**。

### 映射关系

| mattpocock 概念 | dsh 对应 |
| --- | --- |
| `SKILL.md` frontmatter `name` | `SkillRegistration.name` |
| `description` | `description` |
| 正文 | `content` |
| `disable-model-invocation: true` | `invocation.modelInvocable: false` |
| （无标记 = 模型可调用） | `invocation.modelInvocable: true` |
| `agents/openai.yaml` | dsh 无此概念，忽略（策略全在 frontmatter） |

### 两条实现路径

**路径 A（零代码，最快见效）**：直接把 SKILL.md 丢进 dsh 的本地扫描目录，dsh 内置 filesystem provider 会自动发现。扫描优先级（rank 从高到低）：

```
<projectRoot>/.dsh/skills   (100)
<projectRoot>/.agents/skills (200)
Config.customSkillDirs       (300)
<dshHome>/skills             (400)
<agentsHome>/skills          (500)
```

即：`cp skills/*/<name>/SKILL.md 到 <dshHome>/skills/<name>/SKILL.md` 即可全局启用 grill 能力，一行代码都不用写。

**路径 B（插件，可分发，本项目已实现）**：写 TS 插件，`ctx.skills.register()` 在 apply 时注册四个 skill。本目录 `src/index.ts` 已写好：从 `../skills/**/SKILL.md` 读取并解析 frontmatter 后注册。

### 插件文件清单

```
dsh-grill-plugin/
├── src/index.ts                 # 插件入口：读 skills/*/SKILL.md 并 ctx.skills.register()
├── skills/
│   ├── grilling/SKILL.md        # 核心 primitive（模型+用户皆可调用）
│   ├── grill-me/SKILL.md        # 入口（仅用户调用）
│   ├── grill-with-docs/SKILL.md # 入口（仅用户调用）
│   └── domain-modeling/SKILL.md # grill-with-docs 的依赖
└── cordis.yml                   # 插件加载配置示例
```

### 使用步骤

1. 把 `cordis.yml` 里的路径改成你机器上 `src/index.ts` 的绝对路径。
2. 启动：`pnpm dsh web --patch ./cordis.yml`（或走你实际的 dsh 启动方式）。
3. 用户输入 `/grill-me` 或 `/grill-with-docs`；模型在任务合适时会自动触发 `grilling`。

### 需要注意 / 待验证的点

- **注入服务名**：本插件用 `inject: ['skills']`。dsh 的 skills 服务定义包是 `dsh-skill`、暴露为 `ctx.skills`；若你的 dsh 版本 inject 名不是 `skills`，改成对应服务名（以 `ctx.skills` 能取到为准）。
- **`source` 字段**：runtime 注册按官方 `SkillSource` 用 `'runtime'`；若你的版本类型不同，去掉或改成该版本接受的值。
- **`import.meta.url` 读文件**：本地/workspace 插件（run-from-source）下能正确解析到源码旁的 `skills/`；若 dsh 对插件做了打包/转译导致路径失效，改为把正文内联进插件字符串（备用方案）。
- **grill-me → grilling 的委托**：dsh 有模型可调用的 `skill({name})` 工具，理论上能完成「grill-me 正文里点名 grilling」的委托；但官方 docs 明确这是已知脆弱点，建议实测，必要时把 `grill-me` 正文直接内联 grilling 全文兜底。

### 最小可用范围（MVP）

如果只想先要「grill 能力」，最小集就是 **`grilling` + `grill-me`** 两个 skill；`grill-with-docs` 与 `domain-modeling` 属于「带文档产出」的增强，可后补。

---

## 附录：原始文件对照

已下载的 grill 相关源文件在 `grill-files/`（raw 下载，用于核对）：

- `docs_productivity_grilling.md` / `docs_productivity_grill-me.md` / `docs_engineering_grill-with-docs.md` —— 官方文档页
- `skill_grilling_SKILL.md` / `skill_grill-me_SKILL.md` / `skill_grill-with-docs_SKILL.md` / `skill_domain-modeling_SKILL.md` —— skill 定义
- `agent_*_openai.yaml` —— Codex 元数据（dsh 用不到，仅参考）
- `changeset_grilling-*.md` —— 历史改动记录（说明曾加过 `---` 分隔、去掉 em-dash）
