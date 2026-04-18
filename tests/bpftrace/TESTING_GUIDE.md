# bpftrace 测试指南

## 概述

本目录包含完整的 bpftrace 测试框架，提供 8 种不同的测试场景和配套的模拟程序。

## 测试列表

| 测试脚本 | 测试内容 | Mock 程序 | 主要跟踪点 |
|---------|---------|----------|-----------|
| test_syscall_count.sh | 系统调用统计 | syscall_simulator | tracepoint:raw_syscalls:sys_enter |
| test_function_latency.sh | 内核函数延迟 | latency_simulator | kprobe:do_nanosleep |
| test_tcp_lifecycle.sh | TCP 生命周期 | tcp_client (来自BCC) | kprobe:tcp_set_state |
| test_memory_alloc.sh | 大内存分配 | memory_allocator | uprobe:libc:malloc |
| test_process_lifecycle.sh | 进程生命周期 | process_spawner | tracepoint:sched:* |
| test_vfs_io.sh | VFS I/O 操作 | io_generator | kprobe:vfs_read/vfs_write |

## 快速开始

### 1. 安装 bpftrace

```bash
# 自动安装
sudo ./install_bpftrace.sh

# 或手动安装
# Fedora/RHEL
sudo dnf install bpftrace

# Ubuntu/Debian
sudo apt install bpftrace
```

### 2. 检查环境

```bash
sudo ./check_bpftrace.sh
```

检查内容：
- 内核版本 (需要 >= 4.9)
- bpftrace 安装状态
- BPF 文件系统
- debugfs 挂载
- tracepoints 和 kprobes 支持
- BTF (BPF Type Format) 支持

### 3. 编译 Mock 程序

```bash
cd mock_programs
make
```

生成的程序：
- `syscall_simulator` - 系统调用模拟
- `latency_simulator` - 延迟模拟
- `memory_allocator` - 内存分配
- `process_spawner` - 进程创建
- `io_generator` - I/O 操作

### 4. 运行测试

```bash
# 单个测试
sudo ./test_syscall_count.sh
sudo ./test_function_latency.sh
sudo ./test_tcp_lifecycle.sh
sudo ./test_memory_alloc.sh
sudo ./test_process_lifecycle.sh
sudo ./test_vfs_io.sh

# 运行所有测试
sudo ./run_all_tests.sh
```

## 测试详解

### 1. 系统调用统计 (test_syscall_count.sh)

**测试内容**：
- 统计进程的系统调用总数
- 按系统调用类型分类统计

**bpftrace 示例**：
```bash
# 统计所有系统调用
sudo bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'

# 按类型统计
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); }'
```

**预期结果**：
- syscall_simulator 会产生大量系统调用
- 主要类型：getpid, gettimeofday, open, read, close, stat, nanosleep

### 2. 内核函数延迟 (test_function_latency.sh)

**测试内容**：
- 测量 do_nanosleep 函数的延迟
- 生成延迟直方图

**bpftrace 示例**：
```bash
sudo bpftrace -e '
kprobe:do_nanosleep { @start[tid] = nsecs; }
kretprobe:do_nanosleep /@start[tid]/ {
    @usecs = hist((nsecs - @start[tid]) / 1000);
    delete(@start[tid]);
}'
```

**预期结果**：
- 直方图显示 1ms, 5ms, 10ms, 50ms, 100ms 的延迟峰值
- 可以清晰看到不同延迟级别的分布

**直方图解读**：
```
[1K, 2K)     : 1000-2000 us  → 1-2 ms
[4K, 8K)     : 4000-8000 us  → 4-8 ms
[8K, 16K)    : 8000-16000 us → 8-16 ms
[32K, 64K)   : 32K-64K us    → 32-64 ms
[64K, 128K)  : 64K-128K us   → 64-128 ms
```

### 3. TCP 生命周期 (test_tcp_lifecycle.sh)

**测试内容**：
- 跟踪 TCP 状态转换
- 统计新建连接数

