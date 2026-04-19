# Netperf 网络性能测试

## 概述

Netperf是业界标准的网络性能测试工具，由惠普(HP)开发并开源。它提供全面的网络性能评估能力，包括吞吐量、延迟、并发连接等多个维度，支持TCP/UDP/SCTP等多种协议，是网络调优和故障诊断的必备工具。

## 目录结构

```
netperf/
├── README.md                       # 本文件
├── INTERPRETATION_GUIDE.md         # 结果详细解读指南
├── scripts/
│   ├── test_netperf.sh             # 综合自动化测试
│   └── netperf_advanced.sh         # 高级测试场景
└── results/                        # 测试结果目录
```

## Netperf测试原理

### 测试架构

```
Client                          Server
┌─────────────┐                ┌─────────────┐
│             │                │             │
│  netperf    │────────────────>│  netserver  │
│  (测试工具)  │<────────────────│  (服务端)   │
│             │                │             │
└─────────────┘                └─────────────┘
     │                              │
     ├─ 发送测试数据                 ├─ 接收测试数据
     ├─ 测量吞吐量/延迟               ├─ 返回响应
     └─ 生成测试报告                 └─ 提供统计信息
```

### 核心测试类型

#### 1. TCP_STREAM - TCP吞吐量测试

**原理:**
```
发送端                        接收端
  │                            │
  │──── 64KB数据块 ──────────>│
  │──── 64KB数据块 ──────────>│
  │──── 64KB数据块 ──────────>│
  │     (持续发送)             │
  │                            │
  └─测量: Throughput (Mbps)
```

**应用场景:**
- 大文件传输性能评估
- 视频流服务器性能测试
- CDN节点带宽测试
- 数据备份性能验证

**关键指标:**
- **吞吐量(Throughput)**: Mbps或GB/s
- 影响因素: 网络带宽、TCP窗口、CPU性能

#### 2. TCP_RR - TCP请求响应测试

**原理:**
```
客户端                        服务器
  │                            │
  │────── 请求(1字节) ────────>│
  │<───── 响应(1字节) ────────│
  │                            │ (重复)
  │────── 请求(1字节) ────────>│
  │<───── 响应(1字节) ────────│
  │                            │
  └─测量: Transactions/sec
  └─计算: Latency = 1000ms / TPS
```

**应用场景:**
- 数据库查询性能(SELECT)
- 缓存系统性能(Redis GET/SET)
- API服务响应时间
- RPC调用延迟测试

**关键指标:**
- **事务率(TPS)**: Transactions/sec
- **延迟(Latency)**: ms或μs
- 影响因素: RTT、协议栈开销、应用处理时间

#### 3. TCP_CRR - TCP连接请求响应测试

**原理:**
```
客户端                        服务器
  │                            │
  ├────── SYN ────────────────>│
  │<───── SYN-ACK ────────────│
  ├────── ACK ────────────────>│  (3次握手)
  │                            │
  ├────── 数据(1B) ───────────>│
  │<───── 数据(1B) ───────────│
  │                            │
  ├────── FIN ────────────────>│
  │<───── FIN-ACK ────────────│  (4次挥手)
  │                            │
  └─测量: Connections/sec
```

**应用场景:**
- HTTP/1.0短连接性能
- 负载均衡器连接处理能力
- 防火墙新建连接速率
- Web服务器并发能力

**关键指标:**
- **连接率**: Connections/sec
- **连接时间**: ms
- 影响因素: 三次握手开销、TIME_WAIT数量

#### 4. UDP_STREAM - UDP吞吐量测试

**原理:**
```
发送端                        接收端
  │                            │
  │═══ UDP包(1472B) ═════════>│
  │═══ UDP包(1472B) ═════════>│
  │═══ UDP包(1472B) ═════════>│
  │   (持续发送，无确认)        │
  │                            │
  └─测量: Throughput (Mbps)
  └─统计: Packet Loss (%)
```

**应用场景:**
- 视频直播性能测试
- VoIP语音质量评估
- 在线游戏延迟测试
- DNS服务器性能测试

**关键指标:**
- **吞吐量**: Mbps
- **丢包率**: %
- 影响因素: 网络拥塞、缓冲区大小

#### 5. TCP_MAERTS - 反向TCP传输

