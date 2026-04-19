# qperf 结果解读指南

本文档提供qperf测试结果的详细解读，帮助理解Socket和RDMA性能数据并识别性能瓶颈。

## 典型测试输出示例

### TCP带宽测试（tcp_bw）

```
tcp_bw:
    bw              =  117 MB/sec        ← 关键指标: 带宽
    msg_rate        =  1.79 K/sec
    send_cost       =  682 ms/GB
    recv_cost       =  682 ms/GB
    send_cpus_used  =  8 % cpus          ← 发送端CPU使用率
    recv_cpus_used  =  8 % cpus          ← 接收端CPU使用率
```

**关键指标解读:**

| 字段 | 说明 | 重要性 |
|------|------|--------|
| **bw** | **带宽（MB/sec）** | ★★★★★ 核心指标 |
| msg_rate | 消息速率（K/sec） | ★★☆☆☆ 参考信息 |
| send_cost | 发送开销（ms/GB） | ★★★☆☆ 效率指标 |
| recv_cost | 接收开销（ms/GB） | ★★★☆☆ 效率指标 |
| **send_cpus_used** | **发送端CPU使用率** | ★★★★☆ 资源指标 |
| **recv_cpus_used** | **接收端CPU使用率** | ★★★★☆ 资源指标 |

**性能等级划分:**

| 带宽(MB/s) | 性能等级 | 星级 | 网络类型 |
|-----------|---------|------|---------|
| ≥ 10000 | 卓越 | ★★★★★ | 100GbE |
| ≥ 1000 | 优秀 | ★★★★☆ | 10GbE线速 |
| ≥ 100 | 良好 | ★★★☆☆ | 1GbE线速 |
| ≥ 50 | 一般 | ★★☆☆☆ | 1GbE部分带宽 |
| ≥ 10 | 较低 | ★☆☆☆☆ | 100Mbps |
| < 10 | 很低 | ☆☆☆☆☆ | 受限或拥塞 |

**单位换算:**
```
1 MB/sec = 8 Mbps
117 MB/sec = 936 Mbps (接近1GbE线速)
```

### TCP延迟测试（tcp_lat）

```
tcp_lat:
    latency         =  43.2 us           ← 关键指标: 延迟
    msg_rate        =  23.1 K/sec
    loc_cpus_used   =  100 % cpus        ← 本地CPU使用率
    rem_cpus_used   =  100 % cpus        ← 远程CPU使用率
```

**关键指标解读:**

| 字段 | 说明 | 重要性 |
|------|------|--------|
| **latency** | **往返延迟（μs）** | ★★★★★ 核心指标 |
| msg_rate | 消息速率（K/sec） | ★★★☆☆ 吞吐量 |
| loc_cpus_used | 本地CPU使用率 | ★★★★☆ 资源消耗 |
| rem_cpus_used | 远程CPU使用率 | ★★★★☆ 资源消耗 |

**延迟性能等级:**

| 延迟 | 性能等级 | 星级 | 应用场景 |
|------|---------|------|---------|
| < 10 μs | 卓越 | ★★★★★ | 内存数据库、超低延迟交易 |
| 10-50 μs | 优秀 | ★★★★☆ | 本地网络、Redis缓存 |
| 50-200 μs | 良好 | ★★★☆☆ | 1GbE网络、MySQL查询 |
| 200-1000 μs | 一般 | ★★☆☆☆ | 常规应用 |
| 1-10 ms | 较低 | ★☆☆☆☆ | 高延迟网络 |
| > 10 ms | 很低 | ☆☆☆☆☆ | 广域网 |

**延迟与吞吐量关系:**
```
消息速率 = 1,000,000 / 延迟(μs)

示例:
  延迟 = 43.2 μs
  理论消息速率 = 1,000,000 / 43.2 ≈ 23,148 msg/s ≈ 23.1 K/sec
```

### UDP带宽测试（udp_bw）

```
udp_bw:
    send_bw         =  119 MB/sec        ← 发送带宽
    recv_bw         =  119 MB/sec        ← 接收带宽
    msg_rate        =  7.66 K/sec
    send_cpus_used  =  7.52 % cpus
    recv_cpus_used  =  12.5 % cpus
```

