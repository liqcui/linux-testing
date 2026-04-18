# bpftrace 测试和示例

## 概述

bpftrace 是一个基于 eBPF 的高级跟踪语言，用于 Linux 系统的性能分析和故障排查。它提供了简洁的语法来编写动态跟踪脚本。

本目录包含 bpftrace 的常用测试案例、示例脚本和模拟程序。

---

## 测试案例列表

| 测试案例 | 用途 | 脚本文件 |
|---------|------|----------|
| [系统调用统计](#1-系统调用统计) | 统计进程系统调用次数 | test_syscall_count.sh |
| [内核函数延迟](#2-内核函数延迟) | 测量内核函数执行时间 | test_function_latency.sh |
| [TCP生命周期](#3-tcp生命周期) | 跟踪TCP连接状态变化 | test_tcp_lifecycle.sh |
| [内存分配跟踪](#4-内存分配跟踪) | 监控大内存分配 | test_memory_alloc.sh |
| [文件系统操作](#5-文件系统操作) | 跟踪文件读写 | test_filesystem.sh |
| [进程创建销毁](#6-进程创建销毁) | 监控进程生命周期 | test_process_lifecycle.sh |
| [磁盘I/O延迟](#7-磁盘io延迟) | 分析磁盘I/O性能 | test_disk_latency.sh |
| [网络包跟踪](#8-网络包跟踪) | 跟踪网络包收发 | test_network_packets.sh |

---

## 安装 bpftrace

### RHEL/CentOS/Fedora

```bash
sudo dnf install bpftrace
```

### Ubuntu/Debian

```bash
sudo apt-get install bpftrace
```

### 验证安装

```bash
bpftrace --version
```

---

## 1. 系统调用统计

### 用途
统计每个进程执行的系统调用次数，用于了解程序的系统调用模式。

### bpftrace 脚本

```bash
# 统计所有进程的系统调用
bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'

# 统计特定进程的系统调用
bpftrace -e 'tracepoint:raw_syscalls:sys_enter /comm == "myapp"/ { @[comm] = count(); }'

# 按系统调用名称统计
bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); }'
```

### 示例输出

```
Attaching 1 probe...
^C

@[bash]: 42
@[sshd]: 156
@[python]: 1234
@[mysqld]: 5678
```

### 使用场景

- **性能分析**: 识别频繁调用系统调用的进程
- **行为分析**: 了解程序的系统调用模式
- **异常检测**: 发现异常的系统调用频率

### 模拟程序

使用 `syscall_simulator` 程序来生成系统调用活动：

```bash
cd mock_programs
./syscall_simulator 1000  # 执行1000次系统调用
```

---

## 2. 内核函数延迟

### 用途
测量内核函数的执行时间，以直方图形式显示延迟分布。

### bpftrace 脚本

```bash
# do_nanosleep 延迟直方图
bpftrace -e 'kprobe:do_nanosleep { @start[tid] = nsecs; }
              kretprobe:do_nanosleep /@start[tid]/
              { @usecs = hist((nsecs - @start[tid]) / 1000); delete(@start[tid]); }'

# VFS 读操作延迟
bpftrace -e 'kprobe:vfs_read { @start[tid] = nsecs; }
              kretprobe:vfs_read /@start[tid]/
              { @usecs = hist((nsecs - @start[tid]) / 1000); delete(@start[tid]); }'
```

### 示例输出

```
@usecs:
[1, 2)                 5 |                                                    |
[2, 4)                12 |@@                                                  |
[4, 8)                45 |@@@@@@@@                                            |
[8, 16)              125 |@@@@@@@@@@@@@@@@@@@@@@@                             |
[16, 32)             234 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         |
[32, 64)             289 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|
[64, 128)            156 |@@@@@@@@@@@@@@@@@@@@@@@@@@                          |
[128, 256)            67 |@@@@@@@@@@@@                                        |
```

### 使用场景

- **性能瓶颈分析**: 识别慢的内核函数
- **延迟分析**: 了解延迟分布
- **基准测试**: 对比优化前后的性能

### 模拟程序

```bash
cd mock_programs
./latency_simulator    # 模拟各种延迟操作
```

---

## 3. TCP生命周期

### 用途
跟踪TCP连接的状态变化，用于诊断网络连接问题。

### bpftrace 脚本

```bash
# TCP状态变化
bpftrace -e 'kprobe:tcp_set_state {
    printf("%s PID:%d %s -> %s\n",
           strftime("%H:%M:%S", nsecs),
           pid,
           comm,
           @tcp_states[arg1],
           @tcp_states[arg2]);
}'

# 简化版
bpftrace -e 'kprobe:tcp_set_state {
    printf("%s %d -> %d\n", comm, args->oldstate, args->newstate);
}'
```

### TCP 状态说明

| 状态值 | 状态名 | 说明 |
|--------|--------|------|
| 1 | ESTABLISHED | 连接已建立 |
| 2 | SYN_SENT | 发送连接请求 |
| 3 | SYN_RECV | 收到连接请求 |
| 4 | FIN_WAIT1 | 等待关闭 |
| 5 | FIN_WAIT2 | 等待对方关闭 |
| 6 | TIME_WAIT | 等待足够时间关闭 |
| 7 | CLOSE | 连接关闭 |
| 10 | LISTEN | 监听状态 |

### 示例输出

```
nginx 7 -> 1       # LISTEN -> ESTABLISHED (接受连接)
nginx 1 -> 4       # ESTABLISHED -> FIN_WAIT1 (开始关闭)
nginx 4 -> 6       # FIN_WAIT1 -> TIME_WAIT
curl 2 -> 1        # SYN_SENT -> ESTABLISHED (连接成功)
```

### 使用场景

- **连接问题诊断**: 查看连接卡在哪个状态
- **性能分析**: 了解连接建立和关闭的模式
- **故障排查**: 发现异常的状态转换

### 模拟程序

```bash
cd mock_programs
# 使用之前的 tcp_client 和 tcp_server
./tcp_server 8888 &
./tcp_client 5 1000
```

---

## 4. 内存分配跟踪

### 用途
监控大内存分配，用于发现内存使用异常。

### bpftrace 脚本

```bash
# 跟踪超过1MB的内核内存分配
bpftrace -e 'kprobe:__kmalloc /arg1 > 1048576/ {
    printf("%s allocated %d bytes\n", comm, arg1);
}'

# 跟踪所有内存分配并统计
bpftrace -e 'kprobe:__kmalloc { @bytes[comm] = sum(arg1); }'

# 用户空间内存分配
bpftrace -e 'uprobe:/lib/x86_64-linux-gnu/libc.so.6:malloc /arg0 > 1048576/ {
    printf("%s malloc(%d)\n", comm, arg0);
}'
```

### 示例输出

```
python allocated 2097152 bytes
mysqld allocated 4194304 bytes
java allocated 10485760 bytes

@bytes[python]: 15728640
@bytes[mysqld]: 52428800
@bytes[java]: 104857600
```

### 使用场景

- **内存泄漏检测**: 发现持续增长的内存分配
- **资源监控**: 监控大内存分配
- **性能优化**: 识别过度内存分配

### 模拟程序

```bash
cd mock_programs
./memory_allocator 10 2097152  # 分配10次，每次2MB
```

---

## 5. 文件系统操作

### 用途
跟踪文件读写操作，分析I/O模式。

### bpftrace 脚本

```bash
# 统计文件读取
bpftrace -e 'tracepoint:syscalls:sys_enter_read {
    @reads[comm] = count();
    @bytes[comm] = sum(args->count);
}'

# 跟踪大文件读取（超过1MB）
bpftrace -e 'tracepoint:syscalls:sys_enter_read /args->count > 1048576/ {
    printf("%s reading %d bytes from fd %d\n", comm, args->count, args->fd);
}'

# VFS操作统计
bpftrace -e 'kprobe:vfs_read,kprobe:vfs_write {
    @[probe, comm] = count();
}'
```

### 示例输出

```
@reads[dd]: 1000
@reads[cat]: 50
@bytes[dd]: 1073741824    # 1GB
@bytes[cat]: 512000       # 500KB
```

### 模拟程序

```bash
cd mock_programs
./io_generator write 100 4096   # 写100次，每次4KB
./io_generator read 100 4096    # 读100次，每次4KB
```

---

## 6. 进程创建销毁

### 用途
监控进程的创建和销毁，用于分析进程活动。

### bpftrace 脚本

```bash
# 进程创建
bpftrace -e 'tracepoint:sched:sched_process_exec {
    printf("%s[%d] exec: %s\n", comm, pid, str(args->filename));
}'

# 进程退出
bpftrace -e 'tracepoint:sched:sched_process_exit {
    printf("%s[%d] exit\n", comm, pid);
}'

# 进程创建和退出（组合）
bpftrace -e '
    tracepoint:sched:sched_process_exec { @exec[comm] = count(); }
    tracepoint:sched:sched_process_exit { @exit[comm] = count(); }
'
```

### 示例输出

```
bash[12345] exec: /bin/ls
ls[12346] exit

@exec[bash]: 15
@exec[python]: 5
@exit[ls]: 12
@exit[grep]: 8
```

### 使用场景

- **进程监控**: 实时查看进程创建
- **异常检测**: 发现异常的进程活动
- **安全审计**: 监控可疑进程执行

### 模拟程序

```bash
cd mock_programs
./process_spawner 10 1   # 创建10个进程，间隔1秒
```

---

## 7. 磁盘I/O延迟

### 用途
分析磁盘I/O操作的延迟分布。

### bpftrace 脚本

```bash
# 块设备I/O延迟直方图
bpftrace -e '
    kprobe:blk_account_io_start { @start[arg0] = nsecs; }
    kprobe:blk_account_io_done /@start[arg0]/ {
        @usecs = hist((nsecs - @start[arg0]) / 1000);
        delete(@start[arg0]);
    }
'

# 按进程统计I/O延迟
bpftrace -e '
    kprobe:blk_account_io_start { @start[arg0] = nsecs; @comm[arg0] = comm; }
    kprobe:blk_account_io_done /@start[arg0]/ {
        $lat = (nsecs - @start[arg0]) / 1000;
        @usecs[@comm[arg0]] = hist($lat);
        delete(@start[arg0]);
        delete(@comm[arg0]);
    }
'
```

### 示例输出

```
@usecs:
[0, 1)                 0 |                                                    |
[1, 2)                 5 |@                                                   |
[2, 4)                23 |@@@@                                                |
[4, 8)                67 |@@@@@@@@@@@@                                        |
[8, 16)              145 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@                        |
[16, 32)             234 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@        |
[32, 64)             289 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|
```

### 模拟程序

```bash
cd mock_programs
./disk_io 20 500  # 之前创建的程序
```

---

## 8. 网络包跟踪

### 用途
跟踪网络包的收发，用于网络性能分析。

### bpftrace 脚本

```bash
# 网络包接收统计
bpftrace -e 'tracepoint:net:netif_receive_skb {
    @pkts[str(args->name)] = count();
    @bytes[str(args->name)] = sum(args->len);
}'

# TCP发送跟踪
bpftrace -e 'kprobe:tcp_sendmsg {
    printf("%s sending %d bytes\n", comm, arg2);
}'

# 网络包大小分布
bpftrace -e 'tracepoint:net:netif_receive_skb {
    @size = hist(args->len);
}'
```

### 示例输出

```
@pkts[eth0]: 15234
@pkts[lo]: 567
@bytes[eth0]: 45678912
@bytes[lo]: 123456
```

### 模拟程序

```bash
cd mock_programs
./tcp_client 10 500  # 之前创建的程序
```

---

## 快速开始

### 1. 检查环境

```bash
# 运行环境检查脚本
sudo ./check_bpftrace.sh
```

### 2. 编译模拟程序

```bash
cd mock_programs
make
```

### 3. 运行测试

```bash
# 运行所有测试
sudo ./run_all_tests.sh

# 运行单个测试
sudo ./test_syscall_count.sh
sudo ./test_function_latency.sh
sudo ./test_tcp_lifecycle.sh
```

---

## 常用技巧

### 1. 过滤特定进程

```bash
# 只跟踪特定进程
bpftrace -e 'tracepoint:raw_syscalls:sys_enter /comm == "nginx"/ { @[comm] = count(); }'

# 只跟踪特定PID
bpftrace -e 'tracepoint:raw_syscalls:sys_enter /pid == 1234/ { @[comm] = count(); }'
```

### 2. 时间戳

```bash
# 添加时间戳
bpftrace -e 'tracepoint:raw_syscalls:sys_enter {
    printf("%s: %s\n", strftime("%H:%M:%S", nsecs), comm);
}'
```

### 3. 堆栈跟踪

```bash
# 显示用户态堆栈
bpftrace -e 'kprobe:tcp_sendmsg {
    printf("%s\n", ustack);
}'

# 显示内核态堆栈
bpftrace -e 'kprobe:tcp_sendmsg {
    printf("%s\n", kstack);
}'
```

### 4. 限制输出

```bash
# 只显示Top 10
bpftrace -e 'tracepoint:raw_syscalls:sys_enter {
    @[comm] = count();
} END {
    print(@, 10);
}'
```

---

## 常见问题

### Q: bpftrace 需要 root 权限吗？

**A**: 是的，大多数 bpftrace 脚本需要 root 权限。

```bash
sudo bpftrace script.bt
```

### Q: 如何保存输出？

**A**: 使用重定向或 `-o` 选项：

```bash
# 重定向
sudo bpftrace script.bt > output.txt

# 使用 -o 选项
sudo bpftrace -o output.txt script.bt
```

### Q: 如何限制运行时间？

**A**: 使用 `timeout` 命令：

```bash
timeout 30 sudo bpftrace script.bt  # 运行30秒
```

### Q: 虚拟机中可以使用 bpftrace 吗？

**A**: 可以，但需要：
- 内核版本 >= 4.9
- 内核配置支持 BPF
- 某些高级功能可能不可用

---

## 参考资料

- [bpftrace 官方文档](https://github.com/iovisor/bpftrace)
- [bpftrace 参考指南](https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md)
- [BPF Performance Tools 书籍](http://www.brendangregg.com/bpf-performance-tools-book.html)
- [bpftrace 一行脚本](https://github.com/iovisor/bpftrace/blob/master/docs/tutorial_one_liners.md)

---

**最后更新**: 2026-04-18