**原理:**
```
与TCP_STREAM相反，由服务器向客户端发送数据
用于测试下行带宽
```

**应用场景:**
- 测试下载速度
- 非对称带宽评估(ADSL等)

#### 6. TCP_SENDFILE - 零拷贝传输

**原理:**
```
使用sendfile()系统调用，减少数据拷贝次数
直接从文件到网络，绕过用户空间
```

**应用场景:**
- 文件服务器性能测试
- HTTP静态文件服务
- FTP服务器评估

### 测试参数详解

#### 基本参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-H <host>` | 目标服务器地址 | `-H 192.168.1.100` |
| `-p <port>` | netserver端口 | `-p 12865` (默认) |
| `-t <test>` | 测试类型 | `-t TCP_STREAM` |
| `-l <time>` | 测试时长(秒) | `-l 10` |

#### 高级参数(-- 后面)

| 参数 | 说明 | 示例 |
|------|------|------|
| `-m <size>` | 消息大小 | `-m 64K` |
| `-s <size>` | 本地socket缓冲区 | `-s 131072` |
| `-S <size>` | 远程socket缓冲区 | `-S 131072` |
| `-r <req,resp>` | 请求/响应大小 | `-r 1,1` |
| `-D` | 不延迟ACK | `-D` |
| `-R <0\|1>` | 显示接收端统计 | `-R 1` |

## 前置条件

### 系统要求

- Linux/Unix操作系统
- gcc编译器(源码安装时需要)
- 网络连通性(服务器和客户端能互相访问)

### 安装Netperf

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install netperf
```

**RHEL/CentOS/Rocky Linux:**
```bash
sudo yum install netperf
```

**Fedora:**
```bash
sudo dnf install netperf
```

**macOS:**
```bash
brew install netperf
```

**源码编译:**
```bash
wget https://github.com/HewlettPackard/netperf/archive/netperf-2.7.0.tar.gz
tar xzf netperf-2.7.0.tar.gz
cd netperf-netperf-2.7.0
./configure
make
sudo make install
```

### 启动netserver

**服务器端需要运行netserver:**
```bash
# 前台运行
netserver

# 后台运行(推荐)
netserver -D

# 指定端口
netserver -D -p 12865

# 绑定特定IP
netserver -D -L 192.168.1.100
```

**设置开机自启:**
```bash
# Systemd服务
sudo tee /etc/systemd/system/netserver.service <<EOF
[Unit]
Description=Netserver daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/netserver -D
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable netserver
sudo systemctl start netserver
```

**防火墙配置:**
```bash
# firewalld
sudo firewall-cmd --permanent --add-port=12865/tcp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport 12865 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

## 运行测试

### 快速开始

**基本用法:**
```bash
# 在客户端运行(确保服务器端已启动netserver)
netperf -H <服务器IP> -t <测试类型> -l <时长>
```

**示例:**
```bash
# TCP吞吐量测试(10秒)
netperf -H 192.168.1.100 -t TCP_STREAM -l 10

# TCP延迟测试
netperf -H 192.168.1.100 -t TCP_RR -l 10

# UDP吞吐量测试
netperf -H 192.168.1.100 -t UDP_STREAM -l 10
```

### 自动化测试脚本

**综合测试(推荐):**
```bash
cd scripts
./test_netperf.sh [服务器IP]

# 本地环回测试
./test_netperf.sh localhost

# 远程服务器测试
./test_netperf.sh 192.168.1.100
```

自动运行以下测试:
1. TCP吞吐量测试(TCP_STREAM)
2. TCP延迟测试(TCP_RR)
3. TCP连接测试(TCP_CRR)
4. UDP吞吐量测试(UDP_STREAM)
5. 不同消息大小性能分析

**高级测试场景:**
```bash
./netperf_advanced.sh [服务器IP] [测试时长]

# 示例
./netperf_advanced.sh 192.168.1.100 30
```

高级测试包括:
1. 双向同时传输测试(全双工)
2. 并发连接性能测试
3. Socket缓冲区优化测试
4. CPU亲和性测试
5. 延迟分布测试(百分位)
6. 带宽延迟乘积(BDP)优化
7. UDP丢包率测试

## 典型测试场景

### 场景1: 网络带宽测试

