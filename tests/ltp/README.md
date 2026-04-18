# LTP (Linux Test Project) 测试指南

## 概述

LTP (Linux Test Project) 是一个用于验证 Linux 内核可靠性、健壮性和稳定性的综合测试套件。它包含超过 3000 个测试用例，涵盖系统调用、文件系统、内存管理、网络、调度等各个子系统。

## 安装 LTP

### 方法 1: 从源码编译安装（推荐）

```bash
# 克隆 LTP 仓库
git clone https://github.com/linux-test-project/ltp.git
cd ltp

# 安装依赖（Ubuntu/Debian）
sudo apt-get install -y \
    autoconf automake make gcc git \
    bison flex m4 \
    libc6-dev \
    libacl1-dev \
    libaio-dev \
    libcap-dev \
    libkeyutils-dev \
    libnuma-dev \
    libselinux1-dev \
    libssl-dev

# 安装依赖（RHEL/CentOS/Fedora）
sudo yum install -y \
    autoconf automake make gcc git \
    bison flex m4 \
    glibc-devel \
    libacl-devel \
    libaio-devel \
    libcap-devel \
    keyutils-libs-devel \
    numactl-devel \
    libselinux-devel \
    openssl-devel

# 构建和安装
make autotools
./configure --prefix=/opt/ltp
make
sudo make install
```

### 方法 2: 使用包管理器

```bash
# Ubuntu/Debian
sudo apt-get install ltp

# RHEL/CentOS
sudo yum install ltp

# Fedora
sudo dnf install ltp
```

### 验证安装

```bash
# 检查安装路径
ls -l /opt/ltp/

# 查看 runltp 脚本
/opt/ltp/runltp --help
```

## 基本使用

### 1. 运行全部测试

**警告：全部测试耗时数小时，需要 root 权限**

```bash
cd /opt/ltp

# 运行全部测试，生成详细日志
sudo ./runltp -p -l ltp-full.log -o ltp-output.log

# 参数说明：
#   -p          : 打印测试输出到终端
#   -l <file>   : 指定日志文件
#   -o <file>   : 指定输出文件
```

### 2. 运行特定测试集

LTP 提供多个预定义的测试场景文件（scenario files）：

```bash
cd /opt/ltp

# 系统调用测试（约 1-2 小时）
sudo ./runltp -f syscalls -l syscalls.log -o syscalls.out

# 内存管理测试（约 30 分钟）
sudo ./runltp -f mm -l mm.log -o mm.out

# 文件系统测试（约 1 小时）
sudo ./runltp -f fs -l fs.log -o fs.out

# IPC（进程间通信）测试（约 20 分钟）
sudo ./runltp -f ipc -l ipc.log -o ipc.out

# 调度器测试（约 30 分钟）
sudo ./runltp -f sched -l sched.log -o sched.out

# 网络 TCP 命令测试
sudo ./runltp -f net.tcp_cmds -l net_tcp.log -o net_tcp.out

# 数学函数测试
sudo ./runltp -f math -l math.log -o math.out

# 容器测试
sudo ./runltp -f containers -l containers.log -o containers.out

# cgroup 测试
sudo ./runltp -f cgroup -l cgroup.log -o cgroup.out

# 命名空间测试
sudo ./runltp -f namespaces -l namespaces.log -o namespaces.out
```

### 3. 压力测试模式

```bash
cd /opt/ltp

# 运行 72 小时压力测试
sudo ./runltp -p -t 72h -f stress -l stress-72h.log

# 运行 24 小时压力测试
sudo ./runltp -p -t 24h -f stress -l stress-24h.log

# 运行 1 小时压力测试（快速验证）
sudo ./runltp -p -t 1h -f stress -l stress-1h.log

# 参数说明：
#   -t <duration> : 运行时长（支持 s/m/h/d 单位）
#   -f stress     : 使用 stress 测试场景
```

### 4. 自定义测试场景

创建自定义测试场景文件，组合多个测试集：

```bash
cd /opt/ltp

# 创建自定义场景文件
cat > myscenario << 'EOF'
# 核心功能测试
syscalls
mm
fs
sched

# 网络测试
net.tcp_cmds
net.ipv6

# IPC 测试
ipc
EOF

# 运行自定义场景
sudo ./runltp -f myscenario -l custom.log -o custom.out
```

### 5. 运行单个测试

```bash
cd /opt/ltp/testcases/bin

# 运行单个测试程序
sudo ./abort01

# 运行带参数的测试
sudo ./access01

# 查看测试源码位置
ls -l /opt/ltp/testcases/kernel/syscalls/access/
```

## 常用测试场景