**关键指标解读:**

| 字段 | 说明 | 注意事项 |
|------|------|---------|
| send_bw | 发送端带宽 | 发送能力 |
| recv_bw | 接收端带宽 | 实际吞吐 |
| 带宽差异 | send_bw - recv_bw | 丢包指示器 |

**丢包率估算:**
```
丢包率 ≈ (send_bw - recv_bw) / send_bw × 100%

示例:
  send_bw = 119 MB/sec
  recv_bw = 115 MB/sec
  丢包率 ≈ (119 - 115) / 119 × 100% ≈ 3.4%
```

**丢包率评估标准:**

| 丢包率 | 评级 | 应用影响 |
|--------|------|---------|
| < 0.01% | ★★★★★ 优秀 | 视频会议完美 |
| 0.01-0.1% | ★★★★☆ 良好 | 大部分应用可接受 |
| 0.1-1% | ★★★☆☆ 一般 | 实时应用受影响 |
| 1-5% | ★★☆☆☆ 较差 | 明显质量下降 |
| > 5% | ★☆☆☆☆ 很差 | 不可用 |

### RDMA RC带宽测试（rc_bw）

```
rc_bw:
    bw              =  11800 MB/sec      ← 惊人的带宽!
    msg_rate        =  180 K/sec
    send_cost       =  6.78 ms/GB        ← 极低的CPU开销
    recv_cost       =  6.78 ms/GB
    send_cpus_used  =  8 % cpus          ← CPU使用率低
    recv_cpus_used  =  8 % cpus
```

**RDMA性能优势:**

| 指标 | TCP | RDMA RC | 提升倍数 |
|------|-----|---------|---------|
| 带宽 | 117 MB/s | 11800 MB/s | **100x** |
| CPU开销 | 682 ms/GB | 6.78 ms/GB | **100x降低** |
| 延迟 | 43 μs | 1-2 μs | **20-40x降低** |

**RDMA性能等级:**

| 带宽(MB/s) | 性能等级 | 星级 | RDMA类型 |
|-----------|---------|------|---------|
| ≥ 10000 | 卓越 | ★★★★★ | InfiniBand FDR/EDR |
| ≥ 5000 | 优秀 | ★★★★☆ | InfiniBand QDR |
| ≥ 2000 | 良好 | ★★★☆☆ | RoCE v2 |
| ≥ 1000 | 一般 | ★★☆☆☆ | iWARP |
| < 1000 | 较低 | ★☆☆☆☆ | 受限或配置问题 |

### RDMA RC延迟测试（rc_lat）

```
rc_lat:
    latency         =  1.52 us           ← 超低延迟!
    msg_rate        =  658 K/sec         ← 极高消息速率
    loc_cpus_used   =  100 % cpus
    rem_cpus_used   =  100 % cpus
```

**RDMA延迟性能等级:**

| 延迟 | 性能等级 | 星级 | 应用场景 |
|------|---------|------|---------|
| < 1 μs | 卓越 | ★★★★★ | 高频交易、实时仿真 |
| 1-2 μs | 优秀 | ★★★★☆ | 分布式内存数据库 |
| 2-5 μs | 良好 | ★★★☆☆ | 高性能计算(HPC) |
| 5-10 μs | 一般 | ★★☆☆☆ | 存储网络 |
| > 10 μs | 较低 | ★☆☆☆☆ | 配置问题 |

## 测试类型详细解读

### 1. TCP_BW - TCP带宽测试

**测试原理:**
```
发送端                        接收端
  │                            │
  │──── 大数据块(持续) ───────>│
  │──── 大数据块(持续) ───────>│
  │──── 大数据块(持续) ───────>│
  │                            │
  └─测量: 吞吐量(MB/sec)
  └─统计: CPU使用率(%)
```

**应用场景:**
- 大文件传输（FTP、rsync）
- 数据备份和恢复
- 视频流传输
- 云存储上传下载

