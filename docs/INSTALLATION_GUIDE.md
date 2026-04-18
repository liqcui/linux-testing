# 智能安装指南

本文档说明如何使用智能安装脚本自动安装 BCC 和 bpftrace 工具。

## 概述

我们提供了智能安装脚本，能够：

- ✅ 自动检测操作系统和发行版
- ✅ 优先使用包管理器安装（快速）
- ✅ 包管理器失败时自动从源码编译
- ✅ 支持 RHEL、Debian、Arch 等主流发行版
- ✅ 检测虚拟化环境和容器
- ✅ 验证内核版本兼容性
- ✅ 自动配置系统环境

## 支持的平台

### 发行版支持

| 发行版系列 | 具体版本 | 包管理器 | 源码编译 |
|-----------|---------|---------|---------|
| RHEL | RHEL 7/8/9, CentOS 7/8, Fedora, Rocky, AlmaLinux | ✅ DNF/YUM | ✅ |
| Debian | Debian 9/10/11, Ubuntu 18.04/20.04/22.04 | ✅ APT | ✅ |
| Arch | Arch Linux, Manjaro, EndeavourOS | ✅ Pacman | ✅ |
| SUSE | openSUSE, SLES | ✅ Zypper | ✅ |
| Alpine | Alpine Linux | ⚠️ APK | ✅ |

### 架构支持

- ✅ x86_64 (amd64)
- ✅ aarch64 (arm64)
- ⚠️ 其他架构（可能需要从源码编译）

### 内核要求

| 工具 | 最低内核 | 推荐内核 |
|------|---------|---------|
| BCC | 4.4+ | 4.9+ |
| bpftrace | 4.9+ | 5.0+ |

## 快速开始

### 1. bpftrace 安装

```bash
cd tests/bpftrace

# 智能安装（推荐）
sudo ./install_bpftrace_auto.sh

# 或使用简单版本（仅包管理器）
sudo ./install_bpftrace.sh
```

### 2. BCC 工具安装

```bash
cd tests/bcc

# 智能安装（推荐）
sudo ./install_bcc_auto.sh

# 或使用简单版本（仅包管理器）
sudo ./setup/install-bcc.sh
```

## 安装流程详解

### 自动安装流程

```
开始
  ↓
检测系统信息（OS、内核、架构）
  ↓
检查内核版本是否满足要求
  ↓
尝试使用包管理器安装
  ├─ 成功 → 验证安装 → 配置环境 → 完成
  └─ 失败 → 询问是否从源码编译
              ├─ 是 → 安装依赖 → 克隆源码 → 编译 → 安装 → 完成
              └─ 否 → 退出
```

### 包管理器安装

**优点：**
- ⚡ 快速（通常 < 1 分钟）
- 📦 包管理器管理更新
- ✅ 经过发行版测试

**缺点：**
- 📅 版本可能较旧
- ⚠️ 某些发行版可能没有包

**示例输出：**
```bash
$ sudo ./install_bpftrace_auto.sh
╔═══════════════════════════════════════════════════════════╗
║         bpftrace 智能安装脚本                             ║
╚═══════════════════════════════════════════════════════════╝

[INFO] 检测系统信息...

  操作系统: Linux
  架构: x86_64
  内核版本: 6.2.15-100.fc36.x86_64
  发行版: Fedora Linux 36 (Server Edition)

[INFO] 检查内核版本要求...
[SUCCESS] 内核版本满足要求 (>= 4.9)

[INFO] 检测到 RHEL 系发行版
[INFO] 尝试使用 DNF 安装...
[SUCCESS] 使用 DNF 安装成功

[SUCCESS] bpftrace 安装成功
  版本: bpftrace v0.16.0
  路径: /usr/bin/bpftrace
  安装方式: DNF
```

### 源码编译安装

**优点：**
- 🆕 最新版本
- 🔧 自定义编译选项
- 🌍 支持任何发行版

**缺点：**
- ⏱️ 耗时长（15-45 分钟）
- 💾 需要更多磁盘空间
- 🔨 需要安装编译工具链

**示例输出：**
```bash
[WARNING] DNF 安装失败，尝试从源码安装
[INFO] 准备从源码编译安装 bpftrace...

[WARNING] 源码编译需要较长时间（10-30分钟）
是否继续? [y/N] y

[INFO] 安装编译依赖...
[INFO] 克隆 bpftrace 源码...
[INFO] 检出版本: v0.19.1
[INFO] 配置构建...
[INFO] 开始编译（这可能需要10-30分钟）...
[INFO] 使用 4 个并行任务
[INFO] 安装 bpftrace...
[SUCCESS] 从源码安装完成
```

## 平台特定说明

### RHEL/CentOS/Fedora

```bash
# 启用 EPEL 仓库（RHEL/CentOS 7/8）
sudo yum install epel-release

# 安装
sudo ./install_bpftrace_auto.sh
```

**已知问题：**
- RHEL 7: bpftrace 包可能不可用，需要从源码编译
- CentOS 8: CentOS Stream 替代，包可用性良好

### Ubuntu/Debian

```bash
# Ubuntu 18.04 或更早版本可能需要从源码编译
sudo ./install_bpftrace_auto.sh
```

**版本支持：**
- Ubuntu 19.04+: 包可用
- Ubuntu 18.04: 需要从源码编译
- Debian 10+: 包可用

### Arch Linux

