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
