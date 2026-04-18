# BCC (BPF Compiler Collection) 工具测试

## 概述

BCC 是一个用于创建高效内核跟踪和操作程序的工具包。它使用 eBPF (extended Berkeley Packet Filter) 技术，可以在内核中安全高效地运行分析程序。

本目录包含 10 个常用 BCC 工具的测试用例、使用示例和结果详解。

---

## 工具列表

| 工具 | 用途 | 测试脚本 |
|------|------|----------|
| [execsnoop](#1-execsnoop) | 跟踪进程执行 | test_execsnoop.sh |
| [opensnoop](#2-opensnoop) | 跟踪文件打开 | test_opensnoop.sh |
| [biosnoop](#3-biosnoop) | 跟踪块I/O | test_biosnoop.sh |
| [tcpconnect](#4-tcpconnect) | 跟踪TCP连接 | test_tcpconnect.sh |
| [tcpaccept](#5-tcpaccept) | 跟踪TCP接受 | test_tcpaccept.sh |
| [tcpretrans](#6-tcpretrans) | 跟踪TCP重传 | test_tcpretrans.sh |
| [runqlat](#7-runqlat) | 调度队列延迟 | test_runqlat.sh |
| [profile](#8-profile) | CPU采样分析 | test_profile.sh |
| [offcputime](#9-offcputime) | 离CPU时间分析 | test_offcputime.sh |
| [memleak](#10-memleak) | 内存泄漏检测 | test_memleak.sh |

---

## 安装 BCC

### RHEL/CentOS/Fedora

```bash
sudo dnf install bcc-tools
```

### Ubuntu/Debian

```bash
sudo apt-get install bpfcc-tools
```

### 验证安装

```bash
# BCC 工具通常安装在 /usr/share/bcc/tools/
ls /usr/share/bcc/tools/

# 或者在 PATH 中
which execsnoop
```

---

## 快速开始

```bash
# 进入测试目录
cd tests/bcc

# 运行所有测试
./run_all_tests.sh

# 运行单个测试
./test_execsnoop.sh
./test_opensnoop.sh
```

---

## 1. execsnoop

### 用途
实时跟踪系统中所有新执行的进程，包括短暂进程。

### 原理
通过挂载到 `sys_execve()` 和 `sys_execveat()` 系统调用，捕获所有进程执行事件。

### 基本用法

```bash
# 实时显示所有新进程
execsnoop

# 只显示失败的执行
execsnoop -x

# 显示时间戳
execsnoop -t

# 过滤特定进程名
execsnoop -n bash
```

### 示例输出

```
PCOMM            PID    PPID   RET ARGS
bash             12345  12340    0 /bin/bash
ls               12346  12345    0 /bin/ls -l /home
grep             12347  12345    0 /bin/grep test file.txt
python           12348  1        0 /usr/bin/python script.py
```

### 字段说明

- **PCOMM**: 父进程命令
- **PID**: 进程 ID
- **PPID**: 父进程 ID
- **RET**: 返回值（0=成功，非0=失败）
- **ARGS**: 完整命令行参数

### 使用场景

1. **调试启动问题**: 查看程序启动时执行了哪些子进程
2. **安全审计**: 监控可疑的进程执行
3. **性能分析**: 发现频繁执行的短暂进程
4. **故障排查**: 追踪脚本执行流程

### 详细示例

参见: [test_execsnoop.sh](test_execsnoop.sh) 和 [RESULTS_EXECSNOOP.md](../docs/results/RESULTS_EXECSNOOP.md)

---

## 2. opensnoop

### 用途
跟踪系统中所有文件打开操作。

### 原理
通过挂载到 `open()` 和 `openat()` 系统调用，捕获文件打开事件。

### 基本用法

```bash
# 跟踪所有文件打开
opensnoop

# 跟踪特定进程
opensnoop -p 1234

# 跟踪特定进程名
opensnoop -n nginx

# 只显示失败的打开
opensnoop -x

# 显示时间戳
opensnoop -t
```

### 示例输出

```
PID    COMM               FD ERR PATH
12345  python              3   0 /etc/hosts
12346  nginx               4   0 /var/log/nginx/access.log
12347  mysql              -1   2 /var/lib/mysql/data.lock
12348  vim                 5   0 /home/user/.vimrc
```

### 字段说明

- **PID**: 进程 ID
- **COMM**: 进程命令名
- **FD**: 文件描述符（-1 表示失败）
- **ERR**: 错误码（0=成功，2=ENOENT 等）
- **PATH**: 打开的文件路径

### 使用场景

1. **排查文件找不到问题**: 查看程序试图打开哪些文件
2. **性能分析**: 发现频繁打开的文件
3. **安全审计**: 监控敏感文件访问
4. **依赖分析**: 了解程序访问哪些配置文件

### 详细示例

参见: [test_opensnoop.sh](test_opensnoop.sh) 和 [RESULTS_OPENSNOOP.md](../docs/results/RESULTS_OPENSNOOP.md)

---

## 3. biosnoop

### 用途
跟踪块设备 I/O 操作，显示磁盘 I/O 详情。

### 原理
通过挂载到块 I/O 请求队列，捕获所有磁盘 I/O 事件。

### 基本用法

```bash
# 跟踪所有块设备 I/O
biosnoop

# 跟踪特定磁盘
biosnoop -d sda

# 显示队列时间
biosnoop -Q
```

### 示例输出

```
TIME(s)     COMM           PID    DISK    T SECTOR     BYTES   LAT(ms)
0.000000    kworker/0:1    123    sda     W 12345678   4096      2.45
0.001234    mysqld         456    sda     R 87654321   8192      1.23
0.002345    python         789    sda     W 11111111   4096      3.67
0.003456    sync           999    sda     W 22222222  131072     15.89
```

### 字段说明

- **TIME(s)**: 时间戳（秒）
- **COMM**: 进程命令名
- **PID**: 进程 ID
- **DISK**: 磁盘设备名
- **T**: 类型（R=读，W=写）
- **SECTOR**: 起始扇区号
- **BYTES**: I/O 大小（字节）
- **LAT(ms)**: I/O 延迟（毫秒）

### 使用场景

1. **磁盘性能分析**: 识别慢 I/O 操作
2. **I/O 热点分析**: 找出频繁访问的磁盘区域
3. **进程 I/O 行为**: 了解进程的磁盘访问模式
4. **存储故障排查**: 诊断磁盘延迟问题

### 详细示例

参见: [test_biosnoop.sh](test_biosnoop.sh) 和 [RESULTS_BIOSNOOP.md](../docs/results/RESULTS_BIOSNOOP.md)

---

## 4. tcpconnect

### 用途
跟踪主动 TCP 连接尝试（connect() 调用）。

### 原理
通过挂载到 `tcp_v4_connect()` 和 `tcp_v6_connect()` 内核函数。

### 基本用法

```bash
# 跟踪所有 TCP 连接
tcpconnect

# 显示时间戳
tcpconnect -t

# 跟踪特定进程
tcpconnect -p 1234

# 跟踪特定端口
tcpconnect -P 80,443
```

### 示例输出

```
PID    COMM         IP SADDR            DADDR            DPORT
12345  curl         4  192.168.1.100    93.184.216.34    80
12346  ssh          4  192.168.1.100    10.0.0.5         22
12347  mysql        4  192.168.1.100    192.168.1.200    3306
12348  python       6  fe80::1          2001:db8::1      443
```

### 字段说明

- **PID**: 进程 ID
- **COMM**: 进程命令名
- **IP**: IP 版本（4 或 6）
- **SADDR**: 源地址
- **DADDR**: 目标地址
- **DPORT**: 目标端口

### 使用场景

1. **网络连接审计**: 监控外连行为
2. **服务依赖分析**: 了解服务连接了哪些后端
3. **安全监控**: 检测可疑的外连
4. **故障排查**: 追踪连接失败问题

### 详细示例

参见: [test_tcpconnect.sh](test_tcpconnect.sh) 和 [RESULTS_TCPCONNECT.md](../docs/results/RESULTS_TCPCONNECT.md)

---

## 5. tcpaccept

### 用途
跟踪被动 TCP 连接接受（accept() 调用）。

### 原理
通过挂载到 `inet_csk_accept()` 内核函数。

### 基本用法

```bash
# 跟踪所有 TCP 接受
tcpaccept

# 显示时间戳
tcpaccept -t

# 过滤本地端口
tcpaccept -L 80

# 过滤远程端口
tcpaccept -P 1024-65535
```

### 示例输出

```
PID    COMM         IP RADDR            RPORT LADDR            LPORT
12345  nginx        4  192.168.1.50     45678 192.168.1.100    80
12346  sshd         4  192.168.1.60     54321 192.168.1.100    22
12347  mysqld       4  192.168.1.70     33333 192.168.1.100    3306
12348  httpd        6  fe80::2          12345 fe80::1          443
```

### 字段说明

- **PID**: 进程 ID
- **COMM**: 进程命令名
- **IP**: IP 版本
- **RADDR**: 远程地址（客户端）
- **RPORT**: 远程端口
- **LADDR**: 本地地址（服务器）
- **LPORT**: 本地端口

### 使用场景

1. **服务监控**: 查看谁在连接你的服务
2. **访问审计**: 记录所有入站连接
3. **DDoS 检测**: 监控异常连接模式
4. **负载分析**: 了解连接来源分布

### 详细示例

参见: [test_tcpaccept.sh](test_tcpaccept.sh) 和 [RESULTS_TCPACCEPT.md](../docs/results/RESULTS_TCPACCEPT.md)

---

## 6. tcpretrans

### 用途
跟踪 TCP 重传事件，诊断网络质量问题。

### 原理
通过挂载到 `tcp_retransmit_skb()` 内核函数。

### 基本用法

```bash
# 跟踪所有 TCP 重传
tcpretrans

# 显示详细信息（包括状态）
tcpretrans -l

# 持续运行并统计
tcpretrans -c
```

### 示例输出

```
TIME     PID    IP LADDR:LPORT          T> RADDR:RPORT          STATE
12:34:56 12345  4  192.168.1.100:45678  R> 93.184.216.34:80     ESTABLISHED
12:35:01 12346  4  192.168.1.100:22     R> 192.168.1.50:54321   ESTABLISHED
12:35:12 12347  4  192.168.1.100:3306   R> 192.168.1.70:33333   CLOSE_WAIT
```

### 字段说明

- **TIME**: 时间戳
- **PID**: 进程 ID
- **IP**: IP 版本
- **LADDR:LPORT**: 本地地址:端口
- **T>**: 传输方向
- **RADDR:RPORT**: 远程地址:端口
- **STATE**: TCP 连接状态

### 使用场景

1. **网络质量诊断**: 检测丢包和延迟
2. **性能问题排查**: 重传会严重影响性能
3. **故障分析**: 频繁重传可能表示网络问题
4. **容量规划**: 了解网络负载状况

### 详细示例

参见: [test_tcpretrans.sh](test_tcpretrans.sh) 和 [RESULTS_TCPRETRANS.md](../docs/results/RESULTS_TCPRETRANS.md)

---

## 7. runqlat

### 用途
测量调度器运行队列延迟，显示进程等待 CPU 的时间分布。

### 原理
通过挂载到调度器事件，测量进程从可运行到真正运行的延迟。

### 基本用法

```bash
# 运行 5 秒并显示直方图
runqlat 5

# 以毫秒为单位
runqlat -m 5

# 每 1 秒输出一次
runqlat -i 1

# 跟踪特定进程
runqlat -p 1234
```

### 示例输出

```
Tracing run queue latency... Hit Ctrl-C to end.

     usecs               : count     distribution
         0 -> 1          : 12345    |****************************************|
         2 -> 3          : 8901     |*****************************           |
         4 -> 7          : 4567     |**************                          |
         8 -> 15         : 2345     |*******                                 |
        16 -> 31         : 1234     |****                                    |
        32 -> 63         : 567      |*                                       |
        64 -> 127        : 234      |                                        |
       128 -> 255        : 123      |                                        |
       256 -> 511        : 45       |                                        |
       512 -> 1023       : 12       |                                        |
```

### 字段说明

- **usecs**: 延迟范围（微秒）
- **count**: 此范围内的样本数
- **distribution**: 直方图可视化

### 使用场景

1. **CPU 饱和度分析**: 高延迟表示 CPU 过载
2. **调度性能**: 了解调度器效率
3. **实时性分析**: 对延迟敏感的应用
4. **容量规划**: 判断是否需要增加 CPU

### 详细示例

参见: [test_runqlat.sh](test_runqlat.sh) 和 [RESULTS_RUNQLAT.md](../docs/results/RESULTS_RUNQLAT.md)

---

## 8. profile

### 用途
CPU 采样分析，显示哪些函数消耗最多 CPU 时间。

### 原理
使用硬件性能计数器定期采样 CPU 上运行的函数堆栈。

### 基本用法

```bash
# 采样 10 秒，默认 49Hz
profile 10

# 以 99Hz 采样所有 CPU，持续 10 秒
profile -F 99 -a 10

# 只采样用户态
profile -U 10

# 只采样内核态
profile -K 10

# 采样特定进程
profile -p 1234 10
```

### 示例输出

```
Sampling at 99 Hertz of all threads by user + kernel stack for 10 secs.

    pthread_cond_wait;start_thread;clone;-;libc-2.31.so
    1234

    read;vfs_read;ksys_read;do_syscall_64;entry_SYSCALL_64_after_hwframe
    2345

    __tcp_transmit_skb;tcp_write_xmit;tcp_sendmsg;sock_sendmsg
    3456

    process_data;main;__libc_start_main;myapp
    8901
```

### 字段说明

- 每个条目显示一个调用栈
- 最后的数字是该栈的采样次数
- 采样次数越多 = CPU 时间越多

### 使用场景

1. **性能优化**: 找出 CPU 热点函数
2. **瓶颈分析**: 识别性能瓶颈
3. **代码审查**: 了解代码执行路径
4. **基准测试**: 对比优化前后的 CPU 使用

### 详细示例

参见: [test_profile.sh](test_profile.sh) 和 [RESULTS_PROFILE.md](../docs/results/RESULTS_PROFILE.md)

---

## 9. offcputime

### 用途
分析进程离开 CPU 的时间（阻塞、等待 I/O、锁等待等）。

### 原理
通过挂载到调度器事件，测量进程不在 CPU 上运行的时间。

### 基本用法

```bash
# 分析所有进程的离 CPU 时间
offcputime 10

# 分析特定进程
offcputime -p 1234 10

# 显示用户态堆栈
offcputime -u 10

# 显示内核态堆栈
offcputime -k 10

# 生成火焰图数据
offcputime -f 10 > offcpu.folded
```

### 示例输出

```
Tracing off-CPU time (us) of all threads by user + kernel stack... Hit Ctrl-C to end.

    pthread_mutex_lock;process_request;worker_thread;start_thread
    - mysqld (12345)
        123456

    futex_wait_queue_me;futex_wait;do_futex;__x64_sys_futex
    - nginx (12346)
        234567

    wait_for_completion;blk_execute_rq;__blk_mq_run_hw_queue
    - python (12347)
        345678
```

### 字段说明

- 调用栈显示进程在哪里阻塞
- 最后的数字是离 CPU 时间（微秒）
- 时间越长 = 阻塞越严重

### 使用场景

1. **阻塞分析**: 找出程序在哪里等待
2. **锁竞争**: 识别锁等待热点
3. **I/O 性能**: 分析 I/O 等待时间
4. **性能优化**: 减少阻塞时间

### 详细示例

参见: [test_offcputime.sh](test_offcputime.sh) 和 [RESULTS_OFFCPUTIME.md](../docs/results/RESULTS_OFFCPUTIME.md)

---

## 10. memleak

### 用途
检测用户空间和内核空间的内存泄漏。

### 原理
通过挂载到内存分配函数（malloc/free, kmalloc/kfree），追踪未释放的内存。

### 基本用法

```bash
# 检测特定进程的内存泄漏
memleak -p 1234

# 检测用户空间泄漏，每 5 秒报告一次
memleak -p 1234 -a 5

# 检测内核空间泄漏
memleak -k 5

# 显示调用栈
memleak -p 1234 -t 10
```

### 示例输出

```
Attaching to pid 12345, Ctrl+C to quit.
[12:34:56] Top 10 stacks with outstanding allocations:

    addr = 7f8b2c001000 size = 4096
    malloc+0x23
    process_data+0x45
    main+0x67
    __libc_start_main+0xe7
    [python]
    4 times, 16384 bytes

    addr = 7f8b2c002000 size = 8192
    malloc+0x23
    load_config+0x34
    init_system+0x56
    main+0x12
    [python]
    2 times, 16384 bytes

Total outstanding allocations: 32768 bytes in 6 allocations
```

### 字段说明

- **addr**: 分配的内存地址
- **size**: 分配的大小
- 调用栈显示分配来源
- **times**: 该栈的分配次数
- **bytes**: 累计未释放的字节数

### 使用场景

1. **内存泄漏检测**: 发现程序内存泄漏
2. **资源管理**: 验证内存正确释放
3. **长期运行分析**: 监控服务器内存增长
4. **测试验证**: 确保修复有效

### 详细示例

参见: [test_memleak.sh](test_memleak.sh) 和 [RESULTS_MEMLEAK.md](../docs/results/RESULTS_MEMLEAK.md)

---

## 常见问题

### Q: 运行 BCC 工具需要 root 权限吗？

**A**: 是的，大多数 BCC 工具需要 root 权限或 CAP_BPF 能力，因为它们需要加载 eBPF 程序到内核。

```bash
# 使用 sudo
sudo execsnoop

# 或切换到 root
su -
execsnoop
```

### Q: BCC 工具对性能有影响吗？

**A**: 有轻微影响，但通常很小：

- **开销**: 通常 < 5%
- **eBPF 的优势**: 在内核中高效执行，避免上下文切换
- **建议**: 在生产环境中短时间使用，收集数据后停止

### Q: 如何在虚拟机中使用 BCC？

**A**: 虚拟机需要支持：

1. **内核版本**: >= 4.4（推荐 >= 4.9）
2. **内核配置**: CONFIG_BPF=y, CONFIG_BPF_SYSCALL=y
3. **检查支持**:

```bash
# 检查内核版本
uname -r

# 检查 BPF 支持
cat /boot/config-$(uname -r) | grep CONFIG_BPF

# 测试 BCC
sudo execsnoop -h
```

### Q: 某些工具不工作怎么办？

**A**: 常见原因：

1. **内核太老**: 升级到 4.9+
2. **缺少调试符号**: 安装 kernel-debuginfo
3. **BCC 版本太老**: 升级 BCC

```bash
# 安装调试符号（RHEL/CentOS）
sudo debuginfo-install kernel

# 安装调试符号（Ubuntu）
sudo apt-get install linux-image-$(uname -r)-dbgsym
```

---

## 参考资料

- [BCC 官方文档](https://github.com/iovisor/bcc)
- [eBPF 介绍](https://ebpf.io/)
- [BPF Performance Tools 书籍](http://www.brendangregg.com/bpf-performance-tools-book.html)
- [Linux 性能工具图谱](http://www.brendangregg.com/Perf/linux_observability_tools.png)

---

**最后更新**: 2026-04-18