**TCP 状态说明**：
```
1  = ESTABLISHED   - 已建立连接
2  = SYN_SENT      - 发送 SYN，等待响应
3  = SYN_RECV      - 接收 SYN，发送 SYN-ACK
4  = FIN_WAIT1     - 主动关闭，等待 ACK
5  = FIN_WAIT2     - 等待对方关闭
6  = TIME_WAIT     - 等待足够时间确保关闭
7  = CLOSE         - 关闭状态
8  = CLOSE_WAIT    - 被动关闭，等待应用关闭
9  = LAST_ACK      - 等待最后的 ACK
10 = LISTEN        - 监听状态
11 = CLOSING       - 双方同时关闭
```

**bpftrace 示例**：
```bash
sudo bpftrace -e '
kprobe:tcp_set_state {
    $sk = (struct sock *)arg0;
    $newstate = arg1;
    printf("%s [%d] state: %d -> %d\n",
        comm, pid, $sk->__sk_common.skc_state, $newstate);
}'
```

**典型状态转换**：
- 客户端：CLOSE → SYN_SENT → ESTABLISHED → FIN_WAIT1 → TIME_WAIT
- 服务端：LISTEN → SYN_RECV → ESTABLISHED → CLOSE_WAIT → LAST_ACK

### 4. 内存分配跟踪 (test_memory_alloc.sh)

**测试内容**：
- 跟踪大内存分配 (>1MB)
- 统计分配次数和大小

**bpftrace 示例**：
```bash
# 用户空间 malloc
sudo bpftrace -e '
uprobe:/lib/x86_64-linux-gnu/libc.so.6:malloc /arg0 > 1048576/ {
    printf("malloc(%d bytes = %.2f MB)\n", arg0, arg0 / 1048576.0);
}'

# 内核空间 kmalloc
sudo bpftrace -e '
kprobe:__kmalloc /arg1 > 1048576/ {
    printf("kmalloc(%d bytes)\n", arg1);
}'
```

**预期结果**：
- memory_allocator 默认分配 2MB 块
- 可以看到每次分配的具体大小和地址
- 直方图显示分配大小分布

### 5. 进程生命周期 (test_process_lifecycle.sh)

**测试内容**：
- fork 事件跟踪
- exec 事件跟踪
- exit 事件跟踪
- 完整生命周期时间

**bpftrace 示例**：
```bash
# Fork 跟踪
sudo bpftrace -e '
tracepoint:sched:sched_process_fork {
    printf("%s[%d] fork -> %d\n",
        args->parent_comm, args->parent_pid, args->child_pid);
}'

# Exec 跟踪
sudo bpftrace -e '
tracepoint:sched:sched_process_exec {
    printf("%s[%d] exec: %s\n",
        args->old_comm, args->old_pid, str(args->filename));
}'

# 生命周期
sudo bpftrace -e '
tracepoint:sched:sched_process_fork {
    @start[args->child_pid] = nsecs;
}
tracepoint:sched:sched_process_exit /@start[pid]/ {
    printf("lifetime: %d ms\n", (nsecs - @start[pid]) / 1000000);
}'
```

**预期结果**：
- process_spawner 会创建多个子进程
- 执行 /bin/echo, /bin/date, /usr/bin/whoami
- 可以看到从 fork 到 exit 的完整时间

### 6. VFS I/O 操作 (test_vfs_io.sh)

**测试内容**：
- vfs_read/vfs_write 统计
- I/O 大小分布
- 文件系统延迟

**bpftrace 示例**：
```bash
# 统计读写次数
sudo bpftrace -e '
kprobe:vfs_read { @read = count(); @read_bytes = sum(arg2); }
kprobe:vfs_write { @write = count(); @write_bytes = sum(arg2); }
'

# I/O 延迟
sudo bpftrace -e '
kprobe:vfs_write { @start[tid] = nsecs; }
kretprobe:vfs_write /@start[tid]/ {
    @latency = hist((nsecs - @start[tid]) / 1000);
    delete(@start[tid]);
}'
```

**预期结果**：
- io_generator 产生可配置的读写操作
- 直方图显示 I/O 操作大小和延迟分布
- 可以区分读操作和写操作

## Mock 程序说明

### syscall_simulator
```bash
./syscall_simulator [iterations]
# 默认：100 次迭代
# 每次迭代执行：getpid, gettimeofday, open, read, close, stat, nanosleep
```

### latency_simulator
```bash
./latency_simulator [iterations]
# 默认：50 次迭代
# 延迟模式：1ms, 5ms, 10ms, 50ms, 100ms 循环
```

