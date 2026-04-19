# BCC/bpftrace eBPF 追踪工具测试套件

## 概述

本测试套件提供了全面的eBPF追踪工具测试，包括BCC工具集和bpftrace脚本。eBPF是Linux内核中的革命性技术，允许在内核中安全高效地运行用户定义的程序，用于性能分析、安全审计、网络监控等场景。

## eBPF 技术介绍

### 什么是 eBPF

**eBPF (extended Berkeley Packet Filter)** 是Linux内核中的一种强大技术，可以在不修改内核源码或加载内核模块的情况下运行沙箱程序。

```
用户空间                     内核空间
┌─────────────┐            ┌─────────────┐
│             │            │             │
│  BCC/       │ eBPF程序   │   eBPF      │
│  bpftrace   │───编译────>│  验证器     │
│  工具       │            │             │
│             │            └──────┬──────┘
│             │                   │
│             │            ┌──────▼──────┐
│             │            │   JIT       │
│             │   数据     │  编译器     │
│             │<─────────  │             │
│             │  (maps)    └──────┬──────┘
│             │                   │
│             │            ┌──────▼──────┐
│             │            │  探测点     │
│             │            │ kprobe/     │
│             │            │ tracepoint  │
└─────────────┘            └─────────────┘
```

**核心优势:**
- ✓ **安全性**: 验证器确保不会crash内核
- ✓ **零开销**: 未启用时对系统无影响
- ✓ **动态性**: 无需重启或重新编译内核
- ✓ **高效性**: JIT编译为本地机器码
- ✓ **灵活性**: 可追踪内核和用户空间

### BCC vs bpftrace

| 特性 | BCC | bpftrace |
|------|-----|----------|
| **语言** | Python + C | 类awk脚本 |
| **易用性** | ★★★☆☆ 需要编程 | ★★★★★ 非常简单 |
| **灵活性** | ★★★★★ 完全控制 | ★★★★☆ 大部分场景 |
| **性能** | ★★★★★ 优秀 | ★★★★★ 优秀 |
| **工具集** | 70+ 预制工具 | 脚本库 |
| **适用场景** | 复杂追踪、长期监控 | 快速分析、一次性追踪 |
| **学习曲线** | 较陡 | 平缓 |

**使用建议:**
- **快速排查**: 使用bpftrace一行代码
- **深入分析**: 使用BCC工具或编写程序
- **生产监控**: 使用BCC工具

## 目录结构

```
ebpf/
├── README.md                     # 本文件
├── INTERPRETATION_GUIDE.md       # 结果详细解读指南
├── scripts/
│   ├── test_bcc.sh               # BCC工具综合测试
│   ├── test_bpftrace.sh          # bpftrace脚本测试
│   └── bpftrace/                 # bpftrace脚本库
│       ├── syscall_count.bt      # 系统调用统计
│       ├── vfs_latency.bt        # VFS I/O延迟
│       ├── tcp_connect_latency.bt # TCP连接延迟
│       ├── kmalloc_stats.bt      # 内存分配统计
│       └── sched_latency.bt      # CPU调度延迟
└── results/                      # 测试结果（自动生成）
```

## 安装

### 内核要求

- **最低版本**: Linux 4.1+
- **推荐版本**: Linux 4.9+ (完整eBPF支持)
- **最佳版本**: Linux 5.0+ (所有特性)

检查内核版本:
```bash
uname -r
```

### 安装 BCC

**Ubuntu/Debian 20.04+:**
```bash
sudo apt-get update
sudo apt-get install bpfcc-tools linux-headers-$(uname -r)
```

**Ubuntu 18.04:**
```bash
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD
echo "deb https://repo.iovisor.org/apt/$(lsb_release -cs) $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/iovisor.list
sudo apt-get update
sudo apt-get install bcc-tools libbcc-examples linux-headers-$(uname -r)
```

**RHEL/CentOS 8+:**
```bash
sudo dnf install bcc-tools kernel-devel-$(uname -r)
```

**Fedora:**
```bash
sudo dnf install bcc-tools kernel-devel
```

**验证安装:**
```bash
# 检查BCC工具
ls /usr/share/bcc/tools/

# 测试execsnoop
sudo execsnoop
```

### 安装 bpftrace

**Ubuntu/Debian 20.04+:**
```bash
sudo apt-get install bpftrace
```

**RHEL/CentOS 8+:**
```bash
sudo dnf install bpftrace
```

**Fedora:**
```bash
sudo dnf install bpftrace
```

