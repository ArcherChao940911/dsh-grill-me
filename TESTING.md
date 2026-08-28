# Grill 技能测试说明

## 测试环境准备

### 1. 确认 dsh 已安装并可用

```bash
# 检查 dsh 是否已安装
dsh --version

# 如果未安装，请先安装 dsh
npm install -g @deepseek-ai/dsh
```

### 2. 确认技能文件已正确放置

技能文件已放置在以下位置：

```
.dsh/skills/
├── domain-modeling/SKILL.md
├── grill-me/SKILL.md
├── grill-with-docs/SKILL.md
└── grilling/SKILL.md
```

### 3. 验证技能文件内容

```bash
# 检查 grilling 技能文件
cat .dsh/skills/grilling/SKILL.md

# 检查 grill-me 技能文件
cat .dsh/skills/grill-me/SKILL.md

# 检查 grill-with-docs 技能文件
cat .dsh/skills/grill-with-docs/SKILL.md

# 检查 domain-modeling 技能文件
cat .dsh/skills/domain-modeling/SKILL.md
```

## 测试步骤

### 测试 1：验证技能加载

1. 启动 dsh：
   ```bash
   dsh web
   ```

2. 在 dsh 中查看可用技能：
   ```
   /skills
   ```

3. 预期结果：应该看到以下技能：
   - `grilling` - Grill the user relentlessly about a plan, decision, or idea
   - `grill-me` - A relentless interview to sharpen a plan or design
   - `grill-with-docs` - A relentless interview to sharpen a plan or design, which also creates docs
   - `domain-modeling` - Build and sharpen a project's domain model

### 测试 2：测试 grill-me 技能

1. 在 dsh 中输入：
   ```
   /grill-me
   ```

2. 输入一个想法或计划，例如：
   ```
   我想做一个用户登录功能
   ```

3. 预期结果：
   - 模型应该开始面试式提问
   - 问题格式应该符合规范：
     ```
     ❓ **Q1** - **<问题标题>**: <问题正文>
     
     ➡️ <推荐答案>
     
     ---
     
     ❓ **Q2** - **<问题标题>**: <问题正文>
     
     ➡️ <推荐答案>
     ```
   - 每轮问题之间应该用 `---` 分隔
   - 模型应该等待用户回答后再问下一轮

### 测试 3：测试 grill-with-docs 技能

1. 在 dsh 中输入：
   ```
   /grill-with-docs
   ```

2. 输入一个想法或计划，例如：
   ```
   帮我梳理这个项目的领域术语
   ```

3. 预期结果：
   - 模型应该开始面试式提问（与 grill-me 类似）
   - 在面试过程中，模型应该：
     - 实时更新 `CONTEXT.md` 文件
     - 在满足条件时创建 ADR 文件
     - 将术语和决策记录到相应文件中

### 测试 4：验证领域建模功能

1. 使用 `grill-with-docs` 技能进行面试
2. 在面试中讨论领域术语和概念
3. 预期结果：
   - `CONTEXT.md` 文件应该被创建并实时更新
   - 文件应该只包含术语表，不包含实现细节
   - 满足 ADR 三关条件的决策应该被记录到 `docs/adr/` 目录

## 测试验证点

根据 SPEC.md 的验收标准：

### AC-1：技能加载验证
- ✅ 加载后，技能目录中应该包含 4 个 skill
- ✅ 名称分别为 `grilling`、`grill-me`、`grill-with-docs`、`domain-modeling`

### AC-2：调用策略验证
- ✅ `grill-me`、`grill-with-docs` 的 `modelInvocable === false`
- ✅ `grilling`、`domain-modeling` 的 `modelInvocable === true`

### AC-3：面试格式验证
- ✅ 运行 `/grill-me`，首轮输出为编号问题列表
- ✅ 每个问题带独立 `➡️` 推荐行
- ✅ 问题间以 `---` 分隔
- ✅ 可用编号作答

### AC-4：文档生成验证
- ✅ 运行 `/grill-with-docs`，面试中术语被解析时 `CONTEXT.md` 立即更新
- ✅ 非结尾一次性生成

### AC-5：事实查证验证
- ✅ 面试中属于「可查事实」的问题由 agent 读文件/sub-agent 解决
- ✅ 不反问用户

### AC-6：共识确认验证
- ✅ frontier 清空后，agent 停下并请求用户确认「已达成共识」
- ✅ 不擅自开始实施

## 故障排除

### 问题 1：技能未显示

**症状**：输入 `/skills` 后看不到 grill 相关技能

**可能原因**：
1. 技能文件路径不正确
2. 技能文件格式错误
3. dsh 未正确扫描技能目录

**解决方案**：
1. 检查 `.dsh/skills/` 目录是否存在
2. 检查 SKILL.md 文件格式是否正确
3. 重启 dsh 服务

### 问题 2：面试格式不正确

**症状**：模型提问格式不符合规范

**可能原因**：
1. 技能文件内容被修改
2. 模型未正确理解技能指令

**解决方案**：
1. 检查 `grilling/SKILL.md` 文件内容
2. 重置技能文件到原始版本

### 问题 3：文档未生成

**症状**：使用 `grill-with-docs` 时未生成文档

**可能原因**：
1. `domain-modeling` 技能未正确加载
2. 文件权限问题

**解决方案**：
1. 检查 `domain-modeling/SKILL.md` 文件是否存在
2. 检查文件写入权限

## 下一步

完成基本测试后，可以：

1. **自定义技能**：根据需要修改 SKILL.md 文件内容
2. **扩展功能**：添加更多 grill 相关技能
3. **优化体验**：根据使用反馈调整技能指令
4. **文档完善**：编写更详细的用户手册

## 参考资源

- [SPEC.md](./SPEC.md) - 项目规格说明书
- [README.md](./dsh-grill-plugin/README.md) - 项目说明文档
- [mattpocock/skills](https://github.com/mattpocock/skills) - 上游技能仓库
