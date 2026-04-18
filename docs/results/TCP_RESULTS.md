# TCP协议栈测试结果解析 (Packetdrill)

## 概述

本文档详细解释 Packetdrill TCP 测试的输出结果，帮助你理解TCP协议实现和排查协议问题。

---

## 测试文件位置

```
results/tcp/
├── basic_tcp_TIMESTAMP.txt    # 基本TCP测试结果
├── ...其他测试结果...
└── report_TIMESTAMP.txt        # 测试报告
```

---

## 1. Packetdrill 测试成功示例

### 测试脚本

```bash
// TCP 三次握手测试
0.000 socket(..., SOCK_STREAM, IPPROTO_TCP) = 3
0.000 setsockopt(3, SOL_SOCKET, SO_REUSEADDR, [1], 4) = 0
0.000 bind(3, ..., ...) = 0
0.000 listen(3, 1) = 0

// 客户端发送 SYN
0.100 < S 0:0(0) win 65535 <mss 1460,sackOK,nop,nop,nop,wscale 7>

// 服务器回复 SYN-ACK
0.100 > S. 0:0(0) ack 1 win 65535 <mss 1460,nop,nop,sackOK,nop,wscale 7>

// 客户端发送 ACK
0.200 < . 1:1(0) ack 1 win 65535
0.200 accept(3, ..., ...) = 4

// 数据传输
0.300 write(4, ..., 1000) = 1000
0.300 > P. 1:1001(1000) ack 1 win 65535
```

### 成功输出

```bash
./packetdrill basic_tcp.pkt
(无输出)
```

**关键**: 无输出 = 测试通过

**验证**:
```bash
echo $?
0  ← 退出码为 0 表示成功
```

---

## 2. Packetdrill 测试失败示例

### 失败场景1: TCP选项顺序不匹配

#### 错误输出

```
test.pkt:10: error handling packet: bad outbound TCP options
script packet:  0.100000 S. 0:0(0) ack 1 win 65535 <mss 1460,sackOK,nop,nop,nop,wscale 7>
actual packet:  0.100085 S. 0:0(0) ack 1 win 65535 <mss 1460,nop,nop,sackOK,nop,wscale 7>
```

#### 错误解析

**错误位置**: 第10行

**错误类型**: `bad outbound TCP options`

**期望 vs 实际**:
```
期望: <mss 1460,sackOK,nop,nop,nop,wscale 7>
实际: <mss 1460,nop,nop,sackOK,nop,wscale 7>
          期望选项顺序    ↑
                         实际内核返回的顺序
```

**原因**:
- 不同内核版本可能使用不同的TCP选项顺序
- 内核会标准化TCP选项的排列

**解决方法**:
```bash
# 修改测试脚本，使用实际的选项顺序
0.100 > S. 0:0(0) ack 1 win 65535 <mss 1460,nop,nop,sackOK,nop,wscale 7>
#                                              ↑
#                                    修改为实际顺序
```

### 失败场景2: 窗口大小不匹配

#### 错误输出

```
test.pkt:10: error handling packet: live packet field tcp_window: expected: 65535 (0xffff) vs actual: 64800 (0xfd20)
script packet:  0.100000 S. 0:0(0) ack 1 win 65535 <...>
actual packet:  0.100083 S. 0:0(0) ack 1 win 64800 <...>
```

#### 错误解析

**字段**: `tcp_window`

**期望 vs 实际**:
```
期望: 65535 (0xffff)  ← 脚本中定义的窗口大小
实际: 64800 (0xfd20)  ← 内核实际使用的窗口大小
```

**原因**:
- 内核根据系统参数动态计算窗口大小
- 受限于缓冲区大小配置

**系统窗口大小配置**:
```bash
# 查看接收缓冲区大小
sysctl net.ipv4.tcp_rmem
# net.ipv4.tcp_rmem = 4096 131072 6291456
#                      最小  默认   最大

# 查看发送缓冲区大小
sysctl net.ipv4.tcp_wmem
```

**解决方法**:
```bash
# 1. 修改脚本使用实际值
0.100 > S. 0:0(0) ack 1 win 64800 <...>

# 2. 或者调整系统参数
sysctl -w net.ipv4.tcp_rmem="4096 131072 8388608"
```

### 失败场景3: 序列号不匹配

#### 错误输出

