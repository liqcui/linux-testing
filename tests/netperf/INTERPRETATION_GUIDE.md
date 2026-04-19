# Netperf 结果解读指南

本文档提供Netperf测试结果的详细解读，帮助理解网络性能数据并识别网络瓶颈。

## 典型测试输出示例

### TCP_STREAM（TCP吞吐量测试）

```
MIGRATED TCP STREAM TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 192.168.1.100 () port 0 AF_INET
Recv   Send    Send
Socket Socket  Message  Elapsed
Size   Size    Size     Time     Throughput
bytes  bytes   bytes    secs.    10^6bits/sec

 87380  16384  16384    10.00     941.23      ← 关键指标: 吞吐量
```

**关键指标解读:**

| 字段 | 说明 | 示例值 |
|------|------|--------|
| Recv Socket Size | 接收端Socket缓冲区大小 | 87380 bytes |
| Send Socket Size | 发送端Socket缓冲区大小 | 16384 bytes |
| Message Size | 单次发送消息大小 | 16384 bytes |
| Elapsed Time | 测试持续时间 | 10.00 秒 |
| **Throughput** | **吞吐量（关键指标）** | **941.23 Mbps** |

**性能等级划分:**

| 吞吐量 | 性能等级 | 星级 | 网络类型 |
|--------|---------|------|---------|
| ≥ 90 Gbps | 卓越 | ★★★★★ | 100GbE |
| ≥ 9 Gbps | 优秀 | ★★★★☆ | 10GbE线速 |
| ≥ 900 Mbps | 良好 | ★★★☆☆ | 1GbE线速 |
| ≥ 500 Mbps | 一般 | ★★☆☆☆ | 1GbE部分带宽 |
| ≥ 90 Mbps | 较低 | ★☆☆☆☆ | 100Mbps或受限 |
| < 90 Mbps | 很低 | ☆☆☆☆☆ | <100Mbps或严重拥塞 |

### TCP_RR（TCP请求响应测试）

```
MIGRATED TCP REQUEST/RESPONSE TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 192.168.1.100 () port 0 AF_INET : first burst 0
Local /Remote
Socket Size   Request  Resp.   Elapsed  Trans.
Send   Recv   Size     Size    Time     Rate
bytes  Bytes  bytes    bytes   secs.    per sec

16384  87380  1        1       10.00    45678.23    ← 关键指标: 事务率
```

**关键指标解读:**

| 字段 | 说明 | 示例值 |
|------|------|--------|
| Request Size | 请求数据大小 | 1 byte |
| Response Size | 响应数据大小 | 1 byte |
| **Trans. Rate** | **事务率（TPS）** | **45678.23 Trans/sec** |

**从事务率计算延迟:**
```
平均延迟(ms) = 1000 / 事务率(TPS)

示例:
  事务率 = 45678.23 TPS
  平均延迟 = 1000 / 45678.23 = 0.0219 ms = 21.9 μs
```

**性能等级划分:**

| 事务率(TPS) | 延迟 | 性能等级 | 星级 | 应用场景 |
|------------|------|---------|------|---------|
| ≥ 100K | < 0.01 ms | 卓越 | ★★★★★ | 内存数据库、超低延迟交易 |
| ≥ 50K | 0.01-0.02 ms | 优秀 | ★★★★☆ | 本地网络、Redis缓存 |
| ≥ 20K | 0.02-0.05 ms | 良好 | ★★★☆☆ | 1GbE网络、MySQL查询 |
| ≥ 5K | 0.05-0.2 ms | 一般 | ★★☆☆☆ | 常规应用 |
| < 5K | > 0.2 ms | 较低 | ★☆☆☆☆ | 高延迟网络 |

### TCP_CRR（TCP连接请求响应测试）

```
MIGRATED TCP Connect/Request/Response TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 192.168.1.100 () port 0 AF_INET
Local /Remote
Socket Size   Request  Resp.   Elapsed  Trans.
Send   Recv   Size     Size    Time     Rate
bytes  Bytes  bytes    bytes   secs.    per sec

131070 131070 1        1       10.00    12345.67    ← 关键指标: 连接率
```