**目的:** 测试网络最大吞吐量

**测试命令:**
```bash
# 单向TCP吞吐量
netperf -H 192.168.1.100 -t TCP_STREAM -l 60 -- -m 64K

# 双向吞吐量(同时运行)
netperf -H 192.168.1.100 -t TCP_STREAM -l 60 -- -m 64K &
netperf -H 192.168.1.100 -t TCP_MAERTS -l 60 -- -m 64K &
wait
```

**预期结果:**
```
1GbE:   900-950 Mbps
10GbE:  9000-9500 Mbps
100GbE: 90000-95000 Mbps
```

**分析要点:**
- 接近理论带宽的94%即为正常
- 低于80%需要排查TCP窗口、CPU等问题

### 场景2: 数据库网络延迟测试

**目的:** 评估数据库查询网络延迟

**测试命令:**
```bash
# 小消息请求响应测试
netperf -H 192.168.1.100 -t TCP_RR -l 60 -- -r 1,1
```

**预期结果:**
```
本地网络(1GbE):  20K-50K TPS (延迟 0.02-0.05 ms)
数据中心内:       10K-30K TPS (延迟 0.03-0.1 ms)
跨数据中心:       1K-5K TPS (延迟 0.2-1 ms)
```

**分析要点:**
- 延迟应小于1ms(本地网络)
- 高TPS表示低延迟，适合OLTP数据库

### 场景3: Web服务器性能测试

**目的:** 测试Web服务器连接处理能力

**测试命令:**
```bash
# HTTP短连接模拟
netperf -H 192.168.1.100 -t TCP_CRR -l 60 -- -r 256,1024

# HTTP长连接模拟
netperf -H 192.168.1.100 -t TCP_RR -l 60 -- -r 512,8192
```

**预期结果:**
```
TCP_CRR:  10K-20K Conn/s  (短连接)
TCP_RR:   20K-50K TPS     (长连接)
```

**优化建议:**
- 短连接性能低: 启用连接复用(HTTP/1.1 Keep-Alive)
- 考虑升级到HTTP/2或HTTP/3

### 场景4: 视频直播UDP测试

**目的:** 测试UDP传输性能和丢包率

**测试命令:**
```bash
# UDP吞吐量和丢包测试
netperf -H 192.168.1.100 -t UDP_STREAM -l 60 -- \
    -m 1472 -R 1

# 不同速率测试
for rate in 10 50 100 500 1000; do
    echo "Testing ${rate} Mbps"
    netperf -H 192.168.1.100 -t UDP_STREAM -l 10
done
```

**预期结果:**
```
丢包率 < 0.1%:  优秀
丢包率 0.1-1%:  可接受
丢包率 > 1%:    需要优化
```

**应用评估:**
- 视频直播: 丢包率应<1%
- VoIP: 丢包率应<0.5%
- 在线游戏: 丢包率应<0.1%

### 场景5: 高延迟链路优化(WAN/Internet)

**目的:** 优化高延迟网络的TCP性能

**测试步骤:**

1. **测量RTT:**
```bash
ping -c 100 [目标IP]
# 记录平均RTT，假设为100ms
```

2. **计算BDP:**
```
BDP = 带宽 × RTT
示例: 1Gbps × 100ms = 100Mb = 12.5MB
建议TCP窗口大小 >= 12.5MB
```

3. **测试不同窗口大小:**
```bash
for window in 65536 131072 262144 524288 1048576; do
    echo "Testing window size: $window"
    netperf -H [目标IP] -t TCP_STREAM -l 30 -- \
        -s $window -S $window -m 64K
done
```

4. **应用优化:**
```bash
# 增大TCP缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# 启用BBR拥塞控制(适合高延迟)
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

### 场景6: 多核心系统性能优化

**目的:** 评估和优化多核心并发性能

**测试命令:**
```bash
# 并发连接测试
for count in 1 2 4 8 16; do
    echo "Testing with $count concurrent streams"
    for ((i=0; i<count; i++)); do
        netperf -H 192.168.1.100 -t TCP_STREAM -l 10 -- -m 64K &
    done
    wait
done
```

**预期结果:**
```
1个流:   900 Mbps   (基准)
2个流:   1800 Mbps  (2.0x)
4个流:   3600 Mbps  (4.0x)
8个流:   7200 Mbps  (8.0x)