**验证安装:**
```bash
bpftrace --version
```

## 快速开始

### BCC 工具测试

```bash
cd scripts

# 系统范围测试（10秒）
sudo ./test_bcc.sh -d 10

# 指定进程PID测试（30秒）
sudo ./test_bcc.sh -p 1234 -d 30

# 指定进程名称测试
sudo ./test_bcc.sh -n nginx -d 30
```

**输出示例:**
```
bcc_test_20260419_143022/
├── principles.txt              # BCC原理说明
├── execsnoop.txt               # 进程执行监控
├── opensnoop.txt               # 文件打开监控
├── biolatency.txt              # 块I/O延迟
├── tcpconnect.txt              # TCP连接追踪
├── tcplife.txt                 # TCP连接生命周期
├── ext4slower.txt              # 慢速文件操作
├── profile.txt                 # CPU采样分析
└── summary_report.txt          # 综合报告
```

### bpftrace 脚本测试

```bash
cd scripts

# 执行所有bpftrace脚本（10秒）
sudo ./test_bpftrace.sh -d 10

# 单独运行脚本
sudo bpftrace bpftrace/syscall_count.bt
sudo bpftrace bpftrace/vfs_latency.bt
sudo bpftrace bpftrace/tcp_connect_latency.bt
```

**输出示例:**
```
bpftrace_test_20260419_143022/
├── principles.txt              # bpftrace原理
├── syscall_count.txt           # 系统调用统计
├── vfs_latency.txt             # VFS延迟分析
├── tcp_connect_latency.txt     # TCP连接延迟
├── kmalloc_stats.txt           # 内存分配统计
├── sched_latency.txt           # 调度延迟分析
└── summary_report.txt          # 综合报告
```

## BCC 工具详解

### 1. execsnoop - 进程执行监控

**功能:** 实时监控所有 `exec()` 系统调用

**应用场景:**
- 安全审计: 发现可疑进程启动
- 性能分析: 找到频繁fork/exec的进程
- 容器监控: 追踪容器内进程
- 脚本调试: 查看shell脚本执行了哪些命令

**使用方法:**
```bash
# 监控所有进程
sudo execsnoop

# 监控失败的exec
sudo execsnoop -x

# 监控特定用户
sudo execsnoop -u root

# 打印时间戳
sudo execsnoop -t
```

**输出字段:**
- **PCOMM**: 父进程名称
- **PID**: 进程ID
- **PPID**: 父进程ID
- **RET**: 返回值（0=成功，负值=错误码）
- **ARGS**: 完整命令行参数

**典型问题:**
```
现象: RET = -2 (ENOENT)
原因: 可执行文件不存在
解决: 检查PATH或安装缺失程序

现象: 每秒数百次exec
原因: Shell脚本频繁调用外部命令
解决: 使用shell内置命令、批量处理
```

### 2. opensnoop - 文件打开监控

**功能:** 实时监控所有 `open()` 和 `openat()` 系统调用

**应用场景:**
- 性能分析: 找到频繁打开的文件
- 配置审计: 查看程序读取哪些配置文件
- 故障排查: 定位文件未找到错误
- 安全监控: 检测敏感文件访问

**使用方法:**
```bash
# 监控所有文件打开
sudo opensnoop

# 监控特定进程
sudo opensnoop -p 1234

# 监控失败的open
sudo opensnoop -x

# 监控特定文件名
sudo opensnoop -n passwd
```

**输出字段:**
- **PID**: 进程ID
- **COMM**: 进程名称
- **FD**: 文件描述符（-1表示失败）
- **ERR**: 错误码
- **PATH**: 文件路径

**典型问题:**
```
现象: 配置文件每秒被打开数百次
影响: I/O开销、文件系统缓存污染
优化: 启动时读取一次，内存缓存

现象: ERR = 24 (EMFILE)
原因: 达到进程文件描述符限制
解决: 提高ulimit限制
```

### 3. biolatency - 块I/O延迟分析

**功能:** 统计块设备I/O请求的延迟分布

**应用场景:**
- 存储性能分析: 识别I/O延迟问题
- 磁盘健康检查: 发现慢盘
- 应用调优: 优化I/O模式
- SSD vs HDD对比

**使用方法:**
```bash
# 显示延迟直方图（每秒更新）
sudo biolatency 1

# 按磁盘分组
sudo biolatency -D

# 按标志分组（读/写）
sudo biolatency -F

# 显示毫秒级延迟
sudo biolatency -m
```