**关键指标解读:**

| 指标 | 说明 | 意义 |
|------|------|------|
| **Trans. Rate** | 连接率（Conn/sec） | 每秒可建立的新连接数 |

**从连接率计算连接时间:**
```
连接时间(ms) = 1000 / 连接率(Conn/sec)

示例:
  连接率 = 12345.67 Conn/sec
  连接时间 = 1000 / 12345.67 = 0.081 ms
```

**性能等级划分:**

| 连接率(Conn/s) | 连接时间 | 性能等级 | 星级 | 应用场景 |
|---------------|---------|---------|------|---------|
| ≥ 50K | < 0.02 ms | 卓越 | ★★★★★ | 高性能负载均衡器 |
| ≥ 20K | 0.02-0.05 ms | 优秀 | ★★★★☆ | 企业级Web服务器 |
| ≥ 10K | 0.05-0.1 ms | 良好 | ★★★☆☆ | 标准Web服务器 |
| ≥ 5K | 0.1-0.2 ms | 一般 | ★★☆☆☆ | 入门级服务器 |
| < 5K | > 0.2 ms | 较低 | ★☆☆☆☆ | 受限环境 |

### UDP_STREAM（UDP吞吐量测试）

```
UDP UNIDIRECTIONAL SEND TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 192.168.1.100 () port 0 AF_INET
Socket  Message  Elapsed      Messages
Size    Size     Time         Okay Errors   Throughput
bytes   bytes    secs            #      #   10^6bits/sec

212992   1472   10.00      850000      0     998.40     ← 发送端统计

212992           10.00      845000           994.18     ← 接收端统计
```

**关键指标解读:**

| 指标 | 说明 | 重要性 |
|------|------|--------|
| Throughput (发送端) | 发送速率 | 发送能力 |
| Throughput (接收端) | 接收速率 | 实际吞吐 |
| Messages Okay | 成功接收的包数 | 可靠性 |
| Messages Errors | 错误包数 | 丢包情况 |

**丢包率计算:**
```
丢包率(%) = (发送包数 - 接收包数) / 发送包数 × 100

示例:
  发送: 850000 包
  接收: 845000 包
  丢包率 = (850000 - 845000) / 850000 × 100 = 0.59%
```

**丢包率评估标准:**

| 丢包率 | 评级 | 应用影响 |
|--------|------|---------|
| < 0.01% | ★★★★★ 优秀 | 视频会议可用 |
| 0.01-0.1% | ★★★★☆ 良好 | 大部分应用可接受 |
| 0.1-1% | ★★★☆☆ 一般 | 实时应用受影响 |
| 1-5% | ★★☆☆☆ 较差 | 明显质量下降 |
| > 5% | ★☆☆☆☆ 很差 | 不可用 |

## 测试类型详细解读

### 1. TCP_STREAM - TCP批量传输

**测试原理:**
```
Client                    Server
  │                         │
  │────── 数据流 ────────>│  (持续发送)
  │────── 数据流 ────────>│
  │────── 数据流 ────────>│
  │         ...             │
  │                         │
 测量吞吐量(Mbps)
```

**应用场景:**
- 大文件下载/上传
- 视频流传输
- 数据备份
- CDN内容分发

**影响因素:**

1. **网络带宽**
   - 物理链路速度（100Mbps/1Gbps/10Gbps）
   - 网络拥塞情况

2. **TCP窗口大小**
   ```
   最大吞吐量 = TCP窗口大小 / RTT

   示例:
     窗口 = 64KB
     RTT = 1ms
     最大吞吐 = 65536 × 8 / 0.001 = 524 Mbps
   ```

3. **CPU性能**
   - 协议栈处理能力
   - 中断处理效率
   - 网卡offload功能

4. **内存带宽**
   - 数据复制开销
   - 缓存命中率

