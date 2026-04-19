# iperf3 结果解读指南

本文档提供iperf3测试结果的详细解读，帮助理解网络性能数据并识别网络问题。

## 典型测试输出示例

### TCP带宽测试输出

```
Connecting to host 192.168.1.100, port 5201
[  5] local 192.168.1.10 port 54321 connected to 192.168.1.100 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   112 MBytes   941 Mbits/sec    0    435 KBytes
[  5]   1.00-2.00   sec   112 MBytes   941 Mbits/sec    0    435 KBytes
[  5]   2.00-3.00   sec   112 MBytes   941 Mbits/sec    0    435 KBytes
[  5]   3.00-4.00   sec   112 MBytes   941 Mbits/sec    0    435 KBytes
[  5]   4.00-5.00   sec   112 MBytes   941 Mbits/sec    2    328 KBytes  ← 重传
[  5]   5.00-6.00   sec   112 MBytes   941 Mbits/sec    0    435 KBytes
[  5]   6.00-7.00   sec   112 MBytes   941 Mbits/sec    0    435 KBytes
[  5]   7.00-8.00   sec   112 MBytes   941 Mbits/sec    0    435 KBytes
[  5]   8.00-9.00   sec   112 MBytes   941 Mbits/sec    1    381 KBytes  ← 重传
[  5]   9.00-10.00  sec   112 MBytes   941 Mbits/sec    0    435 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.09 GBytes   941 Mbits/sec    3             sender
[  5]   0.00-10.00  sec  1.09 GBytes   938 Mbits/sec                  receiver
                                        ↑               ↑
                                    关键指标          重传次数

iperf Done.
```

**关键指标解读:**

| 字段 | 说明 | 重要性 |
|------|------|--------|
| **Bitrate** | 带宽（Mbits/sec或Gbits/sec） | ★★★★★ 核心指标 |
| **Retr** | TCP重传次数 | ★★★★☆ 质量指标 |
| **Cwnd** | 拥塞窗口大小 | ★★★☆☆ 优化参考 |
| Transfer | 传输数据量 | ★★☆☆☆ 参考信息 |
| Interval | 统计时间间隔 | ★☆☆☆☆ 时间参考 |

**性能等级分类:**

| 带宽范围 | 性能等级 | 星级 | 网络类型 |
|---------|---------|------|---------|
| ≥ 90 Gbps | 卓越 | ★★★★★ | 100GbE |
| ≥ 9 Gbps | 优秀 | ★★★★☆ | 10GbE线速 |
| ≥ 900 Mbps | 良好 | ★★★☆☆ | 1GbE线速 |
| ≥ 500 Mbps | 一般 | ★★☆☆☆ | 1GbE部分 |
| ≥ 90 Mbps | 较低 | ★☆☆☆☆ | 100Mbps |
| < 90 Mbps | 很低 | ☆☆☆☆☆ | <100Mbps |

**重传次数评估:**

| 重传次数 | 评级 | 影响 |
|---------|------|------|
| 0 | ★★★★★ 完美 | 无丢包 |
| 1-10 | ★★★★☆ 优秀 | 轻微影响 |
| 11-50 | ★★★☆☆ 良好 | 可接受 |
| 51-200 | ★★☆☆☆ 一般 | 有影响 |
| > 200 | ★☆☆☆☆ 较差 | 严重影响 |

### UDP带宽测试输出

```
Connecting to host 192.168.1.100, port 5201
[  5] local 192.168.1.10 port 43210 connected to 192.168.1.100 port 5201
[ ID] Interval           Transfer     Bitrate         Total Datagrams
[  5]   0.00-1.00   sec   119 MBytes  1000 Mbits/sec  15360
[  5]   1.00-2.00   sec   119 MBytes  1000 Mbits/sec  15360
[  5]   2.00-3.00   sec   119 MBytes  1000 Mbits/sec  15360
...
[  5]   9.00-10.00  sec   119 MBytes  1000 Mbits/sec  15360
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Jitter    Lost/Total Datagrams
[  5]   0.00-10.00  sec  1.16 GBytes  1000 Mbits/sec  0.015 ms  73/153600 (0.048%)
[  5] Sent 153600 datagrams                               ↑          ↑
                                                        抖动      丢包率
iperf Done.
```

**关键指标解读:**

