# Grill Skills 一键安装脚本 (PowerShell)
# 用法: .\install-grill-skills.ps1

$ErrorActionPreference = "Stop"

# 颜色函数
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "→ $args" -ForegroundColor Yellow }

# 检测 DSH 配置目录
function Get-DSHHome {
    if ($env:DSH_HOME) {
        return $env:DSH_HOME
    } elseif (Test-Path "$env:USERPROFILE\.dsh") {
        return "$env:USERPROFILE\.dsh"
    } elseif (Test-Path "$HOME/.dsh") {
        return "$HOME/.dsh"
    } else {
        return $null
    }
}

# 技能文件内容
$GRILLING_SKILL = @'
---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round using the `ask_user_question` tool. Then wait for the user's answers before the next round.

## How to ask questions

**IMPORTANT**: Use the `ask_user_question` tool to present questions as interactive cards. Do NOT output questions as plain text.

For each round, call `ask_user_question` with all frontier questions at once:

```
ask_user_question({
  questions: [
    {
      id: "q1",
      question: "问题标题",
      detail: "问题详细描述，包含背景信息和选项说明",
      options: [
        { label: "选项1的标签", description: "选项1的详细说明" },
        { label: "选项2的标签", description: "选项2的详细说明" },
        { label: "选项3的标签", description: "选项3的详细说明" }
      ]
    },
    {
      id: "q2",
      question: "另一个问题标题",
      detail: "另一个问题的详细描述",
      options: [
        { label: "选项A", description: "选项A说明" },
        { label: "选项B", description: "选项B说明" }
      ]
    }
  ]
})
```

### Question format rules

1. **id**: Use sequential IDs like "q1", "q2", "q3" etc.
2. **question**: Short, clear title for the question
3. **detail**: Detailed explanation with context, background, and reasoning for each option
4. **options**: Array of choices with label and optional description
5. **multiSelect**: Set to `true` if multiple selections are allowed (default is single select)

### Example round

If you need to ask about authentication and database:

```javascript
ask_user_question({
  questions: [
    {
      id: "auth_method",
      question: "认证方式选择",
      detail: "选择用户身份验证的主要方式。每种方式有不同的安全性和实现复杂度。",
      options: [
        { label: "用户名/密码", description: "最传统的方式，实现简单，用户熟悉" },
        { label: "OAuth 2.0", description: "支持第三方登录（Google、GitHub等），用户体验好" },
        { label: "手机号/验证码", description: "无需记住密码，适合移动端" },
        { label: "多因素认证", description: "安全性最高，但实现复杂度也最高" }
      ]
    },
    {
      id: "database_type",
      question: "数据库选择",
      detail: "选择存储用户数据的数据库类型。考虑数据结构、查询需求和扩展性。",
      options: [
        { label: "PostgreSQL", description: "功能强大的关系型数据库，支持复杂查询" },
        { label: "MySQL", description: "广泛使用，社区资源丰富" },
        { label: "MongoDB", description: "文档型数据库，灵活的数据模型" },
        { label: "Redis", description: "内存数据库，适合缓存和会话存储" }
      ]
    }
  ]
})
```

## Working with the design tree

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

### Fact-finding

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now.

### Decisions

The _decisions_ are the user's: put each to them using `ask_user_question` and wait for their response.

## Completion

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

After the frontier is empty, ask for final confirmation:

```javascript
ask_user_question({
  questions: [
    {
      id: "confirm",
      question: "确认达成共识",
      detail: "我们已经讨论了所有关键决策。请确认我们已经达成共识，可以开始实施。",
      options: [
        { label: "确认，开始实施", description: "所有决策已明确，可以开始编码" },
        { label: "还需要讨论", description: "还有一些问题需要澄清" }
      ]
    }
  ]
})
```

## Key principles

1. **One question per card item**: Each `id` represents one decision point
2. **Provide context in detail**: Users need background to make informed decisions
3. **Offer clear options**: Make the choice set explicit with labeled options
4. **Respect user answers**: Once answered, move forward; don't re-ask settled decisions
5. **Wait for responses**: Never proceed without user input on decisions
'@