**影响因素分析:**

1. **TCP窗口大小**
   ```
   最大吞吐量 = TCP窗口 / RTT

   示例:
     窗口 = 128KB
     RTT = 1ms
     最大吞吐 = 131,072 × 8 / 0.001 = 1,049 Mbps
   ```

2. **网络MTU**
   ```
   MTU越大，协议开销越小

   1500字节MTU: TCP有效载荷 = 1500 - 40 = 1460字节
   9000字节MTU: TCP有效载荷 = 9000 - 40 = 8960字节
   ```

3. **CPU性能**
   ```bash
   # 检查CPU是否成为瓶颈
   # send_cpus_used 或 recv_cpus_used > 90% → CPU瓶颈
   ```

**优化建议:**
```bash
# 1. 增大TCP缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# 2. 启用TCP窗口缩放
sysctl -w net.ipv4.tcp_window_scaling=1

# 3. 使用BBR拥塞控制
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 4. 启用网卡offload
ethtool -K eth0 tso on gso on gro on
```

### 2. TCP_LAT - TCP延迟测试

**测试原理:**
```
客户端                        服务器
  │                            │
  │────── 请求(小消息) ──────>│
  │<───── 响应(小消息) ──────│
  │                            │
  │────── 请求(小消息) ──────>│
  │<───── 响应(小消息) ──────│
  │         (重复)             │
  │                            │
  └─测量: 平均延迟(μs)
  └─计算: 消息速率(msg/sec)
```

**应用场景:**
- 数据库查询（SELECT操作）
- 缓存访问（Redis GET/SET）
- RESTful API调用
- 微服务RPC调用

**延迟组成分析:**
```
总延迟 = 网络传输延迟 + 协议处理延迟 + 应用处理延迟

其中:
  网络传输延迟 = 物理距离 / 光速 × 2 (往返)
  协议处理延迟 = TCP栈处理 + 内核调度
  应用处理延迟 = qperf服务端响应时间
```

**典型延迟值:**

| 场景 | 典型延迟 | 说明 |
|------|---------|------|
| 本地loopback | 5-20 μs | 无物理网络 |
| 同机房1GbE | 30-100 μs | 低延迟网络 |
| 同机房10GbE | 10-50 μs | 更低延迟 |
| 同城10km光纤 | 100-500 μs | 光纤传输延迟 |
| 跨城100km | 1-3 ms | 距离影响 |

**优化建议:**
```bash
# 1. 禁用Nagle算法（应用层）
setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag));

# 2. 减小中断合并延迟
ethtool -C eth0 rx-usecs 0

# 3. 使用低延迟内核
# 安装realtime或lowlatency内核

# 4. CPU性能模式
cpupower frequency-set -g performance
```

### 3. UDP_BW - UDP带宽测试

**测试原理:**
```
发送端                        接收端
  │                            │
  │═══ UDP数据报 ═══════════>│
  │═══ UDP数据报 ═══════════>│
  │═══ UDP数据报 ═══════════>│
  │   (无连接，无确认)          │
  │                            │
  └─测量: 发送带宽 vs 接收带宽
  └─计算: 丢包率
```

**应用场景:**
- 视频直播（RTMP/HLS）
- VoIP电话（SIP/RTP）
- 在线游戏
- DNS查询
- 日志传输（syslog）

**丢包原因分析:**

1. **接收缓冲区溢出**
   ```bash
   # 查看UDP接收错误
   netstat -su | grep "receive buffer errors"

   # 如果数值很高，增大缓冲区
   sysctl -w net.core.rmem_max=134217728
   sysctl -w net.core.rmem_default=33554432
   ```

2. **发送速率过快**
   ```
   发送带宽 > 链路容量 → 必然丢包

   示例:
     发送 = 150 MB/s
     链路 = 1GbE = 125 MB/s
     必然丢包
   ```

3. **网络拥塞**
   ```bash
   # 检查网络路径
   mtr -r -c 100 [目标IP]
   ```