| 字段 | 说明 | 重要性 |
|------|------|--------|
| **Bitrate** | UDP吞吐量 | ★★★★★ |
| **Jitter** | 抖动（ms） | ★★★★★ |
| **Lost/Total** | 丢包率（%） | ★★★★★ |
| Total Datagrams | 发送的数据报数量 | ★★☆☆☆ |

**丢包率评估:**

| 丢包率 | 评级 | 应用影响 |
|--------|------|---------|
| < 0.01% | ★★★★★ 优秀 | 视频会议完美 |
| 0.01-0.1% | ★★★★☆ 良好 | 大部分应用正常 |
| 0.1-1% | ★★★☆☆ 一般 | 实时应用受影响 |
| 1-5% | ★★☆☆☆ 较差 | 明显质量下降 |
| > 5% | ★☆☆☆☆ 很差 | 不可用 |

**抖动(Jitter)评估:**

| 抖动 | 评级 | VoIP质量 |
|------|------|---------|
| < 1 ms | ★★★★★ 优秀 | 优质通话 |
| 1-5 ms | ★★★★☆ 良好 | 正常通话 |
| 5-20 ms | ★★★☆☆ 一般 | 可接受 |
| 20-50 ms | ★★☆☆☆ 较差 | 明显延迟感 |
| > 50 ms | ★☆☆☆☆ 很差 | 不可用 |

### 双向测试输出

```
[ ID][Role] Interval           Transfer     Bitrate         Retr
[  5][TX-C]   0.00-10.00  sec  1.09 GBytes   941 Mbits/sec    3    ← 上行
[  7][RX-C]   0.00-10.00  sec  1.08 GBytes   931 Mbits/sec         ← 下行
[SUM][ALL]   0.00-10.00  sec  2.17 GBytes  1.87 Gbits/sec    3    ← 总计
```

**对称性分析:**
```
对称性 = 上行带宽 / 下行带宽

示例: 941 / 931 = 1.01

评估:
  0.9 - 1.1:  ★★★★★ 对称链路
  0.8 - 0.9 或 1.1 - 1.2:  ★★★★☆ 轻微不对称
  0.7 - 0.8 或 1.2 - 1.3:  ★★★☆☆ 中等不对称
  < 0.7 或 > 1.3:  ★★☆☆☆ 严重不对称（ADSL等）
```

## JSON格式输出解读

### JSON输出示例

```json
{
  "start": {
    "connected": [{
      "socket": 5,
      "local_host": "192.168.1.10",
      "local_port": 54321,
      "remote_host": "192.168.1.100",
      "remote_port": 5201
    }],
    "tcp_mss_default": 1448,                    ← MSS大小
    "sock_bufsize": 131072,                      ← Socket缓冲区
    "sndbuf_actual": 16384,
    "rcvbuf_actual": 131072
  },
  "intervals": [
    {
      "streams": [{
        "socket": 5,
        "start": 0,
        "end": 1.00003,
        "seconds": 1.00003,
        "bytes": 117440512,
        "bits_per_second": 939494000,            ← 关键: 每秒比特数
        "retransmits": 0,                         ← 关键: 重传次数
        "snd_cwnd": 445488,                       ← 拥塞窗口
        "rtt": 234,                               ← RTT微秒
        "omitted": false
      }]
    }
  ],
  "end": {
    "sum_sent": {
      "start": 0,
      "end": 10.0001,
      "seconds": 10.0001,
      "bytes": 1174405120,
      "bits_per_second": 939513000,              ← 关键: 平均带宽
      "retransmits": 3,                           ← 关键: 总重传
      "max_rtt": 456,                             ← 最大RTT
      "min_rtt": 123,                             ← 最小RTT
      "mean_rtt": 234                             ← 平均RTT
    },
    "sum_received": {
      "bytes": 1174405120,
      "bits_per_second": 938745000
    }
  }
}
```

**JSON关键字段提取:**

```bash
# 提取带宽
jq '.end.sum_sent.bits_per_second' result.json

# 提取重传次数
jq '.end.sum_sent.retransmits' result.json

# 提取平均RTT
jq '.end.sum_sent.mean_rtt' result.json

# UDP提取丢包率
jq '.end.sum.lost_packets, .end.sum.packets' result.json
```

## 测试场景详细解读

### 场景1: TCP带宽测试

**测试命令:**
```bash
# 上行测试（客户端→服务器）
iperf3 -c 192.168.1.100 -t 10

# 下行测试（服务器→客户端）
iperf3 -c 192.168.1.100 -R -t 10
```

**影响因素分析:**

