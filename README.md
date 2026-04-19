# Linux 性能测试工具套件

一个完整的 Linux 系统测试工具集，包含30+专业测试套件，涵盖性能分析、功能验证、安全测试、实时性评估等全方位测试场景。

[![Linux](https://img.shields.io/badge/OS-Linux-blue.svg)](https://www.kernel.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 特性

- ✅ **全面覆盖** - 30+测试套件，覆盖性能、功能、安全、虚拟化等
- ✅ **自动化测试** - 一键运行所有性能测试
- ✅ **分类组织** - 按测试类型清晰分类（网络/内存/I/O/实时性/eBPF等）
- ✅ **专业工具** - 集成业界标准测试工具（iperf3/fio/UnixBench/LTP等）
- ✅ **性能基准** - 提供性能评级和优化建议
- ✅ **详细报告** - 自动生成测试报告和可视化图表
- ✅ **独立运行** - 每个测试可单独执行
- ✅ **丰富文档** - 详细的使用说明、结果解读和优化指南

## 快速开始

### 1. 安装测试工具

```bash
# 克隆项目
git clone <repo-url> linux-testing
cd linux-testing

# 安装所有必需工具（需要 root 权限）
sudo ./setup/install-tools.sh
```

安装的工具包括：
- **perf** - Linux 性能分析工具（必需）
- **stress-ng** - 系统压力测试工具（推荐）
- **packetdrill** - TCP 协议栈测试工具（推荐）
- **其他工具** - iftop, iotop, htop 等（可选）

### 2. 运行测试

```bash
# 运行所有测试
sudo ./scripts/run-all.sh

# 或者运行单个测试
sudo ./scripts/network/network-test.sh    # 网络性能
sudo ./scripts/sched/sched-test.sh        # 进程调度
sudo ./scripts/block/block-test.sh        # 块设备I/O
sudo ./scripts/tcp/tcp-test.sh            # TCP协议栈
```

### 3. 查看结果

```bash
# 查看汇总报告
cat results/summary_*.md

# 查看详细结果
ls -lt results/*/report_*.txt
```

## 项目结构

```
linux-testing/
├── setup/              # 安装脚本
│   └── install-tools.sh
├── tools/              # 测试工具
├── scripts/            # 测试脚本（按类型分类）
│   ├── network/        # 网络性能测试
│   ├── sched/          # 进程调度测试
│   ├── block/          # 块设备I/O测试
│   ├── tcp/            # TCP协议栈测试
│   └── run-all.sh      # 运行所有测试
├── tests/              # 测试用例（共30+测试套件）
│   ├── bcc/            # BCC eBPF 工具测试
│   ├── bpftrace/       # bpftrace 动态追踪
│   ├── ebpf/           # eBPF 综合测试套件
│   ├── perf/           # perf 性能分析
│   ├── stress-ng/      # stress-ng 专项测试（内存/网络/文件系统）
│   ├── rt-tests/       # rt-tests 实时性能测试
│   ├── iperf3/         # iperf3 网络吞吐量测试
│   ├── netperf/        # netperf 网络性能测试
│   ├── qperf/          # qperf RDMA/网络测试
│   ├── fio/            # fio 磁盘I/O测试
│   ├── iozone/         # iozone 文件系统基准测试
│   ├── stream/         # STREAM 内存带宽测试
│   ├── memtester/      # memtester 内存测试
│   ├── lmbench/        # lmbench 微基准测试
│   ├── unixbench/      # UnixBench 综合基准测试
│   ├── stressapptest/  # stressapptest 硬件压力测试
│   ├── ltp/            # LTP Linux测试项目
│   ├── cgroup/         # cgroup 资源控制测试
│   ├── namespace/      # namespace 命名空间测试
│   ├── security/       # 安全功能测试
│   ├── selinux/        # SELinux 测试
│   ├── kvm/            # KVM 虚拟化测试
│   ├── kernel-module/  # 内核模块开发测试
│   ├── device-drivers/ # 设备驱动测试
│   ├── memory-analysis/# 内存分析
│   ├── syscalls/       # 系统调用性能测试
│   ├── lock/           # 锁竞争测试
│   └── mem/            # 内存访问测试
├── results/            # 测试结果（自动生成）
├── docs/               # 文档
└── examples/           # 示例
```

详细结构说明：[docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)

## 测试类型

### 1. 网络性能测试

测试网络数据包在内核协议栈中的流转过程。

**测试内容**:
- Ping 数据包跟踪
- 发送/接收事件分析
- 网卡队列映射
- 网络延迟分析

**示例命令**:
```bash
# 跟踪单个 ping 包
perf trace -e 'net:*' ping -c 1 google.com

# 详细事件记录
perf record -e 'net:*' -a ping -c 1 google.com
perf script
```

### 2. 进程调度测试

分析进程调度延迟和 CPU 利用率。

**测试内容**:
- 空闲系统调度延迟
- 高负载调度延迟
- 调度时间线分析
- CPU 调度映射

**示例命令**:
```bash
# 记录调度事件
perf sched record -a sleep 10

# 查看调度延迟
perf sched latency

# 查看时间线
perf sched timehist
```

### 3. 块设备I/O测试

测试磁盘I/O性能和页缓存行为。

**测试内容**:
- 缓存写入（无磁盘I/O）
- Direct I/O（真实磁盘速度）
- fsync 同步写入
- 块事件跟踪

**示例命令**:
```bash
# 缓存写入
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100

# Direct I/O（真实磁盘）
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 oflag=direct
```

### 4. TCP 协议栈测试

使用 packetdrill 测试 TCP 协议实现。

**测试内容**:
- TCP 三次握手
- 数据传输
- 连接关闭
- TCP 选项处理

**示例命令**:
```bash
# 运行 TCP 测试
packetdrill tests/tcp/basic_tcp.pkt

# 详细输出
packetdrill --verbose tests/tcp/basic_tcp.pkt
```

### 5. BCC 工具测试

使用 BPF Compiler Collection (BCC) 工具进行系统跟踪。

**测试内容**:
- 进程执行跟踪 (execsnoop)
- 文件操作跟踪 (opensnoop)
- 磁盘I/O跟踪 (biosnoop)
- TCP连接跟踪 (tcpconnect, tcpaccept)
- CPU性能分析 (profile)
- 内存泄漏检测 (memleak)

**快速开始**:
```bash
cd tests/bcc

# 安装 BCC 工具
sudo ./setup/install-bcc.sh

# 检查环境
sudo ./check_bcc.sh

# 运行测试 (使用 mock 程序)
cd mock_programs && make
cd ..
sudo python3 test_execsnoop.py
```

详细文档：[tests/bcc/README.md](tests/bcc/README.md)

### 6. bpftrace 测试

使用 bpftrace 进行高级动态跟踪。

**测试内容**:
- 系统调用统计
- 内核函数延迟分析
- TCP 连接生命周期
- 内存分配跟踪
- 进程生命周期监控
- VFS I/O 操作分析

**快速开始**:
```bash
cd tests/bpftrace

# 安装 bpftrace
sudo ./install_bpftrace.sh

# 检查环境
sudo ./check_bpftrace.sh

# 编译 mock 程序
cd mock_programs && make
cd ..

# 运行测试
sudo ./test_syscall_count.sh       # 系统调用统计
sudo ./test_function_latency.sh    # 延迟直方图
sudo ./test_tcp_lifecycle.sh       # TCP 状态跟踪
sudo ./test_memory_alloc.sh        # 内存分配
sudo ./test_process_lifecycle.sh   # 进程生命周期
sudo ./test_vfs_io.sh              # I/O 跟踪

# 运行所有测试
sudo ./run_all_tests.sh
```

详细文档：[tests/bpftrace/README.md](tests/bpftrace/README.md)

### 7. stress-ng 专项测试

使用 stress-ng 对内存、网络、文件系统子系统进行专项性能测试。

**测试内容**:
- **内存子系统测试** (9项): VM分配、memcpy带宽、mmap页面错误、Hugepage、NUMA、cache
- **网络子系统测试** (9项): TCP/UDP/Unix Socket、网络吞吐量、零拷贝传输
- **文件系统测试** (10项): HDD写入、I/O IOPS、sync延迟、元数据操作、文件锁

**快速开始**:
```bash
cd tests/stress-ng/scripts

# 内存子系统测试（约9分钟）
sudo ./test_memory.sh

# 网络子系统测试（约9分钟）
sudo ./test_network.sh

# 文件系统测试（约10分钟）
sudo ./test_filesystem.sh
```

**性能评级示例**:
- memcpy带宽: > 15 GB/s ★★★★★ 优秀 (DDR4-3200)
- TCP Socket: > 100K ops/s ★★★★★ 优秀
- NVMe SSD写入: > 2000 MB/s ★★★★★ 优秀

**详细解读**: [tests/stress-ng/INTERPRETATION_GUIDE.md](tests/stress-ng/INTERPRETATION_GUIDE.md)

### 8. rt-tests 实时性能测试

使用 rt-tests 测试系统实时响应能力和延迟特性。

**测试内容**:
- **cyclictest 延迟测试**: 完整实时性测试、多场景对比、CDF分析
- **压力+实时性综合测试**: 6种压力场景下的实时性能评估
- **动态压力调节测试**: 阶梯式CPU负载测试、算法影响对比

**快速开始**:
```bash
cd tests/rt-tests/scripts

# 完整实时性测试
sudo ./cyclictest_rt_full.sh

# 三种场景对比测试
sudo ./cyclictest_three_scenarios.sh

# 压力+实时性综合测试
sudo ./stress_cyclictest_integrated.sh

# 动态压力调节测试
sudo ./adaptive_stress_rt_test.sh
```

**性能评级**:
- 优秀 (硬实时): Max延迟 < 50μs
- 良好 (软实时): Max延迟 < 100μs
- 可接受 (准实时): Max延迟 < 500μs

详细文档：[tests/rt-tests/README.md](tests/rt-tests/README.md)

### 9. 网络性能基准测试

使用专业网络性能测试工具进行吞吐量和延迟测试。

**测试工具**:
- **iperf3**: TCP/UDP吞吐量测试、双向测试、多流测试
- **netperf**: TCP_STREAM、TCP_RR、UDP性能测试
- **qperf**: RDMA和常规网络性能测试

**快速开始**:
```bash
# iperf3 测试
cd tests/iperf3
sudo ./test_iperf3.sh

# netperf 测试
cd tests/netperf
sudo ./test_netperf.sh

# qperf 测试（RDMA）
cd tests/qperf
sudo ./test_qperf.sh
```

详细文档：[tests/iperf3/README.md](tests/iperf3/README.md) | [tests/netperf/README.md](tests/netperf/README.md) | [tests/qperf/README.md](tests/qperf/README.md)

### 10. 磁盘I/O性能基准测试

使用专业I/O测试工具评估磁盘和文件系统性能。

**测试工具**:
- **fio**: 灵活的I/O测试工具，支持多种I/O模式
- **iozone**: 文件系统基准测试，13种测试模式
- **lmbench**: 系统微基准测试，包括I/O延迟

**快速开始**:
```bash
# fio 测试
cd tests/fio
sudo ./run_fio_tests.sh

# iozone 测试
cd tests/iozone
sudo ./test_iozone.sh

# lmbench 测试
cd tests/lmbench
sudo ./run_lmbench.sh
```

详细文档：[tests/fio/README.md](tests/fio/README.md) | [tests/iozone/README.md](tests/iozone/README.md) | [tests/lmbench/README.md](tests/lmbench/README.md)

### 11. 内存性能测试

内存带宽、延迟和稳定性测试。

**测试工具**:
- **stream**: 内存带宽基准测试（Copy、Scale、Add、Triad）
- **memtester**: 内存故障检测和压力测试
- **lmbench**: 内存延迟和带宽测试
- **memory-analysis**: 内存分析和性能分析

**快速开始**:
```bash
# STREAM 带宽测试
cd tests/stream
./run_stream.sh

# memtester 内存测试
cd tests/memtester
sudo ./test_memtester.sh

# 内存分析
cd tests/memory-analysis
sudo ./analyze_memory.sh
```

详细文档：[tests/stream/README.md](tests/stream/README.md) | [tests/memtester/README.md](tests/memtester/README.md)

### 12. 系统综合基准测试

全面的系统性能基准测试套件。

**测试工具**:
- **UnixBench**: Unix系统综合基准测试（CPU、内存、I/O、系统调用）
- **lmbench**: 操作系统微基准测试（延迟、带宽、上下文切换）
- **stressapptest**: 硬件压力测试和稳定性验证

**快速开始**:
```bash
# UnixBench 综合测试
cd tests/unixbench
./run_unixbench.sh

# lmbench 微基准测试
cd tests/lmbench
./run_lmbench.sh

# stressapptest 硬件压力测试
cd tests/stressapptest
sudo ./test_stressapptest.sh
```

详细文档：[tests/unixbench/README.md](tests/unixbench/README.md) | [tests/lmbench/README.md](tests/lmbench/README.md) | [tests/stressapptest/README.md](tests/stressapptest/README.md)

### 13. Linux功能测试

Linux内核功能验证和兼容性测试。

**测试工具**:
- **LTP (Linux Test Project)**: 6000+测试用例，覆盖系统调用、命令、文件系统
- **cgroup**: cgroup资源控制和隔离测试
- **namespace**: Linux命名空间隔离测试
- **security**: 安全功能测试
- **selinux**: SELinux强制访问控制测试

**快速开始**:
```bash
# LTP 测试
cd tests/ltp
sudo ./run_ltp.sh

# cgroup 测试
cd tests/cgroup
sudo ./test_cgroup.sh

# namespace 测试
cd tests/namespace
sudo ./test_namespace.sh

# SELinux 测试
cd tests/selinux
sudo ./test_selinux.sh
```

详细文档：[tests/ltp/README.md](tests/ltp/README.md) | [tests/cgroup/README.md](tests/cgroup/README.md) | [tests/namespace/README.md](tests/namespace/README.md)

### 14. eBPF和内核追踪

eBPF程序开发和内核动态追踪。

**测试工具**:
- **ebpf**: eBPF综合测试套件（XDP、TC、tracepoint、kprobe）
- **bcc**: BPF Compiler Collection工具集
- **bpftrace**: 高级动态追踪语言
- **perf**: Linux性能分析工具

**快速开始**:
```bash
# eBPF 综合测试
cd tests/ebpf
sudo ./test_ebpf.sh

# BCC 工具测试
cd tests/bcc
sudo ./check_bcc.sh

# bpftrace 测试
cd tests/bpftrace
sudo ./run_all_tests.sh

# perf 分析
cd tests/perf
sudo ./test_perf.sh
```

详细文档：[tests/ebpf/README.md](tests/ebpf/README.md) | [tests/bcc/README.md](tests/bcc/README.md) | [tests/bpftrace/README.md](tests/bpftrace/README.md)

### 15. 虚拟化和内核开发

KVM虚拟化和内核模块开发测试。

**测试工具**:
- **kvm**: KVM虚拟化功能和性能测试
- **kernel-module**: 内核模块开发和加载测试
- **device-drivers**: 设备驱动开发和测试

**快速开始**:
```bash
# KVM 虚拟化测试
cd tests/kvm
sudo ./test_kvm.sh

# 内核模块测试
cd tests/kernel-module
make && sudo ./load_module.sh

# 设备驱动测试
cd tests/device-drivers
sudo ./test_drivers.sh
```

详细文档：[tests/kvm/README.md](tests/kvm/README.md) | [tests/kernel-module/README.md](tests/kernel-module/README.md) | [tests/device-drivers/README.md](tests/device-drivers/README.md)

## 测试结果

所有测试结果保存在 `results/` 目录：

```
results/
├── network/                # 网络测试结果
│   ├── ping_trace_*.txt
│   ├── ping_events_*.txt
│   └── report_*.txt
├── sched/                  # 调度测试结果
│   ├── sched_idle_latency_*.txt
│   ├── sched_stress_latency_*.txt
│   └── report_*.txt
├── block/                  # 块设备测试结果
│   ├── block_cached_*.txt
│   ├── block_direct_write_*.txt
│   └── report_*.txt
├── tcp/                    # TCP测试结果
│   └── report_*.txt
└── summary_*.md            # 汇总报告
```

## 文档

- [快速开始指南](QUICKSTART.md) - 快速上手
- [项目结构说明](docs/PROJECT_STRUCTURE.md) - 详细的目录结构
- [详细测试指南](docs/DETAILED_GUIDE.md) - 完整的命令和原理解释
- [工具使用说明](tools/README.md) - 各工具的使用方法

## 系统要求

### 必需
- Linux 内核 3.10+
- Root 权限（用于 perf 和网络测试）
- Bash 4.0+

### 支持的发行版
- RHEL/CentOS 7/8/9
- Ubuntu 18.04/20.04/22.04
- Debian 9/10/11
- Fedora
- AlmaLinux/Rocky Linux

### 工具依赖
- **perf** (必需) - 性能分析工具
- **stress-ng** (推荐) - 压力测试
- **packetdrill** (推荐) - TCP 测试
- **git, gcc, make** (编译 packetdrill)

## 常见问题

### Q: 为什么需要 root 权限？

某些 perf 功能和网络操作需要 root 权限。可以配置允许普通用户使用：

```bash
sudo sysctl -w kernel.perf_event_paranoid=-1
```

### Q: 块设备测试结果都是 0？

这是正常的。默认情况下，数据被写入页缓存，没有触发真实的磁盘I/O。使用 `oflag=direct` 可以绕过缓存。

### Q: packetdrill 测试失败？

常见原因：
- TCP 选项顺序不匹配（使用实际内核返回的顺序）
- 窗口大小不匹配（使用实际的窗口值）
- 端口被占用（等待或修改测试脚本）

更多问题：查看 [FAQ](docs/FAQ.md)

## 性能标准参考

### 调度延迟
- **桌面/服务器**: < 10ms
- **低延迟系统**: < 1ms
- **实时系统**: < 100μs
- **硬实时系统**: < 10μs

### 磁盘I/O
- **SSD Random 4K Read**: 50-100K IOPS
- **SSD Sequential Read**: 500MB/s - 3GB/s
- **HDD Sequential Read**: 100MB/s - 200MB/s
- **页缓存写入**: 2GB/s - 10GB/s

### 网络延迟
- **本地回环**: < 0.1ms
- **局域网**: < 1ms
- **跨数据中心**: 5-50ms
- **跨大洲**: 100-300ms

## 贡献

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md)

可以贡献的方向：
- 添加新的测试用例
- 改进测试脚本
- 完善文档
- 报告 bug
- 提出新功能建议

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 参考资料

- [Perf Wiki](https://perf.wiki.kernel.org/)
- [Brendan Gregg's Performance Tools](http://www.brendangregg.com/perf.html)
- [Packetdrill GitHub](https://github.com/google/packetdrill)
- [Linux Performance](http://www.brendangregg.com/linuxperf.html)
- [Stress-ng](https://github.com/ColinIanKing/stress-ng)

## 致谢

感谢以下开源项目：
- [perf](https://perf.wiki.kernel.org/) - Linux 性能分析工具
- [packetdrill](https://github.com/google/packetdrill) - TCP 测试工具
- [stress-ng](https://github.com/ColinIanKing/stress-ng) - 压力测试工具

---

**创建日期**: 2026-04-18
**最后更新**: 2026-04-18
**版本**: 2.0