**优化建议:**
```bash
# 1. 增大UDP接收缓冲区
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.rmem_default=33554432

# 2. 增加网络队列长度
sysctl -w net.core.netdev_max_backlog=10000

# 3. 使用多队列网卡
ethtool -L eth0 combined 8
```

### 4. RDMA RC_BW - RDMA可靠连接带宽

**测试原理:**
```
RDMA发送端                    RDMA接收端
  │                            │
  │                            │
  │════ 零拷贝RDMA传输 ═══════>│
  │     (绕过内核)              │
  │     (DMA直接访问内存)        │
  │                            │
  └─测量: 极高带宽 + 极低CPU
```

**RDMA优势:**

1. **零拷贝(Zero-Copy)**
   ```
   传统TCP:
     应用 → 用户空间缓冲区 → 内核缓冲区 → 网卡
     (多次内存拷贝)

   RDMA:
     应用 → 网卡
     (直接DMA，零拷贝)
   ```

2. **内核旁路(Kernel Bypass)**
   ```
   传统TCP: 需要经过内核协议栈
   RDMA: 绕过内核，用户空间直接访问网卡
   ```

3. **CPU卸载(CPU Offload)**
   ```
   传统TCP: CPU处理协议栈
   RDMA: 网卡硬件处理，CPU几乎无负载
   ```

**RDMA传输类型对比:**

| 类型 | 全称 | 特性 | 带宽 | 延迟 | 应用 |
|------|------|------|------|------|------|
| **RC** | Reliable Connection | 可靠、有序 | 最高 | 低 | 存储、数据库 |
| **UC** | Unreliable Connection | 不可靠、有序 | 高 | 极低 | HPC |
| **UD** | Unreliable Datagram | 不可靠、无序 | 中 | 最低 | 组播、发现 |

**RDMA网络技术对比:**

| 技术 | 物理层 | 带宽 | 延迟 | 成本 | 部署 |
|------|--------|------|------|------|------|
| **InfiniBand** | 专用 | 200-400 Gbps | < 1 μs | 高 | HPC |
| **RoCE v2** | 以太网 | 100-200 Gbps | 1-2 μs | 中 | 数据中心 |
| **iWARP** | 以太网 | 40-100 Gbps | 2-5 μs | 中 | 企业网 |

### 5. RDMA RC_LAT - RDMA延迟测试

**测试原理:**
```
RDMA客户端                    RDMA服务端
  │                            │
  │────── RDMA Write ────────>│
  │         (零拷贝)            │
  │<───── 完成通知 ──────────│
  │         (硬件)             │
  │                            │
  └─测量: 亚微秒级延迟
```

**RDMA延迟优势:**
```
TCP延迟:     30-100 μs
RDMA延迟:    1-2 μs

降低: 15-100倍
```

**超低延迟应用:**
- 高频交易（HFT）
- 实时仿真
- 分布式内存数据库（RAMCloud）
- 低延迟消息队列

## 性能对比分析

### Socket vs RDMA性能对比

**带宽对比:**

| 测试类型 | TCP | UDP | RDMA RC | RDMA提升 |
|---------|-----|-----|---------|---------|
| 本地环回 | 5-10 GB/s | 3-8 GB/s | 10-20 GB/s | 2-4x |
| 1GbE | 117 MB/s | 117 MB/s | N/A | - |
| 10GbE | 1170 MB/s | 1170 MB/s | 1200 MB/s | 1.03x |
| 100GbE | 11700 MB/s | 11700 MB/s | 12000 MB/s | 1.03x |
| InfiniBand FDR | - | - | 6500 MB/s | - |
| InfiniBand EDR | - | - | 12500 MB/s | - |

**延迟对比:**

| 测试类型 | TCP | UDP | RDMA RC | RDMA降低 |
|---------|-----|-----|---------|---------|
| 本地环回 | 5-20 μs | 3-15 μs | 0.5-2 μs | 3-40x |
| 同机房1GbE | 30-100 μs | 20-80 μs | N/A | - |
| 同机房10GbE | 10-50 μs | 8-40 μs | N/A | - |
| InfiniBand | - | - | 0.5-1.5 μs | - |