### memory_allocator
```bash
./memory_allocator [iterations] [size]
# 默认：10 次迭代，每次 2MB
# 例如：./memory_allocator 5 3145728  # 5次，每次3MB
```

### process_spawner
```bash
./process_spawner [count] [interval]
# 默认：10 个进程，间隔 1 秒
# 例如：./process_spawner 5 0  # 5个进程，无间隔
```

### io_generator
```bash
./io_generator [operation] [count] [size]
# operation: write 或 read
# 默认：write, 100 次，每次 4KB
# 例如：./io_generator read 50 8192  # 读50次，每次8KB
```

## 常见问题

### Q1: bpftrace 提示权限错误？
```bash
# 解决方法：使用 sudo
sudo ./test_*.sh
```

### Q2: 找不到 tracepoint？
```bash
# 检查 debugfs 是否挂载
sudo mount -t debugfs none /sys/kernel/debug

# 查看可用 tracepoints
sudo ls /sys/kernel/debug/tracing/events/
```

### Q3: uprobe 找不到 libc？
```bash
# 查找 libc 路径
find /lib /usr/lib -name "libc.so.6" 2>/dev/null

# 在脚本中会自动检测，或使用内核 kmalloc 作为替代
```

### Q4: TCP 跟踪看不到数据？
```bash
# 确保有实际的网络连接
# 可以手动触发：
curl https://www.google.com
```

### Q5: 直方图输出看不懂？
直方图格式为 `[min, max)  : count`：
- 数字单位根据上下文（us 微秒、bytes 字节等）
- K = 1024, M = 1024*1024
- 例如 [4K, 8K) = [4096, 8192)

### Q6: 虚拟机环境下某些功能不可用？
- 虚拟机可能缺少某些硬件 PMU 支持
- 使用软件事件和 tracepoint 作为替代
- kprobes 和 tracepoints 在 VM 中通常都可用

## 性能影响

bpftrace 在生产环境使用的性能影响：

| 探针类型 | 开销 | 适用场景 |
|---------|------|---------|
| tracepoint | 极低 (~100ns) | 生产环境，持续监控 |
| kprobe | 低 (~1-2μs) | 短期调试，按需启用 |
| uprobe | 中 (~2-5μs) | 开发/测试，短期使用 |
| 高频探针 | 高 | 仅测试环境 |

建议：
- 生产环境优先使用 tracepoint
- 使用过滤条件减少事件数量
- 避免在热路径上使用高开销操作
- 使用聚合而非逐条打印

## 进阶使用

### 自定义 bpftrace 脚本

创建 `.bt` 文件：
```bash
# example.bt
#!/usr/bin/env bpftrace

BEGIN {
    printf("开始跟踪...\n");
}

kprobe:vfs_read {
    @reads[comm] = count();
}

END {
    printf("\n读操作统计:\n");
    print(@reads);
}
```

运行：
```bash
sudo bpftrace example.bt
```

### 结合其他工具

```bash
# 与 perf 结合
sudo perf record -e 'syscalls:*' -a &
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); }'

# 与 strace 对比
strace -c ./syscall_simulator &
sudo bpftrace -e 'tracepoint:raw_syscalls:sys_enter /pid == <PID>/ { @[comm] = count(); }'
```

## 参考资料

- [bpftrace 官方文档](https://github.com/iovisor/bpftrace)
- [bpftrace 参考指南](https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md)
- [BPF 性能工具](http://www.brendangregg.com/ebpf.html)
- [Linux Tracing Systems](https://jvns.ca/blog/2017/07/05/linux-tracing-systems/)

## 故障排查

如果测试失败，按以下步骤检查：

1. 运行环境检查：`sudo ./check_bpftrace.sh`
2. 查看内核日志：`sudo dmesg | tail -50`
3. 测试 bpftrace：`sudo bpftrace -e 'BEGIN { printf("test\n"); exit(); }'`
4. 检查 mock 程序：`cd mock_programs && make clean && make`
5. 查看详细错误：在测试脚本中添加 `set -x` 启用调试输出

## 维护和更新

```bash
# 清理所有编译产物
cd mock_programs && make clean

# 重新编译
make

# 更新 bpftrace
sudo dnf update bpftrace  # Fedora
sudo apt upgrade bpftrace  # Ubuntu
```

---

创建日期：2026-04-18
最后更新：2026-04-18