```
test.pkt:12: error handling packet: bad outbound TCP sequence number
script packet:  0.200000 . 1:1(0) ack 1 win 65535
actual packet:  0.200015 . 1:1(0) ack 2 win 65535
#                                    ↑
#                                 期望ack=1, 实际ack=2
```

#### 错误解析

**原因**:
- SYN 包消耗一个序列号
- ACK 号应该是对方序列号+1

**TCP序列号规则**:
```
SYN:      seq=X,       消耗1个序列号
SYN-ACK:  seq=Y, ack=X+1, 消耗1个序列号
ACK:      seq=X+1, ack=Y+1, 不消耗序列号
```

**示例**:
```
客户端: SYN seq=0           → 消耗seq 0
服务器: SYN-ACK seq=0, ack=1  → 消耗seq 0
客户端: ACK seq=1, ack=1      → ack应该是1 (服务器的seq=0, +1=1)
```

### 失败场景4: 时间戳不匹配

#### 错误输出

```
test.pkt:15: error handling packet: timing error: expected packet at 0.300 but received at 0.325
```

**原因**: 系统负载高，导致时序偏差

**解决**:
```bash
# 增加时间容差
# packetdrill支持一定的时间偏差（通常±10ms）

# 或调整时间戳
0.325 > P. 1:1001(1000) ack 1  # 使用实际观察到的时间
```

---

## 3. Packetdrill 语法详解

### 时间戳格式

```
0.000  ← 测试开始
0.100  ← 100毫秒后
0.200  ← 200毫秒后
```

**相对时间**: 所有时间戳都是相对测试开始的时间

### 方向符号

```
<  ← 注入数据包（模拟接收，输入方向）
>  ← 验证数据包（期望发送，输出方向）
```

**示例**:
```
0.100 < S ...      # 在0.100秒时，注入一个SYN包（模拟客户端发送）
0.100 > S. ...     # 期望在0.100秒时，发送一个SYN-ACK包（验证服务器响应）
```

### TCP标志

```
S   ← SYN（同步）
.   ← ACK（确认）
P   ← PSH（推送）
F   ← FIN（结束）
R   ← RST（重置）
```

**组合使用**:
```
S.  ← SYN + ACK (SYN-ACK包)
P.  ← PSH + ACK
F.  ← FIN + ACK
```

### 序列号格式

```
0:0(0)
│ │ │
│ │ └─ 数据长度
│ └─── 结束序列号
└───── 起始序列号
```

**示例**:
```
0:0(0)        ← seq=0, 无数据
1:1001(1000)  ← seq=1, 1000字节数据, 结束seq=1001
```

**计算规则**:
```
结束序列号 = 起始序列号 + 数据长度 + 标志消耗
SYN/FIN 各消耗 1 个序列号
```

### TCP选项格式

```
<mss 1460,sackOK,nop,nop,nop,wscale 7>
```

**常见选项**:
| 选项 | 含义 | 值示例 |
|------|------|--------|
| mss | 最大报文段大小 | 1460 (以太网1500-40) |
| sackOK | 支持选择性确认 | 无参数 |
| nop | 填充（对齐） | 无参数 |
| wscale | 窗口扩大因子 | 7 (实际窗口 = win × 2^7) |
| timestamp | 时间戳 | val 12345 ecr 0 |

**选项顺序**:
- 不同内核可能使用不同顺序
- 常见顺序: `mss, nop×N, sackOK, nop×N, wscale`
- **关键**: 使用实际内核返回的顺序

### 窗口大小

```
win 65535
```

**窗口缩放**:
```
声明窗口: win 65535
窗口扩大: wscale 7
实际窗口 = 65535 × 2^7 = 8388480 字节 ≈ 8MB
```

---

## 4. TCP三次握手详解

### 完整过程

```
客户端                          服务器
   │                              │
   │  (1) SYN seq=0               │
   │─────────────────────────────>│  0.100s
   │                              │
   │  (2) SYN-ACK seq=0, ack=1    │
   │<─────────────────────────────│  0.100s
   │                              │
   │  (3) ACK seq=1, ack=1        │
   │─────────────────────────────>│  0.200s
   │                              │
   │  [连接建立]                   │
```

### Packetdrill 脚本