**延迟评估标准:**
```
SSD性能:
  <  100 us  → ★★★★★ 优秀
  100-500 us → ★★★★☆ 良好
  500us-1ms  → ★★★☆☆ 一般
  > 1 ms     → ★★☆☆☆ 需检查

机械硬盘:
  1-10 ms    → ★★★★☆ 正常
  10-50 ms   → ★★★☆☆ 可接受
  > 50 ms    → ★★☆☆☆ 性能问题
```

### 4. tcpconnect - TCP连接追踪

**功能:** 追踪所有TCP主动连接（connect()调用）

**应用场景:**
- 网络审计: 查看程序连接的外部服务
- 故障排查: 定位连接失败问题
- 安全监控: 发现异常外连行为
- 微服务追踪: 监控服务间调用

**使用方法:**
```bash
# 追踪所有TCP连接
sudo tcpconnect

# 追踪特定端口
sudo tcpconnect -P 443

# 追踪特定进程
sudo tcpconnect -p 1234

# 统计连接数
sudo tcpconnect -c
```

**常见端口识别:**
- 53: DNS
- 80: HTTP
- 443: HTTPS
- 3306: MySQL
- 5432: PostgreSQL
- 6379: Redis
- 9200: Elasticsearch

### 5. tcplife - TCP连接生命周期

**功能:** 追踪TCP连接的完整生命周期和数据传输

**应用场景:**
- 性能分析: 识别长连接和短连接
- 网络优化: 分析连接复用效率
- 容量规划: 统计连接数和流量
- 异常检测: 发现异常长或短的连接

**使用方法:**
```bash
# 显示所有连接
sudo tcplife

# 显示本地端口
sudo tcplife -L

# 显示特定端口
sudo tcplife -D 80

# 只显示>1秒的连接
sudo tcplife 1000
```

**输出字段:**
- **TX_KB**: 发送数据（KB）
- **RX_KB**: 接收数据（KB）
- **MS**: 连接持续时间（毫秒）

**连接效率分析:**
```
HTTP/1.0短连接问题:
  MS = 5-20 ms
  TX/RX < 5 KB
  频率: 数百次/秒
  → 升级到HTTP/1.1 Keep-Alive

WebSocket长连接正常:
  MS > 60000 (1分钟)
  TX/RX持续有数据
  → 符合预期
```

### 6. ext4slower - 慢速文件系统操作

**功能:** 追踪超过阈值的ext4文件系统操作

**应用场景:**
- 性能诊断: 找到慢速文件操作
- 存储优化: 识别I/O瓶颈
- 应用调优: 优化文件访问模式

**使用方法:**
```bash
# 追踪>10ms的操作
sudo ext4slower 10

# 追踪>1ms的操作
sudo ext4slower 1

# 追踪特定PID
sudo ext4slower -p 1234
```

**操作类型:**
- **R**: Read（读）
- **W**: Write（写）
- **O**: Open（打开）
- **S**: Sync（同步）

### 7. profile - CPU采样分析

**功能:** 基于定时器的CPU采样，类似perf

**应用场景:**
- CPU热点分析
- 性能剖析
- 调用栈追踪
- 火焰图生成

**使用方法:**
```bash
# 系统范围采样（99Hz）
sudo profile

# 指定采样频率
sudo profile -F 999

# 只采样用户态
sudo profile -U

# 只采样内核态
sudo profile -K

# 采样特定进程
sudo profile -p 1234
```

## bpftrace 脚本详解

### 1. syscall_count.bt - 系统调用统计

**功能:** 统计每个系统调用的调用次数

**应用场景:**
- 性能优化: 识别频繁的系统调用
- 异常检测: 发现异常高频的系统调用
- 容量规划: 评估系统调用开销

**脚本内容:**
```bpftrace
tracepoint:raw_syscalls:sys_enter
{
    @syscall[args->id] = count();
}
```

**运行:**
```bash
sudo bpftrace syscall_count.bt
```

### 2. vfs_latency.bt - VFS I/O延迟

**功能:** 追踪VFS read/write延迟直方图

**应用场景:**
- I/O性能分析
- 存储瓶颈定位
- 应用调优

**脚本内容:**
```bpftrace
kprobe:vfs_read,
kprobe:vfs_write
{
    @start[tid] = nsecs;
    @io_type[tid] = func;
}

kretprobe:vfs_read,
kretprobe:vfs_write
/@start[tid]/
{
    $duration_us = (nsecs - @start[tid]) / 1000;
    @latency_us[str(@io_type[tid])] = hist($duration_us);
    delete(@start[tid]);
    delete(@io_type[tid]);
}
```