1. **TCP窗口大小**
   ```
   最大吞吐量 = 窗口大小 / RTT

   示例:
     窗口 = 128KB
     RTT = 1ms
     最大吞吐 = 131072 × 8 / 0.001 = 1049 Mbps
   ```

2. **网络拥塞**
   - 表现: 带宽低于预期，重传次数多
   - 诊断: 检查Retr列，查看拥塞窗口(Cwnd)变化

3. **CPU瓶颈**
   ```bash
   # 测试时监控CPU
   mpstat -P ALL 1

   # 如果%soft(软中断) > 30%，CPU是瓶颈
   ```

**性能对比参考:**

| 网络类型 | 理论带宽 | 实际可达 | 达成率 |
|---------|---------|---------|--------|
| 100Mbps | 100 Mbps | 90-95 Mbps | 90-95% |
| 1GbE | 1000 Mbps | 930-950 Mbps | 93-95% |
| 10GbE | 10000 Mbps | 9300-9500 Mbps | 93-95% |
| 100GbE | 100000 Mbps | 93000-95000 Mbps | 93-95% |

### 场景2: UDP带宽和丢包测试

**测试命令:**
```bash
# 设置目标带宽为1Gbps
iperf3 -c 192.168.1.100 -u -b 1G -t 10
```

**丢包原因分析:**

1. **发送速率过快**
   ```
   发送带宽 > 链路容量 → 必然丢包

   解决: 降低目标带宽(-b参数)
   ```

2. **接收缓冲区不足**
   ```bash
   # 查看丢包统计
   netstat -su | grep "receive buffer errors"

   # 增大缓冲区
   sysctl -w net.core.rmem_max=134217728
   ```

3. **网络拥塞**
   ```bash
   # 使用mtr检查路径
   mtr -r -c 100 192.168.1.100
   ```

**应用场景评估:**

| 应用 | 带宽需求 | 丢包容忍 | 抖动容忍 |
|------|---------|---------|---------|
| 视频直播 | 5-20 Mbps | < 1% | < 20 ms |
| VoIP | 64-128 Kbps | < 0.5% | < 5 ms |
| 在线游戏 | 128-512 Kbps | < 0.1% | < 1 ms |
| 文件传输 | 尽可能高 | 不可接受 | 不敏感 |

### 场景3: 双向同时测试

**测试命令:**
```bash
iperf3 -c 192.168.1.100 --bidir -t 10
```

**分析要点:**

1. **总带宽验证**
   ```
   总带宽 ≈ 上行 + 下行

   1GbE全双工理论: ~1.8-1.9 Gbps
   实际: 1.6-1.8 Gbps正常
   ```

2. **干扰检测**
   ```
   如果: (上行+下行) << 单向 × 2
   可能: 半双工链路或硬件问题
   ```

### 场景4: 多流并发测试

**测试命令:**
```bash
# 8个并发流
iperf3 -c 192.168.1.100 -P 8 -t 10
```

**并行效率分析:**

```
并行效率 = (总带宽 / 流数量) / 单流带宽

示例:
  单流: 940 Mbps
  8流总计: 7200 Mbps
  平均: 900 Mbps/流
  效率: 900 / 940 = 95.7%

评估:
  > 90%: ★★★★★ 优秀扩展性
  80-90%: ★★★★☆ 良好
  70-80%: ★★★☆☆ 一般
  < 70%: ★★☆☆☆ 较差（可能CPU瓶颈）
```

## 性能瓶颈诊断

### 症状1: TCP带宽远低于网络容量

**示例:** 1GbE网络，但只有200Mbps

**诊断流程:**

```
┌─────────────────────┐
│ 1. 检查TCP窗口大小   │
└──────────┬──────────┘
           ↓
    sysctl net.ipv4.tcp_rmem
    sysctl net.ipv4.tcp_wmem
           ↓
┌─────────────────────┐
│ 2. 测量RTT           │
└──────────┬──────────┘
           ↓
    ping -c 100 [目标IP]
           ↓
┌─────────────────────┐
│ 3. 计算BDP           │
└──────────┬──────────┘
           ↓
    BDP = 带宽 × RTT
    窗口应 >= BDP
           ↓
┌─────────────────────┐
│ 4. 检查CPU使用率     │
└──────────┬──────────┘
           ↓
    mpstat -P ALL 1
    查看%soft列
           ↓
┌─────────────────────┐
│ 5. 检查网卡offload   │
└──────────┬──────────┘
           ↓
    ethtool -k eth0
```

