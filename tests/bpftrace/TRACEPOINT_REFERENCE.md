# bpftrace Tracepoint 字段参考

## 概述

本文档列出常用 tracepoint 的可用字段。使用 tracepoint 比 kprobe 更稳定，因为它们提供了稳定的内核接口。

## 如何查看 Tracepoint 字段

```bash
# 列出所有 tracepoint
sudo bpftrace -l 'tracepoint:*' | head

# 查看特定 tracepoint 的字段
sudo bpftrace -lv tracepoint:sched:sched_process_exec

# 查看某类 tracepoint
sudo bpftrace -l 'tracepoint:sched:*'
```

## 内置变量

这些变量在所有 bpftrace 探针中都可用：

| 变量 | 类型 | 说明 |
|------|------|------|
| `pid` | int | 进程 ID |
| `tid` | int | 线程 ID |
| `uid` | int | 用户 ID |
| `gid` | int | 组 ID |
| `nsecs` | uint64 | 时间戳（纳秒） |
| `elapsed` | uint64 | 自 bpftrace 启动经过的纳秒数 |
| `cpu` | int | CPU ID |
| `comm` | string | 进程名称 |
| `kstack` | string | 内核栈 |
| `ustack` | string | 用户栈 |
| `arg0-argN` | uint64 | 函数参数（kprobe/uprobe） |
| `retval` | uint64 | 返回值（kretprobe/uretprobe） |
| `func` | string | 被跟踪的函数名 |
| `probe` | string | 完整的探针名称 |
| `curtask` | uint64 | 当前任务结构指针 |

## 常用 Tracepoint 字段

### 1. 进程相关 (sched)

#### sched_process_fork

创建新进程时触发。

```c
tracepoint:sched:sched_process_fork {
    // 可用字段：
    args->parent_comm    // string - 父进程名
    args->parent_pid     // int    - 父进程 PID
    args->child_comm     // string - 子进程名
    args->child_pid      // int    - 子进程 PID
}
```

**示例：**
```c
tracepoint:sched:sched_process_fork {
    printf("%s[%d] forked child %s[%d]\n",
           args->parent_comm, args->parent_pid,
           args->child_comm, args->child_pid);
}
```

#### sched_process_exec

进程执行新程序时触发。

```c
tracepoint:sched:sched_process_exec {
    // 可用字段：
    args->filename       // string - 执行的文件路径
    // 注意：使用内置变量 comm 和 pid，不要用 args->old_comm
}
```

**示例：**
```c
tracepoint:sched:sched_process_exec {
    printf("%s[%d] exec: %s\n",
           comm, pid, str(args->filename));
}
```

#### sched_process_exit

进程退出时触发。

```c
tracepoint:sched:sched_process_exit {
    // 使用内置变量：
    // comm - 进程名
    // pid  - 进程 ID
}
```

**示例：**
```c
tracepoint:sched:sched_process_exit {
    printf("%s[%d] exited\n", comm, pid);
    @exit_count[comm] = count();
}
```

### 2. 系统调用 (syscalls)

#### sys_enter_* / sys_exit_*

每个系统调用都有对应的 enter 和 exit tracepoint。

```c
tracepoint:syscalls:sys_enter_open {
    args->filename       // char * - 文件名
    args->flags          // int    - 打开标志
    args->mode           // int    - 权限模式
}

tracepoint:syscalls:sys_enter_read {
    args->fd             // int    - 文件描述符
    args->buf            // char * - 缓冲区
    args->count          // size_t - 字节数
}

tracepoint:syscalls:sys_enter_write {
    args->fd             // int    - 文件描述符
    args->buf            // char * - 缓冲区
    args->count          // size_t - 字节数
}

tracepoint:syscalls:sys_exit_* {
    args->ret            // long   - 返回值
}
```

**示例：**
```c
tracepoint:syscalls:sys_enter_openat {
    printf("%s[%d] open: %s\n",
           comm, pid, str(args->filename));
}

tracepoint:syscalls:sys_exit_read {
    if (args->ret > 0) {
        printf("Read %d bytes\n", args->ret);
    }
}
```

