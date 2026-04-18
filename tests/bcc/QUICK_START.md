#!/usr/bin/env bash
# BCC 工具快速开始指南

## 问题：工具未找到

如果遇到以下错误：

```bash
timeout: failed to run command 'execsnoop': No such file or directory
```

即使工具已安装在 `/usr/share/bcc/tools/`，这是因为工具不在 PATH 中。

## 解决方案

### 方案 1: 使用我们的测试脚本（推荐）

测试脚本会自动找到工具：

```bash
cd tests/bcc

# 运行测试（自动查找工具路径）
sudo ./test_execsnoop.sh
sudo ./test_opensnoop.sh
sudo ./test_cachestat.sh
```

### 方案 2: 设置 PATH 环境变量

```bash
# 临时设置（当前 shell 会话）
export PATH="/usr/share/bcc/tools:$PATH"

# 验证
which execsnoop

# 运行工具
sudo execsnoop
```

永久设置（添加到 ~/.bashrc）：

```bash
echo 'export PATH="/usr/share/bcc/tools:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 方案 3: 使用完整路径

```bash
sudo /usr/share/bcc/tools/execsnoop
sudo /usr/share/bcc/tools/opensnoop
```

### 方案 4: 使用通用包装脚本

```bash
cd tests/bcc

# 运行任何 BCC 工具
sudo ./run_bcc_tool.sh execsnoop
sudo ./run_bcc_tool.sh execsnoop -t
sudo ./run_bcc_tool.sh opensnoop -p 1234
```

## 验证安装

```bash
# 检查工具是否已安装
ls /usr/share/bcc/tools/

# 运行环境检查（自动设置 PATH）
sudo ./check_bcc.sh

# 测试单个工具
sudo ./run_bcc_tool.sh execsnoop -h
```

## 常用 BCC 工具位置

| 工具 | 通常路径 |
|------|---------|
| RHEL/Fedora | /usr/share/bcc/tools/ |
| Ubuntu/Debian | /usr/share/bcc/tools/ 或 /usr/sbin/ |
| 源码安装 | /usr/local/share/bcc/tools/ |

## 快速测试

```bash
cd tests/bcc

# 1. 检查环境
sudo ./check_bcc.sh

# 2. 测试一个工具
sudo ./test_execsnoop.sh

# 3. 运行所有测试（如果存在）
sudo ./run_all_tests.sh
```

## 工具查找顺序

我们的测试脚本按以下顺序查找工具：

1. PATH 中的命令
2. /usr/share/bcc/tools/
3. /usr/local/share/bcc/tools/
4. /opt/bcc/tools/

## 故障排查

### 问题：工具找不到

```bash
# 检查是否安装
rpm -ql bcc-tools | grep execsnoop   # RHEL/Fedora
dpkg -L bpfcc-tools | grep execsnoop # Ubuntu/Debian

# 手动查找
find /usr -name execsnoop 2>/dev/null
```

### 问题：权限错误

```bash
# 所有 BCC 工具都需要 root 权限
sudo ./test_execsnoop.sh

# 不要直接运行脚本
# ./test_execsnoop.sh  # 错误！
```

### 问题：内核兼容性

某些工具在特定内核版本可能失败：

```bash
# 查看内核版本
uname -r

# 运行兼容性检查
sudo ./check_bcc.sh

# 使用兼容版本
sudo python3 cachestat_wrapper.py
```

## 进阶使用

### 自定义 BCC 工具路径

```bash
# 设置自定义路径
export BCC_TOOLS_PATH="/opt/my-bcc/tools"

# 运行测试
sudo ./check_bcc.sh
```

### 在脚本中使用 BCC 工具

```bash
#!/bin/bash
source /path/to/tests/bcc/common.sh

# 查找工具
TOOL=$(find_bcc_tool execsnoop)

# 运行工具
"$TOOL" -t
```

## 参考

- BCC 项目: https://github.com/iovisor/bcc
- 安装指南: https://github.com/iovisor/bcc/blob/master/INSTALL.md
- 工具参考: https://github.com/iovisor/bcc/tree/master/tools
- 内核兼容性: [KERNEL_COMPATIBILITY.md](KERNEL_COMPATIBILITY.md)

---

更新日期：2026-04-18
