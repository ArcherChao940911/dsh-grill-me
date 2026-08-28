# dsh-grill 插件

为 DeepSeek Harness (dsh) 开发的 grill 插件，实现面试式需求澄清功能。

## 项目概述

基于 [mattpocock/skills](https://github.com/mattpocock/skills) 仓库的 grill 家族能力，将其移植到 dsh 平台，以插件形式交付。

「grill」是一套**面试式需求澄清技术**：agent 把你的想法建模成一棵决策树，按「前沿（frontier）→ 轮次（round）」的方式逐轮追问，直到你与 agent 对目标达成共识、且没有遗留的隐性假设。

## 功能特性

### 核心技能

| 技能 | 分类 | 调用方式 | 职责 |
| --- | --- | --- | --- |
| `grilling` | 核心 primitive | model + user | 面试循环本体 |
| `grill-me` | 入口 | user-only | 无状态入口，委托 `grilling` |
| `grill-with-docs` | 入口 | user-only | 有状态入口，委托 `grilling` + `domain-modeling`，写 `CONTEXT.md` 和 ADR |
| `domain-modeling` | 依赖 | model + user | 领域模型写作纪律 |

### 面试机制

1. **设计树（Design Tree）**：把主题建模成决策树，每个决策分支出挂在它下面的子决策
2. **前沿（Frontier）**：所有「前置条件已解决」的决策集合，即此刻唯一能诚实提问的问题
3. **轮次（Round）**：一轮 = 一次性问完整个 frontier，等用户答完再进入下一轮

### 事实 vs 决策分工

- **事实（facts）是 agent 的活**：需要查文件/工具才知道的东西，派 sub-agent 去查，绝不问用户
- **决策（decisions）是用户的活**：必须逐条抛给用户并等待

## 安装与使用

### 一键安装（推荐）

#### Linux / macOS

```bash
# 从本地安装
bash install-grill-skills.sh

# 或从网络安装（如果脚本托管在 GitHub）
curl -fsSL https://raw.githubusercontent.com/your-username/dsh-grill/main/install-grill-skills.sh | bash
```

#### Windows (PowerShell)

```powershell
# 从本地安装
.\install-grill-skills.ps1

# 或从网络安装（如果脚本托管在 GitHub）
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/your-username/dsh-grill/main/install-grill-skills.ps1" -OutFile install.ps1; .\install.ps1
```

### 手动安装

```bash
# 1. 创建技能目录
mkdir -p ~/.dsh/skills/{grilling,grill-me,grill-with-docs,domain-modeling}

# 2. 复制技能文件
cp -r dsh-grill-plugin/skills/* ~/.dsh/skills/

# 3. 启动 dsh
dsh web
```

### 使用方法

1. **重启 DSH**：`dsh web`
2. **查看技能**：`/skills`
3. **开始面试**：`/grill-me` 或 `/grill-with-docs`

## 使用方法

### 基本使用

1. **启动 dsh**：
   ```bash
   dsh web
   ```

2. **查看可用技能**：
   ```
   /skills
   ```

3. **开始面试**：
   ```
   /grill-me
   ```

4. **带文档生成的面试**：
   ```
   /grill-with-docs
   ```

### 面试示例

```
用户: /grill-me
用户: 我想做一个用户登录功能

模型:
❓ **Q1** - **认证方式**: 您希望使用哪种认证方式？

1. 用户名/密码认证
2. 第三方 OAuth 认证（Google、GitHub 等）
3. 手机号/短信验证码
4. 多因素认证（MFA）

➡️ 推荐选择 1（用户名/密码认证），因为这是最基本且最常用的方式，后续可以扩展其他方式。

---

❓ **Q2** - **用户存储**: 用户信息存储在哪里？

1. 本地数据库（MySQL、PostgreSQL 等）
2. 云数据库服务（Firebase、Supabase 等）
3. 内存数据库（Redis）

➡️ 推荐选择 1（本地数据库），因为这样可以完全控制数据，且便于后续扩展。

---

❓ **Q3** - **会话管理**: 如何管理用户会话？

1. Cookie + Session
2. JWT Token
3. 无状态设计

➡️ 推荐选择 2（JWT Token），因为这是现代 Web 应用的主流方案，支持前后端分离。
```

## 项目结构

```
dsh-grill-me/
├── SPEC.md                    # 规格说明书
├── PROJECT_STATUS.md          # 项目状态报告
├── WORK_SUMMARY.md            # 工作总结
├── TESTING.md                 # 测试说明
├── README.md                  # 本文件
├── .dsh/skills/               # dsh 技能目录（已配置）
│   ├── domain-modeling/SKILL.md
│   ├── grill-me/SKILL.md
│   ├── grill-with-docs/SKILL.md
│   └── grilling/SKILL.md
├── dsh-grill-plugin/          # 插件源代码
│   ├── src/index.ts           # 插件入口文件
│   ├── skills/                # 技能文件源
│   ├── cordis.yml             # 插件配置示例
│   └── README.md              # 插件说明
└── grill-files/               # 参考文件
    ├── docs_productivity_grilling.md
    ├── docs_productivity_grill-me.md
    ├── docs_engineering_grill-with-docs.md
    ├── skill_grilling_SKILL.md
    ├── skill_grill-me_SKILL.md
    ├── skill_grill-with-docs_SKILL.md
    └── skill_domain-modeling_SKILL.md
```

## 验收标准

根据 SPEC.md 的验收标准：

- **AC-1** 加载后，技能目录中应该包含 4 个 skill
- **AC-2** `grill-me`、`grill-with-docs` 的 `modelInvocable === false`；`grilling`、`domain-modeling` 为 `true`
- **AC-3** 运行 `/grill-me`，首轮输出为编号问题列表，每个问题带独立 `➡️` 推荐行，问题间以 `---` 分隔
- **AC-4** 运行 `/grill-with-docs`，面试中术语被解析时 `CONTEXT.md` 立即更新
- **AC-5** 面试中属于「可查事实」的问题由 agent 读文件/sub-agent 解决，不反问用户
- **AC-6** frontier 清空后，agent 停下并请求用户确认「已达成共识」，不擅自开始实施

## 已知问题与解决方案

### 问题 1：Cordis 插件加载失败

**错误信息**：`invalid arguments: "plugin" must match exactly one oneOf branch (matched 0)`

**解决方案**：采用路径 A（本地扫描目录方式），避免插件加载问题。

### 问题 2：服务依赖不确定性

**问题描述**：`commands` 和 `userQuestions` 服务可能不存在

**解决方案**：采用路径 A 后，不再需要这些服务。

## 自定义与扩展

### 修改技能内容

技能文件是普通的 Markdown 文件，可以直接编辑：

```bash
# 编辑 grilling 技能
vim .dsh/skills/grilling/SKILL.md

# 编辑 grill-me 技能
vim .dsh/skills/grill-me/SKILL.md
```

### 添加新技能

1. 在 `.dsh/skills/` 目录下创建新目录
2. 在目录中创建 `SKILL.md` 文件
3. 按照现有技能的格式编写 frontmatter 和内容

### 扩展功能

根据 SPEC.md 的规划，后续可以添加：

- `wayfinder` - 超大工作量，多 session
- `to-spec` - grill 之后把对话合成 spec
- `prototype` - 无法靠聊天定夺的问题 → 建一次性原型
- `triage` / `to-questionnaire` / `improve-codebase-architecture` - 内部会调用 grilling

## 参考资源

- [mattpocock/skills](https://github.com/mattpocock/skills) - 上游技能仓库
- [DeepSeek Harness 官方文档](https://docs.deepseek.com) - DSH 官方文档
- [Cordis 框架文档](https://cordis.js.org) - Cordis 框架文档

## 贡献指南

欢迎贡献代码、文档或反馈！

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 许可证

本项目基于 MIT 许可证开源 - 查看 [LICENSE](LICENSE) 文件了解详情