#### raw_syscalls (通用)

所有系统调用的通用 tracepoint。

```c
tracepoint:raw_syscalls:sys_enter {
    args->id             // long - 系统调用号
}

tracepoint:raw_syscalls:sys_exit {
    args->id             // long - 系统调用号
    args->ret            // long - 返回值
}
```

### 3. 网络相关 (sock, net, tcp, udp)

#### inet_sock_set_state

TCP 套接字状态变化。

```c
tracepoint:sock:inet_sock_set_state {
    args->skaddr         // void *  - socket 地址
    args->oldstate       // int     - 旧状态
    args->newstate       // int     - 新状态
    args->sport          // uint16  - 源端口
    args->dport          // uint16  - 目标端口
    args->saddr          // uint8[4/16] - 源 IP
    args->daddr          // uint8[4/16] - 目标 IP
    args->family         // uint16  - 地址族 (AF_INET=2, AF_INET6=10)
    args->protocol       // uint16  - 协议 (TCP=6, UDP=17)
}
```

**TCP 状态值：**
```
1  = TCP_ESTABLISHED
2  = TCP_SYN_SENT
3  = TCP_SYN_RECV
4  = TCP_FIN_WAIT1
5  = TCP_FIN_WAIT2
6  = TCP_TIME_WAIT
7  = TCP_CLOSE
8  = TCP_CLOSE_WAIT
9  = TCP_LAST_ACK
10 = TCP_LISTEN
11 = TCP_CLOSING
```

**示例：**
```c
tracepoint:sock:inet_sock_set_state {
    if (args->protocol == 6 && args->newstate == 1) {  // TCP ESTABLISHED
        printf("%s[%d] TCP: %s:%d -> %s:%d\n",
               comm, pid,
               ntop(args->saddr), args->sport,
               ntop(args->daddr), args->dport);
    }
}
```

#### net_dev_queue / net_dev_xmit

网络设备发送数据包。

```c
tracepoint:net:net_dev_queue {
    args->skbaddr        // void * - sk_buff 地址
    args->len            // uint   - 数据包长度
    args->name           // char[16] - 设备名
}
```

### 4. 块设备 (block)

#### block_rq_issue / block_rq_complete

块设备 I/O 请求。

```c
tracepoint:block:block_rq_issue {
    args->dev            // uint   - 设备号
    args->sector         // uint64 - 扇区号
    args->nr_sector      // uint   - 扇区数
    args->bytes          // uint   - 字节数
    args->rwbs           // char[8] - 操作类型 (R/W/...)
    args->comm           // char[16] - 进程名
}

tracepoint:block:block_rq_complete {
    args->dev
    args->sector
    args->nr_sector
    args->error          // int    - 错误码
}
```

### 5. 信号 (signal)

#### signal_generate / signal_deliver

信号生成和传递。

```c
tracepoint:signal:signal_generate {
    args->sig            // int    - 信号编号
    args->errno          // int    - 错误码
    args->code           // int    - 信号代码
    args->comm           // char[16] - 进程名
    args->pid            // int    - 进程 ID
}

tracepoint:signal:signal_deliver {
    args->sig
    args->errno
    args->code
}
```

### 6. 页面错误 (exceptions)

#### page_fault_user / page_fault_kernel

```c
tracepoint:exceptions:page_fault_user {
    args->address        // uint64 - 故障地址
    args->ip             // uint64 - 指令指针
    args->error_code     // uint64 - 错误码
}
```

## 使用技巧

### 1. 字符串字段

某些字段返回指针，需要使用 `str()` 函数转换：

```c
// 正确
printf("File: %s\n", str(args->filename));

// 错误
printf("File: %s\n", args->filename);  // 会打印地址
```

### 2. 数组字段（IP 地址）

IP 地址通常是数组，使用 `ntop()` 转换：