**优化建议:**
```bash
# 1. 增大TCP缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# 2. 启用TCP窗口缩放
sysctl -w net.ipv4.tcp_window_scaling=1

# 3. 调整拥塞控制算法
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 4. 启用网卡offload
ethtool -K eth0 tso on gso on gro on

# 5. 增加网络队列长度
sysctl -w net.core.netdev_max_backlog=5000
```

### 2. TCP_RR - TCP请求响应

**测试原理:**
```
Client                    Server
  │                         │
  │────── 请求(1B) ──────>│
  │<───── 响应(1B) ──────│
  │                         │
  │────── 请求(1B) ──────>│
  │<───── 响应(1B) ──────│
  │         ...             │
  │                         │
 测量事务率(TPS)
 计算延迟(ms)
```

**应用场景:**
- 数据库查询（SELECT操作）
- 缓存访问（Redis GET/SET）
- RESTful API调用
- RPC调用

**延迟组成分析:**
```
总延迟 = 应用处理时间 + 网络传输时间 + 协议开销

其中:
  网络传输时间 = RTT (往返时延)
  协议开销 = TCP处理 + 内核调度
```

**典型延迟值:**

| 场景 | 典型延迟 | 说明 |
|------|---------|------|
| 本地loopback | 10-50 μs | 无物理网络 |
| 同机房1GbE | 50-200 μs | 低延迟网络 |
| 同城10km | 0.1-0.5 ms | 光纤传输延迟 |
| 跨城100km | 1-3 ms | 传输距离影响 |
| 跨国5000km | 50-100 ms | 长距离高延迟 |

**优化建议:**
```bash
# 1. 减少TCP_NODELAY影响
# 在应用中启用TCP_NODELAY禁用Nagle算法
setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag));

# 2. 优化中断亲和性
# 将网卡中断绑定到特定CPU
echo 1 > /proc/irq/[IRQ]/smp_affinity_list

# 3. 使用更快的网络（10GbE）

# 4. 减少应用处理时间
# 使用内存缓存、预计算等
```

### 3. TCP_CRR - TCP连接请求响应

**测试原理:**
```
Client                    Server
  │                         │
  │────── SYN ──────────>│
  │<───── SYN-ACK ───────│
  │────── ACK ──────────>│  (3次握手)
  │────── 请求(1B) ─────>│
  │<───── 响应(1B) ──────│
  │────── FIN ──────────>│  (连接关闭)
  │<───── FIN-ACK ───────│
  │                         │
  重复...
  │                         │
 测量连接率(Conn/sec)
```

**应用场景:**
- HTTP/1.0短连接
- 传统CGI应用
- 无连接池的应用
- 防火墙性能测试

**连接开销分析:**
```
连接开销 = 3次握手 + 数据传输 + 4次挥手
         ≈ RTT × 3 + 数据传输时间 + RTT × 2
         ≈ RTT × 5 + 数据传输时间

示例:
  RTT = 0.1ms
  连接开销 ≈ 0.5ms
  最大连接率 ≈ 1000 / 0.5 = 2000 Conn/s
```

**优化建议:**
```bash
# 1. 使用连接池
# 避免频繁建立/关闭连接

# 2. 升级到HTTP/2或HTTP/3
# 支持连接复用

# 3. 调整TIME_WAIT参数
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.tcp_fin_timeout=30

# 4. 增大本地端口范围
sysctl -w net.ipv4.ip_local_port_range="10000 65535"

# 5. 启用SYN cookies防止SYN flood
sysctl -w net.ipv4.tcp_syncookies=1
```

### 4. UDP_STREAM - UDP批量传输

**测试原理:**
```
Client                    Server
  │                         │
  │════════ UDP包 ═══════>│  (无连接)
  │════════ UDP包 ═══════>│
  │════════ UDP包 ═══════>│
  │         ...             │
  │                         │
 测量吞吐量(Mbps)
 统计丢包率(%)
```