```bash
# Arch 通常有最新的包
sudo ./install_bpftrace_auto.sh
```

### WSL (Windows Subsystem for Linux)

```bash
# WSL 2 支持 eBPF
# WSL 1 不支持

# 检查 WSL 版本
wsl --list --verbose

# 在 WSL 2 中安装
sudo ./install_bpftrace_auto.sh
```

## 虚拟机和容器

### 虚拟机

✅ **支持** - BCC 和 bpftrace 在虚拟机中完全可用

**注意事项：**
- 某些硬件性能计数器可能不可用
- 使用软件事件作为替代

**检测虚拟化：**
```bash
# 使用平台检测库
source setup/platform_detect.sh
is_virtual_machine && echo "运行在虚拟机: $VM_TYPE"
```

### Docker 容器

⚠️ **有限支持** - 需要特殊配置

**要求：**
```bash
# 运行容器时需要特权模式
docker run --privileged ...

# 或挂载内核模块
docker run -v /lib/modules:/lib/modules:ro \
           -v /usr/src:/usr/src:ro \
           --cap-add=SYS_ADMIN ...
```

### Kubernetes

⚠️ **需要配置** - 使用 DaemonSet 或特权 Pod

## 故障排查

### 问题 1: 包管理器安装失败

```bash
[ERROR] DNF 安装失败，尝试从源码安装
```

**解决方法：**
- 选择 `y` 继续从源码编译
- 或检查仓库配置：`dnf repolist`

### 问题 2: 源码编译失败

```bash
[ERROR] CMake 配置失败
```

**可能原因：**
1. 缺少依赖
2. LLVM/Clang 版本不兼容
3. 内核头文件缺失

**解决方法：**
```bash
# 检查依赖
rpm -qa | grep -E "llvm|clang|kernel-devel"  # RHEL
dpkg -l | grep -E "llvm|clang|linux-headers" # Debian

# 安装完整的编译依赖
sudo dnf groupinstall "Development Tools"    # RHEL
sudo apt-get install build-essential         # Debian
```

### 问题 3: 内核版本太旧

```bash
[ERROR] 内核版本 3.10.0 太旧
  BCC 需要内核 >= 4.4
```

**解决方法：**
```bash
# 检查可用内核
dnf list kernel --available  # RHEL
apt-cache search linux-image # Debian

# 升级内核
sudo dnf update kernel       # RHEL
sudo apt-get upgrade         # Debian

# 重启
sudo reboot
```

### 问题 4: 权限错误

```bash
[ERROR] 此脚本需要 root 权限
```

**解决方法：**
```bash
# 使用 sudo
sudo ./install_bpftrace_auto.sh
```

### 问题 5: 磁盘空间不足

源码编译需要约 2-5 GB 空间。

**检查空间：**
```bash
df -h /tmp
df -h /usr/local
```

**清理空间：**
```bash
# 清理包缓存
sudo dnf clean all           # RHEL
sudo apt-get clean           # Debian

# 清理旧内核
sudo dnf remove $(dnf repoquery --installonly --latest-limit=-1)
```

## 卸载

### 卸载包管理器安装的版本

```bash
# RHEL/Fedora
sudo dnf remove bpftrace
sudo dnf remove bcc-tools

# Debian/Ubuntu
sudo apt-get remove bpftrace
sudo apt-get remove bpfcc-tools
```

### 卸载源码编译的版本

```bash
# bpftrace
cd /tmp/bpftrace-build-*/bpftrace/build
sudo make uninstall

# BCC
cd /tmp/bcc-build-*/bcc/build
sudo make uninstall

# 或手动删除
sudo rm -f /usr/local/bin/bpftrace
sudo rm -rf /usr/local/share/bcc
```

## 验证安装

### 检查工具版本

```bash
# bpftrace
bpftrace --version

# BCC
ls /usr/share/bcc/tools/
python3 -c "import bcc; print(bcc.__version__)"
```

### 运行测试

```bash
# bpftrace
cd tests/bpftrace
sudo ./check_bpftrace.sh
sudo ./test_syscall_count.sh

# BCC
cd tests/bcc
sudo ./check_bcc.sh
sudo ./test_execsnoop.sh
```

### 简单功能测试

```bash
# bpftrace - 列出可用探针
sudo bpftrace -l 'kprobe:*' | head

# bpftrace - 简单测试
sudo bpftrace -e 'BEGIN { printf("Hello, bpftrace!\n"); exit(); }'

# BCC - 运行 execsnoop
sudo /usr/share/bcc/tools/execsnoop
```

## 高级选项

### 指定安装路径

编辑脚本中的 CMAKE 选项：

```bash
cmake -DCMAKE_INSTALL_PREFIX=/opt/bpftrace ..
```

### 使用特定 LLVM 版本

```bash
cmake -DLLVM_DIR=/usr/lib/llvm-14/cmake ..
```

### 仅安装工具（不安装 Python 绑定）

```bash
cmake -DPYTHON_BINDINGS=OFF ..
```

## 参考资料

- [bpftrace 官方安装文档](https://github.com/iovisor/bpftrace/blob/master/INSTALL.md)
- [BCC 官方安装文档](https://github.com/iovisor/bcc/blob/master/INSTALL.md)
- [平台检测库文档](../setup/platform_detect.sh)
- [内核兼容性指南](../tests/bcc/KERNEL_COMPATIBILITY.md)

---

更新日期：2026-04-18
版本：1.0
