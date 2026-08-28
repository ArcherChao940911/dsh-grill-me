# Grill Skills 快速安装

## 一条命令安装

### Linux / macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/your-username/dsh-grill/main/install-grill-skills.sh)
```

或者如果脚本在本地：

```bash
bash install-grill-skills.sh
```

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/your-username/dsh-grill/main/install-grill-skills.ps1" -OutFile install.ps1; .\install.ps1
```

或者如果脚本在本地：

```powershell
.\install-grill-skills.ps1
```

## 手动安装（3步）

### 1. 创建目录

```bash
mkdir -p ~/.dsh/skills/{grilling,grill-me,grill-with-docs,domain-modeling}
```

### 2. 复制文件

从项目目录复制技能文件：

```bash
cp -r skills/* ~/.dsh/skills/
```

### 3. 重启 DSH

```bash
dsh web
```

## 使用

在 DSH 中输入：

```
/grill-me
```

或

```
/grill-with-docs
```

## 验证安装

```bash
# 检查技能文件
ls -la ~/.dsh/skills/

# 在 DSH 中查看技能
/skills
```

## 卸载

```bash
rm -rf ~/.dsh/skills/{grilling,grill-me,grill-with-docs,domain-modeling}
```