**应用场景:**
- 视频直播（RTMP/WebRTC）
- VoIP电话（SIP/RTP）
- 在线游戏
- DNS查询
- 日志传输

**丢包原因分析:**

1. **网络拥塞**
   - 路由器缓冲区溢出
   - 带宽不足

2. **接收端处理不及时**
   - CPU负载过高
   - Socket缓冲区过小
   - 应用处理慢

3. **网络错误**
   - 链路错误
   - 硬件故障

**丢包影响评估:**

| 应用类型 | 可容忍丢包率 | 超过后果 |
|---------|------------|---------|
| 视频直播 | < 1% | 马赛克、卡顿 |
| VoIP | < 0.5% | 声音断续 |
| 在线游戏 | < 0.1% | 延迟感知明显 |
| 文件传输 | 不可接受 | 需要重传机制 |

**优化建议:**
```bash
# 1. 增大UDP接收缓冲区
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.rmem_default=33554432

# 2. 增加网络队列长度
sysctl -w net.core.netdev_max_backlog=10000

# 3. 应用层实现丢包恢复
# FEC (Forward Error Correction)
# ARQ (Automatic Repeat reQuest)

# 4. 使用QoS确保带宽
# tc命令配置流量控制
```

## 性能瓶颈识别

### 瓶颈类型判断

#### 症状1: TCP吞吐量远低于网络带宽

**示例:**
```
1GbE网络，但TCP_STREAM只有200Mbps
```

**可能原因:**

1. **TCP窗口太小**
   ```bash
   # 检查当前窗口大小
   ss -i | grep -E "cwnd|rcv_space"

   # 查看系统限制
   sysctl net.ipv4.tcp_rmem
   sysctl net.ipv4.tcp_wmem
   ```

2. **高RTT限制吞吐**
   ```
   带宽延迟乘积(BDP) = 带宽 × RTT

   示例:
     1Gbps链路，RTT=100ms
     BDP = 1000Mbps × 0.1s = 100Mb = 12.5MB

   如果TCP窗口 < 12.5MB，则无法跑满带宽
   ```

3. **CPU瓶颈**
   ```bash
   # 检查软中断CPU使用率
   mpstat -P ALL 1
   # 查看%soft列

   # 如果%soft > 30%，说明协议栈处理是瓶颈
   ```

4. **网卡offload未启用**
   ```bash
   # 检查offload状态
   ethtool -k eth0 | grep -E "tcp|generic"

   # TSO/GSO/GRO应为on
   ```

**诊断流程:**
```
┌─────────────────────┐
│ 吞吐量低于预期？      │
└──────────┬──────────┘
           ↓
    ┌─────────────┐
    │ 检查TCP窗口  │ ← sysctl net.ipv4.tcp_*mem
    └──────┬──────┘
           ↓
    ┌─────────────┐
    │ 检查RTT      │ ← ping测量
    └──────┬──────┘
           ↓
    ┌─────────────┐
    │ 检查CPU使用  │ ← mpstat查看%soft
    └──────┬──────┘
           ↓
    ┌─────────────┐
    │ 检查offload  │ ← ethtool -k
    └─────────────┘
```

#### 症状2: TCP_RR延迟高

**示例:**
```
本地网络，但延迟达到1ms（预期<0.1ms）
```

**可能原因:**

1. **Nagle算法影响**
   ```
   Nagle算法会延迟发送小包
   对于请求响应模式造成额外延迟
   ```

2. **中断合并(Interrupt Coalescing)**
   ```bash
   # 检查中断合并设置
   ethtool -c eth0

   # rx-usecs太大会增加延迟
   ```

3. **CPU C-states省电模式**
   ```bash
   # 检查C-states
   cpupower idle-info

   # 深度睡眠状态唤醒慢
   ```

4. **交换分区影响**
   ```bash
   # 检查是否发生交换
   vmstat 1
   # si/so列非0表示有交换
   ```