```bash
# (1) 客户端发送 SYN
0.100 < S 0:0(0) win 65535 <mss 1460,sackOK,nop,nop,nop,wscale 7>
#     ↑ ↑ ↑
#     │ │ └─ SYN包，seq=0，无数据
#     │ └─── 客户端窗口大小
#     └───── 注入（模拟接收）

# (2) 服务器回复 SYN-ACK
0.100 > S. 0:0(0) ack 1 win 65535 <mss 1460,nop,nop,sackOK,nop,wscale 7>
#     ↑ ↑  ↑       ↑
#     │ │  │       └─ ack=1 (确认客户端的seq=0)
#     │ │  └─────── SYN-ACK包，服务器seq=0
#     │ └────────── 发送（验证）
#     └──────────── 同一时刻（内核立即响应）

# (3) 客户端发送 ACK
0.200 < . 1:1(0) ack 1 win 65535
#     ↑ ↑ ↑      ↑
#     │ │ │      └─ ack=1 (确认服务器的seq=0)
#     │ │ └─────── seq=1 (SYN消耗了seq 0)
#     │ └───────── ACK包
#     └─────────── 100ms后
```

### 序列号追踪

```
阶段   方向  标志   seq   ack   seq消耗
(1)    C→S   SYN    0     -     1 (SYN消耗)
(2)    S→C   SYN-ACK 0    1     1 (SYN消耗)
(3)    C→S   ACK    1     1     0 (ACK不消耗)

下次数据传输:
(4)    S→C   PSH-ACK 1   1     1000 (1000字节数据)
```

---

## 5. 数据传输测试

### 测试脚本

```bash
// 服务器发送1000字节数据
0.300 write(4, ..., 1000) = 1000
0.300 > P. 1:1001(1000) ack 1 win 65535
#      ↑ ↑  ↑
#      │ │  └─ seq=1, 发送1000字节, 结束seq=1001
#      │ └──── PSH-ACK (推送+确认)
#      └────── 验证发送

// 客户端确认收到
0.400 < . 1:1(0) ack 1001 win 65535
#           ↑         ↑
#           │         └─ ack=1001 (确认收到seq 1-1000)
#           └─────────── 客户端seq还是1 (没发数据)
```

### 分段传输

```bash
// 发送3000字节，分3个包
0.300 write(4, ..., 3000) = 3000

// 第1个包 (MSS=1460)
0.300 > . 1:1461(1460) ack 1 win 65535

// 第2个包
0.301 > . 1461:2921(1460) ack 1 win 65535

// 第3个包 (剩余80字节)
0.302 > P. 2921:3001(80) ack 1 win 65535
#      ↑ 最后一个包才设置PSH标志
```

---

## 6. 常见测试场景

### 窗口扩展 (Window Scaling)

```bash
// 测试大窗口
0.100 < S 0:0(0) win 65535 <mss 1460,wscale 8>
0.100 > S. 0:0(0) ack 1 win 65535 <mss 1460,wscale 7>
#                                              ↑
#                                         实际窗口 = 65535 × 2^7 = 8MB
```

### 选择性确认 (SACK)

```bash
// 启用SACK
0.100 < S 0:0(0) win 65535 <mss 1460,sackOK>
0.100 > S. 0:0(0) ack 1 win 65535 <mss 1460,sackOK>

// 模拟丢包，使用SACK
0.300 < . 1:1461(1460) ack 1 win 65535        # 包1
0.300 < . 2921:4381(1460) ack 1 win 65535     # 包3 (包2丢失)

// 服务器SACK响应
0.300 > . 1:1(0) ack 1461 win 65535 <sack 2921:4381>
#                                           ↑
#                                    确认收到2921-4381
#                                    但1461-2921缺失
```

### 连接关闭 (四次挥手)

```bash
// 客户端主动关闭
0.500 < F. 1:1(0) ack 1001 win 65535    # (1) 客户端FIN
0.500 > . 1001:1001(0) ack 2 win 65535  # (2) 服务器ACK

// 服务器关闭
0.600 close(4) = 0
0.600 > F. 1001:1001(0) ack 2 win 65535 # (3) 服务器FIN
0.700 < . 2:2(0) ack 1002 win 65535     # (4) 客户端ACK
```

---

## 7. 调试技巧

### 使用 --verbose 查看详细信息

```bash
./packetdrill --verbose test.pkt

输出:
outbound packet:  0.100000 S. 0:0(0) ack 1 win 65535 <mss 1460,...>
outbound tcp header:
  source port: 8080
  dest port: 55555
  seq: 0
  ack: 1
  flags: SYN ACK
  window: 65535
  ...
```

### 使用 --debug 查看更多细节