**CPU使用率对比:**

| 测试类型 | TCP | UDP | RDMA RC | CPU节省 |
|---------|-----|-----|---------|---------|
| 1GbE满载 | 15-25% | 10-20% | N/A | - |
| 10GbE满载 | 50-80% | 40-70% | 5-15% | 5-15x |
| 100GbE满载 | 100%+ | 100%+ | 10-30% | 3-10x |

### TCP vs UDP vs SCTP对比

**协议特性对比:**

| 特性 | TCP | UDP | SCTP |
|------|-----|-----|------|
| 连接 | 面向连接 | 无连接 | 面向连接 |
| 可靠性 | 可靠 | 不可靠 | 可靠 |
| 有序性 | 有序 | 无序 | 有序 |
| 消息边界 | 字节流 | 保留 | 保留 |
| 多流 | 不支持 | 不支持 | **支持** |
| 多宿主 | 不支持 | 不支持 | **支持** |

**性能对比:**

| 指标 | TCP | UDP | SCTP |
|------|-----|-----|------|
| 带宽 | 100% | 102% | 98% |
| 延迟 | 100% | 80% | 105% |
| CPU | 100% | 70% | 110% |

**应用场景选择:**

| 场景 | 推荐协议 | 原因 |
|------|---------|------|
| 文件传输 | TCP | 可靠性 |
| 视频直播 | UDP | 低延迟 |
| VoIP | UDP | 实时性 |
| 电信信令 | SCTP | 多流、可靠 |
| 数据库复制 | TCP | 顺序保证 |
| 游戏 | UDP | 低延迟 |
| HTTP | TCP | 可靠性 |
| DNS | UDP | 简单快速 |

## CPU使用率分析

### CPU使用率含义

**qperf CPU使用率字段:**
```
send_cpus_used  =  8 % cpus    ← 发送端CPU使用率
recv_cpus_used  =  8 % cpus    ← 接收端CPU使用率
loc_cpus_used   =  100 % cpus  ← 本地CPU使用率（延迟测试）
rem_cpus_used   =  100 % cpus  ← 远程CPU使用率（延迟测试）
```

**注意:**
- 带宽测试显示 `send_cpus_used` 和 `recv_cpus_used`
- 延迟测试显示 `loc_cpus_used` 和 `rem_cpus_used`，通常是100%（单线程ping-pong）

### CPU效率计算

**带宽效率（Bandwidth per CPU）:**
```
效率 = 带宽(MB/s) / CPU使用率(%)

示例:
  带宽 = 117 MB/s
  CPU = 8%
  效率 = 117 / 8 = 14.625 MB/s per %CPU
```

**效率等级:**

| 效率(MB/s per %CPU) | 评级 | 说明 |
|-------------------|------|------|
| > 50 | ★★★★★ 卓越 | RDMA级别 |
| 20-50 | ★★★★☆ 优秀 | 高效网卡offload |
| 10-20 | ★★★☆☆ 良好 | 标准配置 |
| 5-10 | ★★☆☆☆ 一般 | 需要优化 |
| < 5 | ★☆☆☆☆ 较低 | CPU瓶颈 |

### CPU瓶颈识别

**症状:**
```
CPU使用率 > 90% 但带宽未饱和

示例:
  10GbE网络（理论1250 MB/s）
  实际带宽: 600 MB/s
  CPU使用率: 95%

诊断: CPU成为瓶颈
```

**解决方案:**
```bash
# 1. 启用网卡offload
ethtool -K eth0 tso on gso on gro on

# 2. 增大消息大小（减少系统调用）
qperf <host> -oo msg_size:65536 tcp_bw

# 3. 使用多队列网卡
ethtool -L eth0 combined 8

# 4. CPU亲和性绑定
taskset -c 0-3 qperf <host> tcp_bw
```

## 消息大小影响分析

### 消息大小与性能关系

**典型测试结果:**