**诊断和优化:**
```bash
# 1. 禁用Nagle
sysctl -w net.ipv4.tcp_nodelay=1

# 2. 减小中断合并延迟
ethtool -C eth0 rx-usecs 0

# 3. 禁用C-states
cpupower frequency-set -g performance

# 4. 禁用交换
swapoff -a
```

#### 症状3: UDP丢包严重

**示例:**
```
UDP_STREAM丢包率>5%
```

**可能原因:**

1. **接收缓冲区溢出**
   ```bash
   # 查看丢包统计
   netstat -su | grep -i "receive errors"

   # 如果"receive buffer errors"很高
   # 说明接收缓冲区不足
   ```

2. **发送速率过快**
   ```
   发送速率 > 网络带宽 → 必然丢包
   ```

3. **网络拥塞**
   ```bash
   # 使用mtr检查网络路径
   mtr -r -c 100 [目标IP]

   # 查看中间节点丢包情况
   ```

**诊断流程:**
```
UDP丢包
    ↓
┌─────────────────┐
│ 检查接收缓冲区   │ ← netstat -su
└────────┬────────┘
         ↓
┌─────────────────┐
│ 检查发送速率     │ ← 是否超过带宽
└────────┬────────┘
         ↓
┌─────────────────┐
│ 检查网络路径     │ ← mtr检查
└─────────────────┘
```

**优化措施:**
```bash
# 1. 增大接收缓冲区
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.rmem_default=33554432

# 2. 限制发送速率
# 在应用层实现速率控制

# 3. 启用多队列网卡
ethtool -l eth0  # 查看队列数
ethtool -L eth0 combined 8  # 设置队列数
```

## 不同网络环境性能基准

### 本地环回(Loopback)

**预期性能:**
```
TCP_STREAM:   > 10 Gbps  (受CPU和内存带宽限制)
TCP_RR:       > 100K TPS (延迟 < 0.01ms)
TCP_CRR:      > 50K Conn/s
UDP_STREAM:   > 10 Gbps
```

**典型用途:**
- 本地进程间通信性能测试
- 协议栈性能基准

### 1GbE以太网

**预期性能:**
```
TCP_STREAM:   900-950 Mbps (理论线速941Mbps)
TCP_RR:       20K-50K TPS
TCP_CRR:      10K-20K Conn/s
UDP_STREAM:   900-950 Mbps (丢包率<0.1%)
```

**影响因素:**
- 交换机性能
- 网线质量（Cat5e vs Cat6）
- 网卡offload功能

### 10GbE以太网

**预期性能:**
```
TCP_STREAM:   9.0-9.5 Gbps
TCP_RR:       50K-150K TPS
TCP_CRR:      20K-50K Conn/s
UDP_STREAM:   9.0-9.5 Gbps
```

**优化要点:**
- 多队列网卡必须启用
- CPU性能要跟上
- 使用NUMA感知配置

### 100GbE以太网

**预期性能:**
```
TCP_STREAM:   90-95 Gbps
TCP_RR:       100K-300K TPS
TCP_CRR:      50K-100K Conn/s
UDP_STREAM:   90-95 Gbps
```

**特殊要求:**
- 需要高性能CPU（如Xeon Platinum）
- NUMA优化至关重要
- 考虑使用DPDK绕过内核

### WiFi网络

**预期性能（WiFi 6, 802.11ax）:**
```
TCP_STREAM:   500-1200 Mbps (理论)
               300-800 Mbps (实际)
TCP_RR:       5K-15K TPS
延迟:         1-10 ms (不稳定)
丢包率:       0.1-5% (取决于信号质量)
```

**特点:**
- 性能波动大
- 延迟不稳定
- 半双工通信（上下行互相影响）

### 广域网/互联网

**预期性能（取决于ISP和距离）:**
```
带宽:         根据购买服务
延迟:
  同城:       1-5 ms
  跨省:       10-50 ms
  跨国:       50-300 ms
丢包率:       0.1-1% (正常)
              >1% (拥塞或故障)
```

## 性能优化最佳实践

### 操作系统层面