### 完整测试场景列表

测试场景文件位于 `/opt/ltp/runtest/` 目录：

```bash
# 查看所有可用场景
ls /opt/ltp/runtest/

# 常用场景：
# - syscalls        : 系统调用测试
# - mm              : 内存管理
# - fs              : 文件系统
# - fs_perms_simple : 文件系统权限
# - ipc             : 进程间通信
# - sched           : 进程调度
# - math            : 数学库
# - nptl            : POSIX 线程
# - pty             : 伪终端
# - containers      : 容器
# - cgroup          : cgroup
# - namespaces      : 命名空间
# - net.*           : 网络测试（多个）
# - stress          : 压力测试
# - timers          : 定时器
# - io              : I/O 测试
# - cap_bounds      : 能力边界
# - commands        : 系统命令
# - dio             : 直接 I/O
```

### 按子系统分类测试

#### 内核核心功能
```bash
sudo ./runltp -f syscalls     # 系统调用
sudo ./runltp -f mm           # 内存管理
sudo ./runltp -f sched        # 调度器
sudo ./runltp -f timers       # 定时器
sudo ./runltp -f ipc          # IPC
```

#### 文件系统测试
```bash
sudo ./runltp -f fs                  # 通用文件系统
sudo ./runltp -f fs_perms_simple     # 权限测试
sudo ./runltp -f fs_readonly         # 只读文件系统
sudo ./runltp -f fs_ext4             # ext4 特定测试
sudo ./runltp -f dio                 # 直接 I/O
```

#### 网络测试
```bash
sudo ./runltp -f net.ipv6            # IPv6
sudo ./runltp -f net.tcp_cmds        # TCP 命令
sudo ./runltp -f net.udp             # UDP
sudo ./runltp -f net.sctp            # SCTP
sudo ./runltp -f net.rpc             # RPC
sudo ./runltp -f net.nfs             # NFS
```

#### 容器和命名空间
```bash
sudo ./runltp -f containers          # 容器测试
sudo ./runltp -f cgroup              # cgroup v1/v2
sudo ./runltp -f namespaces          # 命名空间
```

#### 安全测试
```bash
sudo ./runltp -f cap_bounds          # Capability bounds
sudo ./runltp -f securebits          # Secure bits
sudo ./runltp -f selinux             # SELinux（如果启用）
```

## 高级用法

### 1. 并行执行测试

```bash
# 使用多个 CPU 并行运行（加快测试速度）
sudo ./runltp -f syscalls -q -j 4

# 参数说明：
#   -q        : 安静模式，减少输出
#   -j <num>  : 并行任务数
```

### 2. 跳过特定测试

```bash
# 创建跳过列表
cat > skiplist << 'EOF'
# 跳过已知失败的测试
abort01
access01
EOF

# 使用跳过列表
sudo ./runltp -f syscalls -S skiplist
```

### 3. 只运行失败的测试

```bash
# 第一次运行
sudo ./runltp -f syscalls -l test1.log

# 只重跑失败的测试
sudo ./runltp -f syscalls -l test2.log -r test1.log
```

### 4. 设置临时目录

```bash
# 指定临时文件目录（默认 /tmp）
sudo ./runltp -f fs -d /mnt/test-tmp

# 对于需要大空间的测试很有用
```

### 5. 测试网络功能

```bash
# 设置远程测试主机（双机测试）
export RHOST=192.168.1.100
export PASSWD=password

sudo ./runltp -f net.tcp_cmds
```

## 结果分析

### 日志文件结构

运行 LTP 后会生成多个文件：

```
ltp-full.log        # 主日志文件
ltp-output.log      # 详细输出
results/            # 结果目录
├── LTP_RUN_ON      # 运行信息
├── summary         # 测试摘要
└── failed          # 失败的测试
```

### 查看测试结果

```bash
# 查看测试摘要
cat /opt/ltp/results/summary

# 示例输出：
# Total Tests: 2500
# Total Skipped Tests: 50
# Total Failures: 3
# Kernel Version: 5.15.0
# Machine Architecture: x86_64
# Hostname: test-machine
# Total Execution Time: 3h 45m 12s

# 查看失败的测试
cat /opt/ltp/results/failed

# 搜索特定测试结果
grep "PASS" ltp-output.log | wc -l     # 通过的测试数
grep "FAIL" ltp-output.log | wc -l     # 失败的测试数
grep "CONF" ltp-output.log | wc -l     # 配置问题
grep "BROK" ltp-output.log | wc -l     # 中断的测试
```

### 结果状态说明