**运行:**
```bash
sudo bpftrace vfs_latency.bt
```

### 3. tcp_connect_latency.bt - TCP连接延迟

**功能:** 测量TCP连接建立的延迟

**应用场景:**
- 网络性能分析
- 连接超时排查
- 微服务性能优化

**运行:**
```bash
sudo bpftrace tcp_connect_latency.bt
```

### 4. kmalloc_stats.bt - 内存分配统计

**功能:** 统计kmalloc分配大小和调用栈

**应用场景:**
- 内存泄漏排查
- 内存使用优化
- 内核模块分析

**运行:**
```bash
sudo bpftrace kmalloc_stats.bt
```

### 5. sched_latency.bt - CPU调度延迟

**功能:** 测量进程从唤醒到运行的延迟

**应用场景:**
- 实时性能评估
- 调度器优化
- 延迟敏感应用分析

**运行:**
```bash
sudo bpftrace sched_latency.bt
```

## bpftrace 一行代码示例

### 系统调用追踪

```bash
# 统计系统调用
bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); }'

# 追踪进程创建
bpftrace -e 'tracepoint:sched:sched_process_exec { printf("%s\n", str(args->filename)); }'

# 文件打开监控
bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args->filename)); }'
```

### 网络追踪

```bash
# TCP连接监控
bpftrace -e 'kprobe:tcp_connect { printf("%s\n", comm); }'

# TCP发送字节统计
bpftrace -e 'kprobe:tcp_sendmsg { @bytes[comm] = sum(arg2); }'
```

### 性能采样

```bash
# CPU采样（99Hz）
bpftrace -e 'profile:hz:99 { @[kstack] = count(); }'

# 用户态栈采样
bpftrace -e 'profile:hz:99 { @[ustack] = count(); }'
```

### I/O追踪

```bash
# 块I/O大小直方图
bpftrace -e 'tracepoint:block:block_rq_issue { @bytes = hist(args->bytes); }'

# VFS读写统计
bpftrace -e 'kprobe:vfs_read,kprobe:vfs_write { @[func] = count(); }'
```

## 典型使用场景

### 场景1: Web服务性能分析

**问题:** Nginx CPU使用率高

**分析步骤:**
```bash
# 1. 查看进程在执行什么
sudo execsnoop -n nginx

# 2. 查看打开了哪些文件
sudo opensnoop -n nginx

# 3. TCP连接模式
sudo tcplife -n nginx

# 4. CPU热点
sudo profile -p $(pidof nginx)
```

### 场景2: 数据库I/O问题

**问题:** MySQL查询慢

**分析步骤:**
```bash
# 1. I/O延迟分布
sudo biolatency -D 1

# 2. 慢速文件操作
sudo ext4slower 10

# 3. VFS延迟分析
sudo bpftrace vfs_latency.bt

# 4. 系统调用统计
sudo bpftrace syscall_count.bt
```

### 场景3: 容器监控

**问题:** 追踪容器内进程行为

**分析步骤:**
```bash
# 1. 监控容器进程创建
sudo execsnoop | grep container_name

# 2. 监控容器文件访问
sudo opensnoop | grep container_name

# 3. 监控容器网络连接
sudo tcpconnect | grep container_name
```

### 场景4: 内存泄漏排查

**问题:** 进程内存持续增长

**分析步骤:**
```bash
# 1. 追踪大块内存分配
sudo bpftrace kmalloc_stats.bt

# 2. 追踪特定进程的malloc
sudo bpftrace -e 'uprobe:/lib/x86_64-linux-gnu/libc.so.6:malloc { @[ustack] = count(); }' -p PID
```

### 场景5: 调度延迟问题

**问题:** 应用响应时间不稳定

**分析步骤:**
```bash
# 1. 调度延迟分析
sudo bpftrace sched_latency.bt

# 2. 上下文切换统计
sudo bpftrace -e 'tracepoint:sched:sched_switch { @[comm] = count(); }'
```

## 高级技巧

### 1. 过滤和聚合

```bash
# 只追踪特定进程
bpftrace -e 'kprobe:do_sys_open /comm == "nginx"/ { @[str(arg1)] = count(); }'

# 按进程分组统计
bpftrace -e 'kprobe:tcp_sendmsg { @bytes[comm] = sum(arg2); }'

# 按时间间隔输出
bpftrace -e 'interval:s:1 { print(@); clear(@); }'
```

### 2. 调用栈追踪