**1. TCP参数优化**
```bash
# /etc/sysctl.conf

# 增大TCP缓冲区
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# 启用TCP窗口缩放
net.ipv4.tcp_window_scaling = 1

# 使用BBR拥塞控制
net.ipv4.tcp_congestion_control = bbr

# 快速回收TIME_WAIT
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# 增大连接队列
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192

# 增大网络队列
net.core.netdev_max_backlog = 10000
```

**2. 网卡offload优化**
```bash
# 启用所有offload功能
ethtool -K eth0 tso on
ethtool -K eth0 gso on
ethtool -K eth0 gro on
ethtool -K eth0 lro on

# 增大网卡ring buffer
ethtool -G eth0 rx 4096 tx 4096

# 启用多队列
ethtool -L eth0 combined 8
```

**3. 中断优化**
```bash
# 中断亲和性配置
# 将网卡中断分散到多个CPU

# 示例：8核心系统，网卡eth0
for i in {0..7}; do
    echo $i > /proc/irq/[eth0_irq_base+$i]/smp_affinity_list
done

# 或使用irqbalance自动均衡
systemctl start irqbalance
```

### 应用层面

**1. Socket选项优化**
```c
// TCP_NODELAY - 禁用Nagle算法
int flag = 1;
setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag));

// SO_REUSEADDR - 允许地址重用
int reuse = 1;
setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

// SO_RCVBUF/SO_SNDBUF - 设置缓冲区大小
int bufsize = 16777216;
setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &bufsize, sizeof(bufsize));
setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &bufsize, sizeof(bufsize));

// TCP_QUICKACK - 快速ACK
int quickack = 1;
setsockopt(sock, IPPROTO_TCP, TCP_QUICKACK, &quickack, sizeof(quickack));
```

**2. 使用零拷贝技术**
```c
// sendfile() - 零拷贝传输文件
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);

// splice() - 管道零拷贝
ssize_t splice(int fd_in, loff_t *off_in, int fd_out,
               loff_t *off_out, size_t len, unsigned int flags);
```

**3. 连接池**
```python
# 使用连接池避免频繁建立连接
from DBUtils.PooledDB import PooledDB

pool = PooledDB(
    creator=psycopg2,
    maxconnections=100,
    mincached=10,
    blocking=True
)

conn = pool.connection()
```

### 硬件层面

**1. 网卡选择**
- 优先选择支持多队列的网卡
- Intel网卡通常性能更好
- 10GbE及以上考虑支持SR-IOV

**2. CPU选择**
- 高频率CPU对网络延迟友好
- 多核心CPU对高吞吐量重要
- NUMA系统需要特别配置

**3. 内存配置**
- 大内存缓冲区需要足够内存
- 内存带宽影响网络性能
- 考虑使用大页(Huge Pages)

## 常见问题诊断

### Q1: 为什么环回(loopback)测试性能不如预期？

**A: 环回测试受CPU和内存限制，而非网络。**

诊断步骤:
```bash
# 1. 检查CPU使用率
mpstat -P ALL 1

# 2. 检查内存带宽
# 使用STREAM benchmark

# 3. 尝试不同消息大小
netperf -H localhost -t TCP_STREAM -- -m 1024
netperf -H localhost -t TCP_STREAM -- -m 65536
```

### Q2: 为什么UDP吞吐量正常但TCP吞吐量很低？

**A: TCP受窗口大小和RTT限制。**

```bash
# 计算BDP
BDP = 带宽 × RTT

# 检查TCP窗口是否足够
ss -i | grep -E "cwnd|rcv_space"

# 增大窗口
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
```

### Q3: 如何确定网络是否跑满？

**A: 对比理论带宽。**

```
1GbE理论:  1000 Mbps
实际可达:  ~940 Mbps (考虑以太网开销)

10GbE理论: 10000 Mbps
实际可达:  ~9400 Mbps

如果TCP_STREAM > 理论带宽 × 90%，认为已跑满
```

---

**更新日期:** 2026-04-19
**版本:** 1.0