**优化措施:**

```bash
# 1. 增大TCP缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# 2. 使用iperf3测试不同窗口大小
iperf3 -c 192.168.1.100 -w 1M -t 10

# 3. 启用网卡offload
ethtool -K eth0 tso on gso on gro on

# 4. 使用BBR拥塞控制
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

### 症状2: UDP严重丢包

**示例:** 丢包率>5%

**诊断流程:**

1. **检查是否发送过快**
   ```bash
   # 降低目标带宽
   iperf3 -c 192.168.1.100 -u -b 500M -t 10

   # 逐步增加直到出现丢包
   ```

2. **检查接收缓冲区**
   ```bash
   # 查看丢包统计
   netstat -su | grep "receive buffer errors"

   # 如果很高，增大缓冲区
   sysctl -w net.core.rmem_max=134217728
   sysctl -w net.core.rmem_default=33554432
   ```

3. **检查网络路径**
   ```bash
   # 使用mtr检查每跳丢包
   mtr -r -c 100 192.168.1.100
   ```

### 症状3: 大量TCP重传

**示例:** Retr列频繁显示非零值

**原因分析:**

1. **网络拥塞**
   - 表现: 重传均匀分布
   - 解决: 检查网络负载，升级带宽

2. **网络错误**
   - 表现: 重传集中在某些时间段
   - 解决: 检查网线、交换机

3. **TCP参数不当**
   ```bash
   # 检查拥塞控制算法
   sysctl net.ipv4.tcp_congestion_control

   # 尝试BBR（适合高延迟）
   sysctl -w net.ipv4.tcp_congestion_control=bbr
   ```

## 不同场景优化建议

### 场景A: 本地局域网（1GbE）

**目标:** 接近线速(~940 Mbps)

**优化配置:**
```bash
# TCP参数
sysctl -w net.ipv4.tcp_rmem="4096 87380 6291456"
sysctl -w net.ipv4.tcp_wmem="4096 65536 4194304"

# 网卡offload
ethtool -K eth0 tso on gso on gro on

# 测试
iperf3 -c 192.168.1.100 -t 60
```

**预期结果:** 930-950 Mbps

### 场景B: 高延迟WAN（RTT 100ms）

**目标:** 充分利用带宽

**关键计算:**
```
BDP = 1Gbps × 100ms = 100Mb = 12.5MB
TCP窗口需要 >= 12.5MB
```

**优化配置:**
```bash
# 增大TCP缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 33554432"
sysctl -w net.ipv4.tcp_wmem="4096 65536 33554432"

# 使用BBR拥塞控制
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 启用窗口缩放
sysctl -w net.ipv4.tcp_window_scaling=1

# 测试大窗口
iperf3 -c [远程IP] -w 16M -t 60
```

### 场景C: 10GbE高性能网络

**目标:** 9+ Gbps

**优化配置:**
```bash
# 大缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 268435456"
sysctl -w net.ipv4.tcp_wmem="4096 65536 268435456"
sysctl -w net.core.rmem_max=268435456
sysctl -w net.core.wmem_max=268435456

# 增大队列
sysctl -w net.core.netdev_max_backlog=30000

# 多队列网卡
ethtool -L eth0 combined 8

# 并发流测试
iperf3 -c 192.168.1.100 -P 8 -t 60
```

**预期结果:** 单流 3-4 Gbps，8流 9+ Gbps

## 常见问题解答

### Q1: 为什么环回(localhost)测试性能不高？

**A:** 环回测试受CPU和内存带宽限制，而非网络。

```bash
# 优化环回测试
iperf3 -c localhost -P 4

# 预期: 10-40 Gbps（取决于CPU）
```

### Q2: JSON输出如何解析？

**A:** 使用jq工具。

```bash
# 提取带宽(Mbps)
iperf3 -c 192.168.1.100 -J | \
    jq '.end.sum_sent.bits_per_second / 1000000'

# 提取重传次数
iperf3 -c 192.168.1.100 -J | \
    jq '.end.sum_sent.retransmits'
```

### Q3: 如何进行长时间稳定性测试？

**A:** 使用长时间测试并监控。

```bash
# 1小时测试，每30秒输出
iperf3 -c 192.168.1.100 -t 3600 -i 30

# 分析带宽波动
# 检查重传是否递增
```

---

**更新日期:** 2026-04-19
**版本:** 1.0
