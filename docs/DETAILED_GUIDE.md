# Linux 性能测试技能集

本文档总结了常用的 Linux 性能测试命令和技巧。

## 目录

- [网络性能测试](#网络性能测试)
- [进程调度测试](#进程调度测试)
- [块设备I/O测试](#块设备io测试)
- [TCP协议栈测试](#tcp协议栈测试)

---

## 网络性能测试

### 1. 跟踪网络数据包流程

**命令**:
```bash
perf trace -e 'net:*' ping -c 1 google.com
```

**说明**: 跟踪单个 ping 包在网络栈中的发送和接收过程

**关键事件**:
- `net:net_dev_queue` - 数据包进入发送队列
- `net:net_dev_start_xmit` - 开始传输到网卡
- `net:net_dev_xmit` - 发送完成
- `net:napi_gro_receive_entry` - NAPI 接收数据包
- `net:netif_receive_skb` - 数据包进入协议栈

**输出示例**:
```
0.000 ping/2955314 net:net_dev_queue(skbaddr: 0xffff947c20d59e00, len: 98, name: "eth0")
0.020 ping/2955314 net:net_dev_start_xmit(name: "eth0", queue_mapping: 3, ...)
0.028 ping/2955314 net:net_dev_xmit(skbaddr: 0xffff947c20d59e00, len: 98, name: "eth0")
```

**数据包大小计算**:
```
总长度(98) = 以太网头(14) + IP头(20) + ICMP头(8) + 数据(56)
```

### 2. 查看完整的发送和接收事件

**命令**:
```bash
# 跟踪所有 CPU 的网络事件
perf trace -e 'net:*' -a ping -c 1 google.com

# 或使用 record + script 查看详细时间线
perf record -e 'net:*' -a ping -c 1 google.com
perf script
```

**关键发现**:
- 发送在用户进程上下文中执行（如 `ping` 进程）
- 接收在内核软中断上下文中执行（`swapper` 进程）
- 发送和接收可能在不同的 CPU 核心上处理（多队列网卡）

---

## 进程调度测试

### 1. 调度延迟分析

**命令**:
```bash
# 记录 10 秒的调度事件
perf sched record -a sleep 10

# 查看调度延迟报告
perf sched latency
```

**输出字段说明**:
| 字段 | 含义 |
|------|------|
| Runtime ms | 进程在 CPU 上实际运行的时间 |
| Switches | 上下文切换次数 |
| Avg delay ms | 平均调度延迟（等待 CPU 的时间） |
| Max delay ms | 最大调度延迟 |

**性能标准**:
- 桌面/服务器系统: < 10ms 可接受
- 低延迟系统: < 1ms
- 实时系统: < 100μs
- 硬实时系统: < 10μs

### 2. 调度时间线分析

**命令**:
```bash
perf sched record -a sleep 10
perf sched timehist
```

**输出字段**:
- `wait time` - 在运行队列中等待的时间
- `sch delay` - 从唤醒到运行的延迟
- `run time` - 在 CPU 上运行的时间

**示例**:
```
time         cpu  task name        wait time  sch delay  run time
3458569.254  [0]  stress-ng[2955]      0.000      0.000     1.122
3458569.254  [0]  rcu_preempt[16]      0.000      0.012     0.003
3458569.258  [0]  stress-ng[2955]      0.003      0.000     3.977
```

### 3. CPU 调度映射

**命令**:
```bash
perf sched record -a sleep 10
perf sched map
```

**说明**: 显示每个时刻每个 CPU 正在运行的任务

**输出示例**:
```
B0  G0  E0  J0   3458569.496397 secs
│   │   │   │
│   │   │   └─ CPU 3: 任务 J0
│   │   └───── CPU 2: 任务 E0
│   └───────── CPU 1: 任务 G0
└───────────── CPU 0: 任务 B0

. => swapper:0 (空闲)
```

### 4. 创建 CPU 负载

**命令**:
```bash
# 在 4 核系统上创建 4 个 CPU 密集型进程
stress-ng --cpu 4 --timeout 10s

# 在压力测试期间记录调度事件
perf sched record -a stress-ng --cpu 4 --timeout 10
```

---

## 块设备I/O测试

### 1. 基本块事件跟踪

**命令**:
```bash
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100
```

**重要提示**: 默认情况下，写操作会被页缓存吸收，不会触发真实的磁盘 I/O！

### 2. 直接 I/O 测试（绕过缓存）

**命令**:
```bash
# 强制直接写入磁盘
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 oflag=direct
```

**关键事件**:
- `block:block_bio_queue` - bio（块I/O）进入队列
- `block:block_getrq` - 获取请求结构
- `block:block_rq_insert` - 请求插入 I/O 调度器
- `block:block_rq_issue` - 请求发送到设备驱动
- `block:block_rq_complete` - 请求完成
- `block:block_plug/unplug` - I/O 批处理开始/结束
- `block:block_bio_backmerge` - bio 后向合并优化

### 3. 同步写入测试

**命令**:
```bash
# 写入后立即调用 fsync 刷盘
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 conv=fsync
```

### 4. 观察延迟刷盘

**命令**:
```bash
# 先写入（会缓存）
dd if=/dev/zero of=test bs=1M count=100

# 然后观察刷盘过程
perf stat -e 'block:*' sync
```

### 5. 性能对比

| 模式 | 典型速度 | I/O 事件数 | 说明 |
|------|---------|-----------|------|
| 缓存写入 | 2-5 GB/s | 0 | 只写到内存 |
| Direct I/O | 500 MB/s - 1 GB/s | 100+ | 绕过缓存，真实磁盘速度 |
| fsync 同步 | 400 MB/s - 900 MB/s | 100+ | 写入 + 强制刷盘 |

### 6. 查看页缓存使用情况

**命令**:
```bash
# 查看内存统计（观察 buff/cache 列）
free -h

# 清空页缓存（仅用于测试，不推荐生产环境使用）
sync
echo 3 > /proc/sys/vm/drop_caches
```

### 7. 详细 I/O 事件跟踪

**命令**:
```bash
# 记录详细的块事件
perf record -e 'block:*' -a dd if=/dev/zero of=test bs=1M count=100 oflag=direct

# 查看详细时间线
perf script
```

**输出格式**:
```
dd 12345 [001] 1234.567: block:block_bio_queue: 8,0 W 2048 + 2048 [dd]
                                                 │ │ │    │   │
                                                 │ │ │    │   └─ 扇区数
                                                 │ │ │    └───── 起始扇区
                                                 │ │ └────────── 写操作(W)/读操作(R)
                                                 │ └──────────── minor 设备号
                                                 └────────────── major 设备号
```

---

## TCP协议栈测试

### 1. Packetdrill 测试工具

**安装**:
```bash
git clone https://github.com/google/packetdrill.git
cd packetdrill/gtests/net/packetdrill
./configure
make
```

### 2. 基本 TCP 连接测试

**测试脚本** (`test.pkt`):
```bash
// 建立TCP连接
0.000 socket(..., SOCK_STREAM, IPPROTO_TCP) = 3
0.000 setsockopt(3, SOL_SOCKET, SO_REUSEADDR, [1], 4) = 0
0.000 bind(3, ..., ...) = 0
0.000 listen(3, 1) = 0

// 模拟客户端 SYN
0.100 < S 0:0(0) win 64800 <mss 1440,sackOK,nop,nop,nop,wscale 7>

// 期望服务器 SYN-ACK（注意：使用实际内核返回的选项顺序）
0.100 > S. 0:0(0) ack 1 win 64800 <mss 1440,nop,nop,sackOK,nop,wscale 7>

// 模拟客户端 ACK
0.200 < . 1:1(0) ack 1 win 64800
0.200 accept(3, ..., ...) = 4

// 测试数据传输
0.300 write(4, ..., 1000) = 1000
0.300 > P. 1:1001(1000) ack 1 win 64800
```

**运行测试**:
```bash
./packetdrill test.pkt
```

**测试成功**: 无输出（静默退出）
**测试失败**: 打印详细的错误信息

### 3. Packetdrill 语法详解

**时间戳格式**:
- `0.000` - 相对测试开始的时间（秒）

**方向符号**:
- `<` - 注入数据包（模拟接收）
- `>` - 验证发送的数据包（期望发送）

**TCP 标志**:
- `S` - SYN（同步）
- `.` - ACK（确认）
- `P` - PSH（推送）
- `F` - FIN（结束）
- `R` - RST（重置）

**序列号格式**:
- `0:0(0)` - 起始序列号:结束序列号(数据长度)
- `1:1001(1000)` - seq=1, 数据长度=1000, 结束seq=1001

**TCP 选项**:
- `mss 1440` - 最大报文段大小
- `sackOK` - 支持选择性确认
- `nop` - 填充字节（对齐）
- `wscale 7` - 窗口扩大因子（实际窗口 = win × 2^7）

### 4. 常见错误处理

**TCP 选项顺序不匹配**:
```
错误: bad outbound TCP options
解决: 使用内核实际返回的选项顺序
      常见顺序: <mss 1440,nop,nop,sackOK,nop,wscale 7>
```

**窗口大小不匹配**:
```
错误: expected: 65535 vs actual: 64800
解决: 使用实际的窗口大小（受系统配置影响）
```

### 5. 调试技巧

**详细输出**:
```bash
./packetdrill --verbose test.pkt
```

**调试模式**:
```bash
./packetdrill --debug test.pkt
```

**检查退出码**:
```bash
./packetdrill test.pkt
echo $?  # 0 = 成功, 非0 = 失败
```

---

## 通用测试技巧

### 1. Perf 工具基础

**列出所有可用事件**:
```bash
perf list                    # 所有事件
perf list 'net:*'           # 网络事件
perf list 'sched:*'         # 调度事件
perf list 'block:*'         # 块设备事件
```

**记录和分析**:
```bash
# 记录事件
perf record -e 'event_name' command

# 查看报告
perf report

# 查看详细脚本
perf script
```

### 2. 系统信息查看

**CPU 信息**:
```bash
lscpu                        # CPU 架构信息
cat /proc/cpuinfo           # 详细 CPU 信息
nproc                       # CPU 核心数
```

**内存信息**:
```bash
free -h                     # 内存使用情况
cat /proc/meminfo          # 详细内存信息
```

**网卡信息**:
```bash
ip link show               # 网络接口列表
ethtool eth0               # 网卡详细信息
cat /proc/net/dev          # 网络统计
```

**磁盘信息**:
```bash
lsblk                      # 块设备列表
df -h                      # 磁盘使用情况
iostat -x 1                # I/O 统计（需要 sysstat 包）
```

### 3. 实时监控

**网络流量**:
```bash
iftop                      # 实时网络流量
nethogs                    # 按进程显示网络使用
ss -s                      # socket 统计
```

**进程监控**:
```bash
top                        # 传统进程监控
htop                       # 增强版进程监控
atop                       # 全面的系统监控
```

**I/O 监控**:
```bash
iotop                      # 按进程显示 I/O
iostat -x 1                # I/O 统计
```

---

## 最佳实践

### 1. 测试前准备

- 确保系统相对空闲（减少干扰）
- 了解系统基线性能
- 记录系统配置（CPU、内存、网卡型号等）

### 2. 测试过程

- 多次运行取平均值
- 排除异常值
- 记录所有相关参数
- 保存原始数据

### 3. 结果分析

- 对比不同场景的数据
- 识别性能瓶颈
- 验证优化效果
- 文档化发现

### 4. 安全注意事项

- 不要在生产环境直接测试
- 某些命令需要 root 权限
- 注意磁盘空间（perf 记录文件可能很大）
- 清理测试文件

---

## 参考资源

- [Perf Wiki](https://perf.wiki.kernel.org/)
- [Brendan Gregg's Perf Examples](http://www.brendangregg.com/perf.html)
- [Packetdrill GitHub](https://github.com/google/packetdrill)
- [Linux Performance](http://www.brendangregg.com/linuxperf.html)

---

**创建日期**: 2026-04-18
**最后更新**: 2026-04-18