| 消息大小 | TCP带宽 | TCP延迟 | CPU使用率 | 效率 |
|---------|--------|---------|----------|------|
| 64 B | 15 MB/s | 12 μs | 90% | 0.17 |
| 256 B | 45 MB/s | 15 μs | 85% | 0.53 |
| 1 KB | 95 MB/s | 22 μs | 75% | 1.27 |
| 4 KB | 115 MB/s | 35 μs | 45% | 2.56 |
| 16 KB | 117 MB/s | 140 μs | 15% | 7.80 |
| 64 KB | 117 MB/s | 550 μs | 8% | 14.63 |

**规律总结:**
```
消息大小 ↑ →  带宽 ↑  (到达瓶颈后平台)
消息大小 ↑ →  延迟 ↑  (线性增长)
消息大小 ↑ →  CPU ↓   (系统调用减少)
消息大小 ↑ →  效率 ↑  (每%CPU处理更多数据)
```

### 最优消息大小选择

**应用场景指导:**

| 应用场景 | 推荐消息大小 | 原因 |
|---------|------------|------|
| 数据库查询 | 1-4 KB | 平衡延迟和吞吐 |
| 缓存访问 | 256 B - 1 KB | 低延迟优先 |
| 文件传输 | 64 KB+ | 最大化吞吐 |
| 视频流 | 8-16 KB | 平衡吞吐和延迟 |
| RPC调用 | 1-4 KB | 典型请求大小 |
| 实时游戏 | 64-256 B | 最低延迟 |

## 性能瓶颈诊断

### 症状1: 带宽远低于网络容量

**示例:**
```
1GbE网络，但TCP带宽只有30 MB/s (240 Mbps)
```

**诊断流程:**
```
┌─────────────────────┐
│ 带宽低于预期？        │
└──────────┬──────────┘
           ↓
    ┌─────────────┐
    │ 检查CPU使用  │ ← cpus_used > 90%?
    └──────┬──────┘
           ↓
    ┌─────────────┐
    │ 检查消息大小  │ ← msg_size太小?
    └──────┬──────┘
           ↓
    ┌─────────────┐
    │ 检查网络MTU  │ ← MTU是否最优?
    └──────┬──────┘
           ↓
    ┌─────────────┐
    │ 检查offload  │ ← TSO/GSO/GRO启用?
    └─────────────┘
```

**解决方案:**
```bash
# 1. 增大消息大小
qperf <host> -oo msg_size:65536 tcp_bw

# 2. 启用Jumbo Frames（如果支持）
ip link set eth0 mtu 9000

# 3. 启用网卡offload
ethtool -K eth0 tso on gso on gro on

# 4. 多流并发（模拟）
for i in {1..4}; do
    qperf <host> tcp_bw &
done
wait
```

### 症状2: 延迟高于预期

**示例:**
```
本地网络，但TCP延迟达到500 μs（预期<100 μs）
```

**可能原因:**

1. **Nagle算法延迟**
   ```
   小包会被延迟发送
   ```

2. **中断合并(Interrupt Coalescing)**
   ```bash
   # 检查中断合并设置
   ethtool -c eth0

   # rx-usecs太大会增加延迟
   ```

3. **CPU省电模式**
   ```bash
   # 检查CPU频率
   cpupower frequency-info

   # 切换到性能模式
   cpupower frequency-set -g performance
   ```

**解决方案:**
```bash
# 1. 减小中断合并延迟
ethtool -C eth0 rx-usecs 0

# 2. CPU性能模式
cpupower frequency-set -g performance

# 3. 禁用C-states
cpupower idle-set -D 2

# 4. 实时内核
# 安装lowlatency或realtime内核
```

### 症状3: RDMA性能不如预期

**示例:**
```
InfiniBand FDR，但rc_bw只有2000 MB/s（预期6500 MB/s）
```

**诊断步骤:**
```bash
# 1. 检查IB链路状态
ibstat

# 应该显示: State: Active
#          Physical state: LinkUp
#          Rate: 56 (FDR)

# 2. 检查IB子网管理器
ibstat | grep SM

# 应该有SM running

# 3. 检查RDMA设备
ibv_devinfo

# 4. 测试RDMA直接性能
ib_write_bw
ib_write_lat
```