$GRILL_ME_SKILL = @'
---
name: grill-me
description: A relentless interview to sharpen a plan or design.
disable-model-invocation: true
---

Call the Skill tool with "grilling".
'@

$GRILL_WITH_DOCS_SKILL = @'
---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Call the Skill tool twice, for "grilling" and "domain-modeling".
'@

$DOMAIN_MODELING_SKILL = @'
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
'@

# 主安装函数
function Install-GrillSkills {
    Write-Info "检测 DSH 配置目录..."
    
    $dshHome = Get-DSHHome
    
    if (-not $dshHome) {
        Write-Error "未找到 DSH 配置目录"
        Write-Info "请设置 DSH_HOME 环境变量，或确保 ~/.dsh 目录存在"
        exit 1
    }
    
    Write-Success "找到 DSH 配置目录: $dshHome"
    
    # 创建 skills 目录
    $skillsDir = Join-Path $dshHome "skills"
    Write-Info "创建技能目录: $skillsDir"
    New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
    
    # 安装 grilling 技能
    Write-Info "安装 grilling 技能..."
    $grillingDir = Join-Path $skillsDir "grilling"
    New-Item -ItemType Directory -Force -Path $grillingDir | Out-Null
    Set-Content -Path (Join-Path $grillingDir "SKILL.md") -Value $GRILLING_SKILL -Encoding UTF8
    Write-Success "grilling 技能安装完成"
    
    # 安装 grill-me 技能
    Write-Info "安装 grill-me 技能..."
    $grillMeDir = Join-Path $skillsDir "grill-me"
    New-Item -ItemType Directory -Force -Path $grillMeDir | Out-Null
    Set-Content -Path (Join-Path $grillMeDir "SKILL.md") -Value $GRILL_ME_SKILL -Encoding UTF8
    Write-Success "grill-me 技能安装完成"
    
    # 安装 grill-with-docs 技能
    Write-Info "安装 grill-with-docs 技能..."
    $grillWithDocsDir = Join-Path $skillsDir "grill-with-docs"
    New-Item -ItemType Directory -Force -Path $grillWithDocsDir | Out-Null
    Set-Content -Path (Join-Path $grillWithDocsDir "SKILL.md") -Value $GRILL_WITH_DOCS_SKILL -Encoding UTF8
    Write-Success "grill-with-docs 技能安装完成"
    
    # 安装 domain-modeling 技能
    Write-Info "安装 domain-modeling 技能..."
    $domainModelingDir = Join-Path $skillsDir "domain-modeling"
    New-Item -ItemType Directory -Force -Path $domainModelingDir | Out-Null
    Set-Content -Path (Join-Path $domainModelingDir "SKILL.md") -Value $DOMAIN_MODELING_SKILL -Encoding UTF8
    Write-Success "domain-modeling 技能安装完成"
    
    # 验证安装
    Write-Info "验证安装..."
    
    $allInstalled = $true
    foreach ($skill in @("grilling", "grill-me", "grill-with-docs", "domain-modeling")) {
        $skillFile = Join-Path $skillsDir "$skill\SKILL.md"
        if (Test-Path $skillFile) {
            Write-Success "✓ $skill"
        } else {
            Write-Error "✗ $skill 安装失败"
            $allInstalled = $false
        }
    }
    
    if ($allInstalled) {
        Write-Host ""
        Write-Success "=========================================="
        Write-Success "  Grill 技能安装成功！"
        Write-Success "=========================================="
        Write-Host ""
        Write-Info "使用方法："
        Write-Info "1. 重启 DSH: dsh web"
        Write-Info "2. 查看技能: /skills"
        Write-Info "3. 开始面试: /grill-me"
        Write-Info "4. 带文档面试: /grill-with-docs"
        Write-Host ""
    } else {
        Write-Error "部分技能安装失败，请检查权限或目录"
        exit 1
    }
}

# 运行安装
Install-GrillSkills