```bash
# 内核栈
bpftrace -e 'kprobe:do_nanosleep { printf("%s\n", kstack); }'

# 用户栈
bpftrace -e 'uprobe:/bin/bash:readline { printf("%s\n", ustack); }'

# 内核+用户栈
bpftrace -e 'kprobe:do_sys_open { printf("%s\n%s\n", kstack, ustack); }'
```

### 3. 性能优化

```bash
# 减少输出（使用maps聚合）
bpftrace -e 'kprobe:vfs_read { @[comm] = count(); }'

# 限制采样频率
bpftrace -e 'profile:hz:49 { @[kstack] = count(); }'

# 早期过滤
bpftrace -e 'kprobe:tcp_sendmsg /arg2 > 1024/ { @bytes = sum(arg2); }'
```

## 故障诊断

### 问题1: 权限不足

**症状:**
```
ERROR: Could not open perf_event for cpu 0: Permission denied
```

**解决:**
```bash
# 方案1: 临时调整
sudo sysctl -w kernel.perf_event_paranoid=-1

# 方案2: 使用sudo
sudo bpftrace script.bt

# 方案3: 永久配置
echo "kernel.perf_event_paranoid = -1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 问题2: 内核版本不支持

**症状:**
```
kernel too old for feature XYZ
```

**解决:**
```bash
# 检查内核版本
uname -r

# 升级内核（Ubuntu）
sudo apt-get install linux-generic-hwe-20.04

# 升级内核（RHEL）
sudo yum update kernel
```

### 问题3: BCC工具找不到

**症状:**
```
command not found: execsnoop
```

**解决:**
```bash
# Ubuntu/Debian
# BCC工具通常在 /usr/share/bcc/tools/
ls /usr/share/bcc/tools/

# 添加到PATH
export PATH=$PATH:/usr/share/bcc/tools

# 或使用完整路径
sudo /usr/share/bcc/tools/execsnoop
```

### 问题4: 符号缺失

**症状:** 显示地址而非函数名

**解决:**
```bash
# 安装调试符号（Ubuntu）
sudo apt-get install linux-image-$(uname -r)-dbg

# 安装调试符号（RHEL）
sudo debuginfo-install kernel

# 编译时带调试信息
gcc -g -O2 -fno-omit-frame-pointer ...
```

## 性能影响评估

### BCC工具开销

| 工具 | CPU开销 | 内存开销 | 适用环境 |
|------|---------|----------|----------|
| execsnoop | < 1% | < 10MB | 生产环境 ✓ |
| opensnoop | < 2% | < 10MB | 生产环境 ✓ |
| biolatency | < 1% | < 5MB | 生产环境 ✓ |
| tcpconnect | < 1% | < 10MB | 生产环境 ✓ |
| tcplife | < 1% | < 20MB | 生产环境 ✓ |
| ext4slower | < 1% | < 5MB | 生产环境 ✓ |
| profile | 1-5% | < 50MB | 开发/测试 |

### bpftrace开销

- **采样类**: < 1% CPU（profile, interval）
- **追踪类**: 1-3% CPU（kprobe, tracepoint）
- **高频追踪**: 可能5%+ CPU（需谨慎）

**生产环境建议:**
- 使用低频采样（49-99 Hz）
- 避免高频kprobe
- 优先使用tracepoint
- 限制输出量
- 定期清理maps

## 参考资料

- [eBPF Official Website](https://ebpf.io/)
- [BCC GitHub Repository](https://github.com/iovisor/bcc)
- [bpftrace GitHub Repository](https://github.com/iovisor/bpftrace)
- [bpftrace Reference Guide](https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md)
- [Brendan Gregg's eBPF Tools](http://www.brendangregg.com/ebpf.html)
- [Linux Performance](http://www.brendangregg.com/linuxperf.html)

## 常见问题 (FAQ)

**Q: BCC和bpftrace应该选择哪个？**
A: 快速分析用bpftrace，复杂场景用BCC。bpftrace适合一次性问题排查，BCC适合长期监控。

**Q: eBPF会影响系统性能吗？**
A: 未启用时零开销。启用时大部分工具开销<2%，适合生产环境。

**Q: 需要重启系统吗？**
A: 不需要。eBPF程序可动态加载和卸载。

**Q: 可以在容器中使用吗？**
A: 可以。但需要特权容器或CAP_BPF权限。

**Q: 支持哪些架构？**
A: x86_64, ARM64, PowerPC等。x86_64支持最好。

---

**更新日期:** 2026-04-19
**版本:** 1.0