理想: 线性扩展
实际: 70-90%效率
```

**优化措施:**
```bash
# 启用多队列网卡
ethtool -L eth0 combined 8

# 配置中断亲和性
# 将网卡中断分散到不同CPU核心
```

### 场景7: 虚拟化环境性能测试

**目的:** 评估虚拟化网络性能损失

**测试对比:**
```bash
# 物理机测试
netperf -H 物理服务器IP -t TCP_STREAM -l 30 -- -m 64K

# 虚拟机测试
netperf -H 虚拟机IP -t TCP_STREAM -l 30 -- -m 64K
```

**典型性能损失:**
```
Virtio网络:    5-15% 性能损失
SR-IOV:        < 5% 性能损失
桥接网络:      10-20% 性能损失
NAT网络:       20-40% 性能损失
```

**优化建议:**
- 使用virtio网络驱动
- 启用vhost-net内核加速
- 考虑SR-IOV直通
- 启用大页(Huge Pages)

## 性能基准参考

### 不同网络类型性能基准

| 网络类型 | TCP吞吐量 | TCP_RR(TPS) | TCP_CRR(Conn/s) | 延迟 |
|---------|----------|------------|----------------|------|
| Loopback | > 10 Gbps | > 100K | > 50K | < 0.01 ms |
| 1GbE | 900-950 Mbps | 20K-50K | 10K-20K | 0.05-0.2 ms |
| 10GbE | 9-9.5 Gbps | 50K-150K | 20K-50K | 0.02-0.1 ms |
| 100GbE | 90-95 Gbps | 100K-300K | 50K-100K | 0.01-0.05 ms |
| WiFi 6 | 300-800 Mbps | 5K-15K | 3K-8K | 1-10 ms |

### 不同CPU对网络性能影响

| CPU类型 | 1GbE性能 | 10GbE性能 | 延迟影响 |
|---------|---------|----------|---------|
| 低端双核 | 可跑满 | 3-5 Gbps | 中等 |
| 主流四核 | 可跑满 | 6-8 Gbps | 较低 |
| 高端八核+ | 可跑满 | 可跑满 | 很低 |

## 故障诊断

### 诊断流程图

```
性能问题
    ↓
┌─────────────────┐
│ TCP吞吐量低？     │
└────────┬────────┘
         ├─yes──> 检查TCP窗口大小
         │         检查网卡offload
         │         检查CPU使用率
         │
         ├─no
         ↓
┌─────────────────┐
│ TCP延迟高？      │
└────────┬────────┘
         ├─yes──> 检查RTT
         │         禁用Nagle算法
         │         检查中断延迟
         │
         ├─no
         ↓
┌─────────────────┐
│ UDP丢包？        │
└────────┬────────┘
         ├─yes──> 增大接收缓冲区
         │         检查网络拥塞
         │         限制发送速率
         │
         └─no──> 其他问题
```

### 常见问题诊断

**问题1: TCP吞吐量低**

诊断命令:
```bash
# 检查TCP窗口
ss -i | grep -E "cwnd|rcv_space"

# 检查网卡offload
ethtool -k eth0 | grep -E "tcp|generic"

# 检查CPU软中断
mpstat -P ALL 1
```

**问题2: 高延迟**

诊断命令:
```bash
# 测量RTT
ping -c 100 [目标IP]

# 检查Nagle算法
sysctl net.ipv4.tcp_nodelay

# 检查中断合并
ethtool -c eth0
```

**问题3: UDP丢包**

诊断命令:
```bash
# 查看丢包统计
netstat -su | grep -i "receive errors"

# 检查接收缓冲区
sysctl net.core.rmem_max
sysctl net.core.rmem_default

# 检查网络路径
mtr -r -c 100 [目标IP]
```

## 参考资料

- [Netperf官方文档](https://hewlettpackard.github.io/netperf/)
- [Netperf GitHub仓库](https://github.com/HewlettPackard/netperf)
- [Linux网络性能优化](https://www.kernel.org/doc/Documentation/networking/)
- [TCP性能调优指南](https://fasterdata.es.net/host-tuning/linux/)

---

**更新日期:** 2026-04-19
**版本:** 1.0