| 状态 | 说明 |
|------|------|
| PASS | 测试通过 |
| FAIL | 测试失败（发现 bug） |
| CONF | 配置问题（测试未运行） |
| BROK | 测试中断（测试程序错误） |
| WARN | 警告（可能有问题） |
| TINFO | 信息（仅提示） |

### 分析失败测试

```bash
# 提取失败测试的详细信息
grep -A 10 "FAIL" ltp-output.log

# 查看特定测试的输出
grep -A 20 "test_name" ltp-output.log

# 检查内核日志中的相关错误
dmesg | grep -i "error\|bug\|oops"
```

## 快速测试示例

### 快速验证测试（30 分钟）

```bash
cd /opt/ltp

# 创建快速测试场景
cat > quick-test << 'EOF'
syscalls
mm
sched
ipc
EOF

sudo ./runltp -f quick-test -l quick.log -o quick.out
```

### 核心功能测试（2-3 小时）

```bash
cd /opt/ltp

cat > core-test << 'EOF'
syscalls
mm
fs
sched
ipc
timers
nptl
EOF

sudo ./runltp -f core-test -l core.log -o core.out
```

### 完整回归测试（6-8 小时）

```bash
cd /opt/ltp

cat > regression-test << 'EOF'
syscalls
mm
fs
fs_perms_simple
sched
ipc
timers
nptl
io
dio
pty
containers
cgroup
namespaces
math
commands
EOF

sudo ./runltp -f regression-test -l regression.log -o regression.out
```

## 持续集成 (CI) 集成

### 示例 CI 脚本

```bash
#!/bin/bash
# ci-ltp-test.sh - LTP CI 测试脚本

set -e

LTP_DIR="/opt/ltp"
RESULTS_DIR="./ltp-results-$(date +%Y%m%d-%H%M%S)"
SCENARIO="quick-test"

mkdir -p "$RESULTS_DIR"

cd "$LTP_DIR"

# 运行测试
sudo ./runltp -f "$SCENARIO" \
    -l "$RESULTS_DIR/test.log" \
    -o "$RESULTS_DIR/output.log" \
    -q

# 检查结果
if grep -q "FAIL" "$RESULTS_DIR/output.log"; then
    echo "Tests FAILED"
    grep "FAIL" "$RESULTS_DIR/output.log"
    exit 1
else
    echo "All tests PASSED"
    exit 0
fi
```

## 故障排查

### 常见问题

#### 1. 权限错误
```bash
# 错误: Permission denied
# 解决: 使用 sudo 运行
sudo ./runltp -f syscalls
```

#### 2. 临时空间不足
```bash
# 错误: No space left on device
# 解决: 清理 /tmp 或指定其他目录
df -h /tmp
sudo ./runltp -f fs -d /mnt/large-disk/ltp-tmp
```

#### 3. 内核模块缺失
```bash
# 错误: modprobe: FATAL: Module not found
# 解决: 安装所需内核模块或跳过相关测试
sudo modprobe <module_name>
# 或添加到 skiplist
```

#### 4. 网络测试失败
```bash
# 确保网络配置正确
ping -c 1 127.0.0.1
ping -c 1 $RHOST

# 检查防火墙
sudo iptables -L
```

#### 5. 超时
```bash
# 增加超时时间
export LTP_TIMEOUT_MUL=3

# 或在 runltp 中设置
sudo ./runltp -f syscalls -T 300  # 300 秒超时
```

## 最佳实践

### 1. 测试前准备
- 备份重要数据
- 确保足够的磁盘空间（至少 10GB）
- 关闭不必要的服务
- 记录系统配置和内核版本

### 2. 测试执行
- 从小测试集开始
- 使用日志文件记录所有输出
- 在测试环境而非生产环境运行
- 监控系统资源使用

### 3. 结果分析
- 保存所有测试结果
- 对比不同内核版本的结果
- 记录失败测试的详细信息
- 向内核维护者报告 bug

### 4. 定期测试
- 内核升级后运行 LTP
- 系统配置更改后验证
- 定期运行压力测试
- 建立测试结果基线

## 参考资源

- **官方网站**: https://linux-test-project.github.io/
- **GitHub 仓库**: https://github.com/linux-test-project/ltp
- **Wiki 文档**: https://github.com/linux-test-project/ltp/wiki
- **邮件列表**: ltp@lists.linux.it
- **IRC**: #ltp on irc.oftc.net

## 相关工具

- **stress-ng**: 系统压力测试
- **kselftest**: 内核自测试
- **Trinity**: 系统调用模糊测试
- **Syzkaller**: 内核模糊测试

---

**更新日期：** 2026-04-18
**LTP 版本：** 建议使用最新稳定版
**文档版本：** 1.0