**常见问题:**
```
1. IB链路未激活 → 检查物理连接和子网管理器
2. RDMA驱动未加载 → 加载mlx4/mlx5驱动
3. 防火墙阻止 → 配置防火墙规则
4. NUMA配置不当 → 绑定到本地NUMA节点
```

## 不同网络环境性能基准

### 本地环回(Loopback)

**预期性能:**
```
tcp_bw:     5-10 GB/s
tcp_lat:    5-20 μs
udp_bw:     3-8 GB/s
udp_lat:    3-15 μs
```

**特点:**
- 无物理网络限制
- 受CPU和内存带宽限制
- 用于协议栈性能基准测试

### 1GbE以太网

**预期性能:**
```
tcp_bw:     110-117 MB/s (880-936 Mbps)
tcp_lat:    30-100 μs
udp_bw:     110-117 MB/s
udp_lat:    20-80 μs
CPU:        5-15% (per Gbps)
```

**影响因素:**
- 交换机性能
- 网线质量（Cat5e vs Cat6）
- 网卡offload功能

### 10GbE以太网

**预期性能:**
```
tcp_bw:     1100-1170 MB/s (8.8-9.4 Gbps)
tcp_lat:    10-50 μs
udp_bw:     1100-1170 MB/s
udp_lat:    8-40 μs
CPU:        30-60% (per 10 Gbps)
```

**优化要点:**
- 必须启用多队列网卡
- CPU性能要足够
- 建议使用Jumbo Frames

### 100GbE以太网

**预期性能:**
```
tcp_bw:     11000-11700 MB/s (88-94 Gbps)
tcp_lat:    5-20 μs
udp_bw:     11000-11700 MB/s
udp_lat:    5-15 μs
CPU:        60-100% (per 100 Gbps)
```

**特殊要求:**
- 高性能CPU（Xeon Platinum等）
- NUMA优化
- 考虑DPDK或XDP

### InfiniBand FDR (56 Gbps)

**预期性能:**
```
rc_bw:      6000-6500 MB/s (48-52 Gbps)
rc_lat:     0.7-1.5 μs
uc_bw:      6000-6500 MB/s
ud_bw:      3000-4000 MB/s
CPU:        3-8% (per 50 Gbps)
```

**特点:**
- 极低延迟
- 极低CPU开销
- 适合HPC和存储

### InfiniBand EDR (100 Gbps)

**预期性能:**
```
rc_bw:      11500-12500 MB/s (92-100 Gbps)
rc_lat:     0.5-1.2 μs
CPU:        5-10% (per 100 Gbps)
```

**特点:**
- 顶级性能
- 用于超算和高性能存储

## 常见问题诊断

### Q1: 为什么UDP带宽低于TCP带宽？

**A: 可能原因:**

1. **UDP缓冲区不足**
   ```bash
   # 增大UDP缓冲区
   sysctl -w net.core.rmem_max=134217728
   sysctl -w net.core.rmem_default=33554432
   ```

2. **UDP丢包严重**
   ```bash
   # 检查丢包统计
   netstat -su | grep -i "receive errors"
   ```

3. **消息大小不合适**
   ```bash
   # 使用合适的消息大小
   qperf <host> -oo msg_size:1472 udp_bw
   ```

### Q2: 为什么本地环回性能不高？

**A: 环回受CPU和内存限制。**

```bash
# 优化环回性能
sysctl -w net.core.netdev_max_backlog=10000
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
```

### Q3: 如何验证RDMA是否正常工作？

**A: 使用IB工具验证。**

```bash
# 1. 检查IB设备
ibstat

# 2. 测试RDMA性能
ib_write_bw <server_ip>
ib_write_lat <server_ip>

# 3. 对比qperf结果
qperf <server_ip> rc_bw rc_lat

# RDMA正常工作的特征:
# - rc_bw > 5000 MB/s (FDR)
# - rc_lat < 2 μs
# - CPU < 10%
```

---

**更新日期:** 2026-04-19
**版本:** 1.0