```bash
./packetdrill --debug test.pkt

# 输出:
# - 系统调用追踪
# - 内核事件
# - 数据包hex dump
```

### 抓包对比

```bash
# 同时抓包
tcpdump -i any -w capture.pcap port 8080 &

# 运行测试
./packetdrill test.pkt

# 分析抓包
tcpdump -r capture.pcap -nn -v
```

---

## 8. 测试报告解析

### 成功报告示例

```
TCP 协议栈测试报告
==================
测试时间: 2026-04-18 10:30:00
主机名: test-server

## 测试统计

总测试数: 5
通过: 5
失败: 0
成功率: 100.0%

## 测试详情

### basic_tcp.pkt
状态: ✓ 通过

### window_scaling.pkt
状态: ✓ 通过

### sack.pkt
状态: ✓ 通过

## 系统信息

内核版本: 5.15.0-1234-generic
系统: Linux
```

### 失败报告示例

```
## 测试详情

### basic_tcp.pkt
状态: ✗ 失败

错误信息:
```
test.pkt:10: error handling packet: bad outbound TCP options
script packet:  0.100000 S. 0:0(0) ack 1 win 65535 <mss 1460,sackOK,nop,nop,nop,wscale 7>
actual packet:  0.100085 S. 0:0(0) ack 1 win 65535 <mss 1460,nop,nop,sackOK,nop,wscale 7>
```

**诊断**: TCP选项顺序不匹配，需要更新测试脚本使用内核实际顺序。
```

---

## 9. 常见问题解决

### Q: 如何确定正确的TCP选项顺序？

**A**: 使用 `--verbose` 运行测试，查看实际输出
```bash
./packetdrill --verbose test.pkt 2>&1 | grep "actual packet"
```

### Q: 窗口大小总是不匹配

**A**: 检查系统TCP缓冲区配置
```bash
# 查看当前配置
sysctl net.ipv4.tcp_rmem
sysctl net.ipv4.tcp_wmem

# 调整或在测试中使用实际值
```

### Q: 时间戳经常偏差

**A**: 系统负载影响，可以：
1. 在空闲系统上测试
2. 增加时间容差
3. 使用相对时间而非绝对匹配

### Q: 如何测试重传？

**A**: 示例脚本
```bash
// 发送数据
0.100 > . 1:1001(1000) ack 1 win 65535

// 不发送ACK（模拟丢包）
// 等待重传超时（RTO约1秒）

// 验证重传
1.200 > . 1:1001(1000) ack 1 win 65535
```

---

## 10. 进阶测试场景

### 拥塞控制测试

```bash
// 测试慢启动
// 第1个RTT: 1个MSS
0.100 > . 1:1461(1460) ack 1
// 收到ACK
0.200 < . 1:1(0) ack 1461

// 第2个RTT: 2个MSS (窗口翻倍)
0.200 > . 1461:2921(1460) ack 1
0.201 > . 2921:4381(1460) ack 1
```

### 快速重传测试

```bash
// 发送4个包
0.100 > . 1:1461(1460) ack 1
0.101 > . 1461:2921(1460) ack 1     # 丢失
0.102 > . 2921:4381(1460) ack 1
0.103 > . 4381:5841(1460) ack 1

// 收到3个重复ACK
0.200 < . 1:1(0) ack 1461
0.201 < . 1:1(0) ack 1461           # dup 1
0.202 < . 1:1(0) ack 1461           # dup 2
0.203 < . 1:1(0) ack 1461           # dup 3

// 触发快速重传
0.203 > . 1461:2921(1460) ack 1     # 重传丢失的包
```

---

## 总结

Packetdrill TCP测试结果解读的关键点：

1. **无输出 = 成功** - 静默表示通过
2. **序列号追踪** - 理解seq/ack的变化
3. **选项顺序** - 使用实际内核返回的顺序
4. **时间戳** - 相对时间，允许一定偏差
5. **标志组合** - S/F/P/.的正确使用

通过系统的测试，可以：
- ✅ 验证TCP协议实现
- ✅ 发现内核Bug
- ✅ 测试新特性
- ✅ 回归测试

---

**相关文档**:
- [网络测试结果解析](NETWORK_RESULTS.md)
- [调度测试结果解析](SCHED_RESULTS.md)
- [块设备测试结果解析](BLOCK_RESULTS.md)
- [Packetdrill GitHub](https://github.com/google/packetdrill)