```c
// IPv4 地址
printf("IP: %s\n", ntop(AF_INET, args->saddr));
printf("IP: %s\n", ntop(args->saddr));  // 自动检测

// IPv6 地址
printf("IP: %s\n", ntop(AF_INET6, args->saddr));
```

### 3. 检查字段是否存在

在编写脚本前，先检查 tracepoint 的实际字段：

```bash
sudo bpftrace -lv tracepoint:sched:sched_process_exec
```

输出示例：
```
tracepoint:sched:sched_process_exec
    int __syscall_nr;
    int old_pid;
    char filename[];
```

### 4. 条件过滤

使用字段进行过滤：

```c
// 只跟踪 TCP 协议
tracepoint:sock:inet_sock_set_state /args->protocol == 6/ {
    ...
}

// 只跟踪特定进程
tracepoint:syscalls:sys_enter_open /comm == "nginx"/ {
    ...
}

// 组合条件
tracepoint:block:block_rq_issue /args->bytes > 1048576 && comm == "mysql"/ {
    printf("Large I/O: %d bytes\n", args->bytes);
}
```

## 完整示例

### 示例 1：监控进程生命周期

```c
#!/usr/bin/env bpftrace

BEGIN {
    printf("Tracking process lifecycle...\n");
}

// Fork
tracepoint:sched:sched_process_fork {
    @forks[args->parent_comm] = count();
    printf("[FORK] %s[%d] -> %s[%d]\n",
           args->parent_comm, args->parent_pid,
           args->child_comm, args->child_pid);
}

// Exec
tracepoint:sched:sched_process_exec {
    printf("[EXEC] %s[%d] -> %s\n",
           comm, pid, str(args->filename));
}

// Exit
tracepoint:sched:sched_process_exit {
    printf("[EXIT] %s[%d]\n", comm, pid);
}

END {
    printf("\nFork count by parent:\n");
    print(@forks);
}
```

### 示例 2：TCP 连接追踪

```c
#!/usr/bin/env bpftrace

tracepoint:sock:inet_sock_set_state {
    if (args->protocol == 6) {  // TCP only
        $state_names[1] = "ESTABLISHED";
        $state_names[2] = "SYN_SENT";
        $state_names[7] = "CLOSE";

        printf("%s TCP %s:%d -> %s:%d: %d -> %d\n",
               comm,
               ntop(args->saddr), args->sport,
               ntop(args->daddr), args->dport,
               args->oldstate, args->newstate);

        if (args->newstate == 1) {  // New connection
            @connections[comm] = count();
        }
    }
}

END {
    printf("\nConnections by process:\n");
    print(@connections);
}
```

### 示例 3：文件 I/O 统计

```c
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_openat {
    @opens[comm, str(args->filename)] = count();
}

tracepoint:syscalls:sys_enter_read,
tracepoint:syscalls:sys_enter_write {
    @io_bytes[comm] += args->count;
}

interval:s:5 {
    printf("\n=== Top I/O processes ===\n");
    print(@io_bytes, 5);
    clear(@io_bytes);
}

END {
    printf("\n=== Top opened files ===\n");
    print(@opens, 10);
}
```

## 故障排查

### 问题：字段不存在

```
ERROR: Struct/union does not contain a field named 'xxx'
```

**解决：**
1. 使用 `bpftrace -lv` 查看实际字段
2. 检查内核版本（字段可能在不同版本中变化）
3. 使用内置变量代替（如 `comm`, `pid`）

### 问题：类型不匹配

```
ERROR: ntop() expects an integer or array argument
```

**解决：**
确保传递正确类型的字段给函数

```c
// 正确
ntop(args->saddr)        // IP 地址数组
str(args->filename)      // 字符串指针

// 错误
str(args->pid)           // pid 是整数
ntop(args->filename)     // filename 不是 IP
```

## 参考资料

- [Linux Tracepoint 文档](https://www.kernel.org/doc/html/latest/trace/tracepoints.html)
- [bpftrace 参考指南](https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md)
- [可用 Tracepoint 列表](https://www.kernel.org/doc/html/latest/trace/events.html)

---

更新日期：2026-04-18
