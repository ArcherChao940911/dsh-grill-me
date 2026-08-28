# Grill Skills 一键安装指南

## 快速安装

### Linux / macOS

```bash
# 一键安装（从当前目录）
bash install-grill-skills.sh

# 或者从网络下载安装（如果脚本托管在 GitHub）
curl -fsSL https://raw.githubusercontent.com/your-username/dsh-grill/main/install-grill-skills.sh | bash
```

### Windows (PowerShell)

```powershell
# 一键安装（从当前目录）
.\install-grill-skills.ps1

# 或者从网络下载安装（如果脚本托管在 GitHub）
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/your-username/dsh-grill/main/install-grill-skills.ps1" -OutFile install-grill-skills.ps1; .\install-grill-skills.ps1
```

## 手动安装

如果一键安装脚本不工作，可以手动安装：

### 1. 找到 DSH 配置目录

```bash
# Linux/macOS
echo $HOME/.dsh

# Windows
echo %USERPROFILE%\.dsh
```

### 2. 创建技能目录

```bash
mkdir -p ~/.dsh/skills/grilling
mkdir -p ~/.dsh/skills/grill-me
mkdir -p ~/.dsh/skills/grill-with-docs
mkdir -p ~/.dsh/skills/domain-modeling
```

### 3. 复制技能文件

将以下文件复制到对应的目录：

- `skills/grilling/SKILL.md` → `~/.dsh/skills/grilling/SKILL.md`
- `skills/grill-me/SKILL.md` → `~/.dsh/skills/grill-me/SKILL.md`
- `skills/grill-with-docs/SKILL.md` → `~/.dsh/skills/grill-with-docs/SKILL.md`
- `skills/domain-modeling/SKILL.md` → `~/.dsh/skills/domain-modeling/SKILL.md`

### 4. 验证安装

```bash
ls -la ~/.dsh/skills/
```

应该看到四个目录：

```
drwxr-xr-x  2 user group  4096 Aug 28 10:39 domain-modeling
drwxr-xr-x  2 user group  4096 Aug 28 10:39 grill-me
drwxr-xr-x  2 user group  4096 Aug 28 10:39 grill-with-docs
drwxr-xr-x  2 user group  4096 Aug 28 10:39 grilling
```

## 使用方法

### 1. 重启 DSH

```bash
dsh web
```

### 2. 查看可用技能

在 DSH 中输入：

```
/skills
```

应该看到：

- `grilling` - Grill the user relentlessly about a plan, decision, or idea
- `grill-me` - A relentless interview to sharpen a plan or design
- `grill-with-docs` - A relentless interview to sharpen a plan or design, which also creates docs
- `domain-modeling` - Build and sharpen a project's domain model

### 3. 开始使用

- **无状态面试**：`/grill-me`
- **带文档生成的面试**：`/grill-with-docs`

## 卸载

如需卸载技能，删除对应的目录即可：

```bash
rm -rf ~/.dsh/skills/grilling
rm -rf ~/.dsh/skills/grill-me
rm -rf ~/.dsh/skills/grill-with-docs
rm -rf ~/.dsh/skills/domain-modeling
```

## 故障排除

### 问题：技能未显示

**解决方案**：

1. 确认技能文件已正确复制到 `~/.dsh/skills/` 目录
2. 确认每个目录下都有 `SKILL.md` 文件
3. 重启 DSH 服务

### 问题：权限错误

**解决方案**：

```bash
# Linux/macOS
chmod +x install-grill-skills.sh

# Windows (PowerShell)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 问题：DSH 配置目录不存在

**解决方案**：

```bash
# 创建 DSH 配置目录
mkdir -p ~/.dsh/skills
```

## 支持的平台

- ✅ Linux (x86_64, ARM64)
- ✅ macOS (Intel, Apple Silicon)
- ✅ Windows (PowerShell 5.1+)

## 依赖项

- DSH (DeepSeek Harness) 已安装
- Bash (Linux/macOS) 或 PowerShell (Windows)

## 许可证

MIT License
