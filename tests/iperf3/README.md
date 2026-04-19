# iperf3 网络性能测试

## 概述

iperf3是业界广泛使用的网络性能测试工具，用于测量TCP、UDP和SCTP协议的最大可用带宽。它是iperf2的完全重写版本，提供更简洁的代码库、更好的性能和更多功能。iperf3特别适合用于网络基础设施验收、性能调优、故障诊断和网络设备评估。

## 目录结构

```
iperf3/
├── README.md                       # 本文件
├── INTERPRETATION_GUIDE.md         # 结果详细解读指南
├── scripts/
│   ├── test_iperf3.sh              # 综合自动化测试脚本
│   └── iperf3_advanced.sh          # 高级测试场景脚本
└── results/                        # 测试结果目录（自动创建）
```

## iperf3测试原理

### 测试架构

```
Client                          Server
┌─────────────┐                ┌─────────────┐
│             │                │             │
│   iperf3    │────────────────>│  iperf3 -s  │
│  (客户端)    │<────────────────│  (服务端)   │
│             │                │             │
└─────────────┘                └─────────────┘
     │                              │
     ├─ 发送测试数据                 ├─ 接收测试数据
     ├─ 测量带宽/延迟                ├─ 返回统计信息
     ├─ 计算重传/丢包                ├─ 提供JSON输出
     └─ 生成测试报告                 └─ 支持多客户端
```

### 核心测试类型

#### 1. TCP带宽测试（默认）

**原理:**
```
发送端                        接收端
  │                            │
  │──── 数据流(持续) ─────────>│
  │──── 数据流(持续) ─────────>│
  │──── 数据流(持续) ─────────>│
  │                            │
  └─测量: Bitrate (Mbps/Gbps)
  └─统计: Retransmits (重传次数)
```

**关键指标:**
- **Bitrate**: 吞吐量（Mbps或Gbps）
- **Retransmits**: TCP重传次数（网络质量指标）
- **Cwnd**: 拥塞窗口大小（TCP性能指标）

**应用场景:**
- 网络带宽验收测试
- 文件传输性能评估
- 视频流服务器容量规划
- 网络升级效果验证

#### 2. UDP带宽测试（-u参数）

**原理:**
```
发送端                        接收端
  │                            │
  │═══ UDP包(无连接) ═══════>│
  │═══ UDP包(无连接) ═══════>│
  │═══ UDP包(无连接) ═══════>│
  │                            │
  └─测量: Bitrate, Jitter
  └─统计: Lost/Total (丢包率)
```

**关键指标:**
- **Bitrate**: UDP吞吐量
- **Jitter**: 抖动（延迟变化）
- **Lost/Total**: 丢包率（关键质量指标）

**应用场景:**
- 视频直播性能测试
- VoIP语音质量评估
- 在线游戏网络测试
- 实时流媒体评估

#### 3. 双向同时测试（--bidir参数）

**原理:**
```
同时测试上行和下行带宽
评估全双工性能
检测链路对称性
```

**关键用途:**
- 全双工链路验证
- 对称性带宽测试
- 交换机性能评估

#### 4. 多流并发测试（-P参数）

**原理:**
```
并发多个TCP/UDP流
测试多核心扩展性
评估聚合带宽
```

**关键用途:**
- 多核心CPU性能测试
- 负载均衡效果验证
- 网卡多队列性能评估

## 与iperf2的主要区别

| 特性 | iperf2 | iperf3 |
|------|--------|--------|
| 代码库 | 较旧 | 完全重写 |
| JSON输出 | 不支持 | **支持** ✓ |
| 双向同时测试 | 需两个实例 | **单命令** ✓ |
| 反向测试 | 复杂 | **简单(-R)** ✓ |
| UDP目标带宽 | 支持 | 支持 |
| TCP窗口大小 | 支持 | 支持 |
| 零拷贝(sendfile) | 不支持 | **支持(-Z)** ✓ |
| 协议支持 | TCP/UDP/SCTP | TCP/UDP/SCTP |
| 多客户端同时连接 | 支持 | 不支持 |

**推荐:** 新项目使用iperf3，旧项目可继续使用iperf2

## 前置条件

### 系统要求

- Linux/Unix操作系统（推荐）
- macOS（通过Homebrew）
- Windows（通过Cygwin或WSL）
- 客户端和服务器之间网络连通

### 安装iperf3

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install iperf3
```

**RHEL/CentOS/Rocky Linux 8+:**
```bash
sudo dnf install iperf3
```

**Fedora:**
```bash
sudo dnf install iperf3
```

**macOS:**
```bash
brew install iperf3
```

**源码编译:**
```bash
git clone https://github.com/esnet/iperf.git
cd iperf
./configure
make
sudo make install
```

**验证安装:**
```bash
iperf3 --version
# 输出: iperf 3.x.x (或更高版本)
```

### 启动iperf3服务器

**基本启动:**
```bash
# 前台运行（默认端口5201）
iperf3 -s

# 后台运行（推荐）
iperf3 -s -D

# 指定端口
iperf3 -s -p 5201

# 绑定特定IP（多网卡情况）
iperf3 -s -B 192.168.1.100
```

**设置开机自启（Systemd）:**
```bash
sudo tee /etc/systemd/system/iperf3.service <<EOF
[Unit]
Description=iperf3 server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/iperf3 -s
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable iperf3
sudo systemctl start iperf3
```

**防火墙配置:**
```bash
# firewalld
sudo firewall-cmd --permanent --add-port=5201/tcp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport 5201 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 5201 -j ACCEPT
```

## 运行测试

### 快速开始

**基本用法:**
```bash
# 客户端连接到服务器
iperf3 -c <服务器IP>

# 示例
iperf3 -c 192.168.1.100
```

**常用参数:**
```bash
# TCP带宽测试（10秒）
iperf3 -c 192.168.1.100 -t 10

# UDP带宽测试（目标1Gbps）
iperf3 -c 192.168.1.100 -u -b 1G

# 反向测试（服务器→客户端）
iperf3 -c 192.168.1.100 -R

# 双向同时测试
iperf3 -c 192.168.1.100 --bidir

# 多流并发测试（8个流）
iperf3 -c 192.168.1.100 -P 8

# JSON格式输出
iperf3 -c 192.168.1.100 -J
```

### 自动化测试脚本

**综合测试（推荐）:**
```bash
cd scripts
./test_iperf3.sh [服务器IP] [测试时长]

# 本地环回测试
./test_iperf3.sh localhost

# 远程服务器测试（默认10秒）
./test_iperf3.sh 192.168.1.100

# 远程服务器测试（指定60秒）
./test_iperf3.sh 192.168.1.100 60
```

自动执行以下测试:
1. ✓ TCP上行带宽测试
2. ✓ TCP下行带宽测试
3. ✓ UDP带宽和丢包测试
4. ✓ 双向同时测试（全双工）
5. ✓ 多流并发测试（1/2/4/8流）

**高级测试场景:**
```bash
./iperf3_advanced.sh [服务器IP] [测试时长]

# 示例：对192.168.1.100进行30秒高级测试
./iperf3_advanced.sh 192.168.1.100 30
```

高级测试包括:
1. TCP窗口大小优化测试（64K-4M）
2. MSS大小测试（536-8960字节）
3. 拥塞控制算法对比（cubic/reno/bbr）
4. UDP不同带宽目标测试（10M-1G）
5. 长时间稳定性测试（5分钟）
6. IPv6性能测试
7. 零拷贝性能测试
8. 逐秒统计测试

## 典型测试场景

### 场景1: 网络验收测试

**目的:** 验证新网络是否达到预期带宽

**测试步骤:**
```bash
# 1. 启动服务器
ssh server "iperf3 -s -D"

# 2. 单向TCP测试（60秒）
iperf3 -c 192.168.1.100 -t 60

# 3. 反向TCP测试
iperf3 -c 192.168.1.100 -R -t 60

# 4. 双向测试
iperf3 -c 192.168.1.100 --bidir -t 60
```

**验收标准:**
```
1GbE网络:   ≥ 930 Mbps  (93%线速)
10GbE网络:  ≥ 9300 Mbps (93%线速)
100GbE网络: ≥ 93000 Mbps (93%线速)
```

### 场景2: TCP窗口优化

**目的:** 找到最优TCP窗口大小（特别是高延迟网络）

**测试步骤:**
```bash
# 测试不同窗口大小
for window in 64K 128K 256K 512K 1M 2M 4M; do
    echo "Testing window size: $window"
    iperf3 -c 192.168.1.100 -w $window -t 10
done
```

**BDP（带宽延迟乘积）计算:**
```
BDP = 带宽 × RTT

示例:
  1Gbps网络，RTT=100ms
  BDP = 1000Mbps × 0.1s = 100Mb = 12.5MB
  建议窗口大小 >= 12.5MB
```

### 场景3: UDP实时流媒体测试

**目的:** 评估UDP传输质量（丢包率和抖动）

**测试步骤:**
```bash
# 测试不同目标带宽的丢包情况
for rate in 10M 50M 100M 500M 1G; do
    echo "Testing at $rate"
    iperf3 -c 192.168.1.100 -u -b $rate -t 10
done
```

**评估标准:**
```
视频直播:  丢包率 < 1%,   抖动 < 20ms
VoIP:      丢包率 < 0.5%, 抖动 < 5ms
在线游戏:  丢包率 < 0.1%, 抖动 < 1ms
```

### 场景4: 多核心性能测试

**目的:** 评估多核心并发性能和扩展性

**测试步骤:**
```bash
# 测试不同流数量的聚合带宽
for streams in 1 2 4 8 16; do
    echo "Testing with $streams streams"
    iperf3 -c 192.168.1.100 -P $streams -t 10
done
```

**扩展性评估:**
```
理想情况: 聚合带宽 = 单流带宽 × 流数量
实际情况: 70-90%效率是正常的

示例:
  单流: 940 Mbps
  8流:  7200 Mbps (效率 = 7200 / (940×8) = 95.7%)
```

### 场景5: 零拷贝性能对比

**目的:** 评估零拷贝(sendfile)带来的性能提升

**测试步骤:**
```bash
# 标准传输
iperf3 -c 192.168.1.100 -t 10

# 零拷贝传输
iperf3 -c 192.168.1.100 -Z -t 10
```

**预期提升:**
```
典型提升: 5-15%
高带宽网络(10GbE+): 10-20%
```

## 参数详解

### 基本参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-c <host>` | 客户端模式，连接到服务器 | `-c 192.168.1.100` |
| `-s` | 服务器模式 | `-s` |
| `-p <port>` | 服务器端口（默认5201） | `-p 5201` |
| `-t <time>` | 测试时长（秒，默认10） | `-t 60` |
| `-i <interval>` | 统计输出间隔（秒，默认1） | `-i 5` |

### TCP测试参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-w <size>` | TCP窗口大小 | `-w 1M` |
| `-M <mss>` | TCP最大段大小(MSS) | `-M 1460` |
| `-C <algo>` | TCP拥塞控制算法 | `-C bbr` |
| `-Z` | 零拷贝模式(sendfile) | `-Z` |

### UDP测试参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-u` | UDP模式 | `-u` |
| `-b <bandwidth>` | 目标带宽（支持K/M/G） | `-b 1G` |
| `-l <length>` | 数据包大小（字节） | `-l 1472` |

### 高级参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-R` | 反向测试（服务器发送） | `-R` |
| `--bidir` | 双向同时测试 | `--bidir` |
| `-P <num>` | 并发流数量 | `-P 8` |
| `-J` | JSON格式输出 | `-J` |
| `-4` | 仅使用IPv4 | `-4` |
| `-6` | 仅使用IPv6 | `-6` |
| `-B <ip>` | 绑定到特定IP | `-B 192.168.1.10` |
| `-D` | 服务器后台运行（守护进程） | `-D` |

## 性能基准参考

### 不同网络类型性能基准

| 网络类型 | 理论带宽 | 实际可达 | 达成率 | TCP重传 |
|---------|---------|---------|--------|---------|
| Loopback | > 10 Gbps | 10-40 Gbps | - | 0 |
| 100Mbps | 100 Mbps | 90-95 Mbps | 90-95% | < 10 |
| 1GbE | 1000 Mbps | 930-950 Mbps | 93-95% | < 10 |
| 10GbE | 10000 Mbps | 9300-9500 Mbps | 93-95% | < 10 |
| 100GbE | 100000 Mbps | 93000-95000 Mbps | 93-95% | < 10 |

### 不同场景UDP丢包率参考

| 应用场景 | 可接受丢包率 | 推荐丢包率 | 抖动要求 |
|---------|------------|-----------|---------|
| 视频直播 | < 1% | < 0.5% | < 20 ms |
| VoIP | < 0.5% | < 0.1% | < 5 ms |
| 在线游戏 | < 0.1% | < 0.01% | < 1 ms |
| 文件传输 | 不可接受 | 使用TCP | - |

## 故障诊断

### 问题1: TCP带宽远低于预期

**症状:** 1GbE网络只有200Mbps

**诊断步骤:**
```bash
# 1. 检查TCP窗口大小
ss -i | grep -E "cwnd|rcv_space"

# 2. 测量RTT
ping -c 100 [目标IP]

# 3. 计算BDP
# BDP = 带宽 × RTT
# 窗口应 >= BDP

# 4. 检查网卡offload
ethtool -k eth0 | grep -E "tcp|generic"

# 5. 检查CPU软中断
mpstat -P ALL 1
```

**解决方案:**
```bash
# 增大TCP缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# 启用网卡offload
ethtool -K eth0 tso on gso on gro on

# 使用BBR拥塞控制
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

### 问题2: UDP严重丢包

**症状:** 丢包率 > 5%

**诊断步骤:**
```bash
# 1. 检查接收缓冲区
netstat -su | grep "receive buffer errors"

# 2. 检查发送速率
# 是否超过链路带宽？

# 3. 检查网络路径
mtr -r -c 100 [目标IP]
```

**解决方案:**
```bash
# 增大UDP接收缓冲区
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.rmem_default=33554432

# 降低目标带宽
iperf3 -c [IP] -u -b 500M  # 而不是1G

# 增加网络队列
sysctl -w net.core.netdev_max_backlog=10000
```

### 问题3: 测试结果波动大

**症状:** 多次测试结果差异 > 20%

**原因分析:**
- 网络拥塞（共享带宽）
- CPU负载波动
- 其他流量干扰
- 无线网络信号波动

**解决方案:**
```bash
# 1. 增加测试时长
iperf3 -c [IP] -t 60  # 而不是10秒

# 2. 多次测试取平均
for i in {1..5}; do
    iperf3 -c [IP] -t 30
done

# 3. 监控系统资源
mpstat -P ALL 1 &
iperf3 -c [IP] -t 30
```

## JSON输出解析

### 提取关键指标

**带宽:**
```bash
iperf3 -c 192.168.1.100 -J | \
    jq '.end.sum_sent.bits_per_second / 1000000'
# 输出: 941.23 (Mbps)
```

**重传次数:**
```bash
iperf3 -c 192.168.1.100 -J | \
    jq '.end.sum_sent.retransmits'
# 输出: 3
```

**UDP丢包率:**
```bash
iperf3 -c 192.168.1.100 -u -b 1G -J | \
    jq '(.end.sum.lost_packets / .end.sum.packets) * 100'
# 输出: 0.048 (%)
```

**Python解析示例:**
```python
import json
import subprocess

result = subprocess.run(['iperf3', '-c', '192.168.1.100', '-J'],
                       capture_output=True, text=True)
data = json.loads(result.stdout)

bandwidth_mbps = data['end']['sum_sent']['bits_per_second'] / 1e6
retransmits = data['end']['sum_sent']['retransmits']

print(f"带宽: {bandwidth_mbps:.2f} Mbps")
print(f"重传: {retransmits} 次")
```

## 与Netperf对比

| 特性 | iperf3 | Netperf |
|------|--------|---------|
| **易用性** | ★★★★★ 非常简单 | ★★★☆☆ 较复杂 |
| **JSON输出** | ✓ 支持 | ✗ 不支持 |
| **双向测试** | ✓ 单命令 | ✗ 需分别测试 |
| **实时统计** | ✓ 逐秒输出 | ✗ 仅最终结果 |
| **测试类型** | TCP/UDP | TCP/UDP/RR/CRR等 |
| **延迟测试** | ✗ 不支持 | ✓ TCP_RR |
| **连接测试** | ✗ 不支持 | ✓ TCP_CRR |
| **成熟度** | 较新 | 非常成熟 |
| **社区支持** | 活跃 | 较少更新 |

**使用建议:**
- **带宽测试:** 优先使用iperf3（简单直观）
- **延迟测试:** 使用Netperf TCP_RR
- **连接测试:** 使用Netperf TCP_CRR
- **自动化:** iperf3的JSON输出更友好

## 最佳实践

### 测试前准备

1. **确保网络空闲**
   - 避免其他大流量应用运行
   - 选择非高峰时段

2. **优化系统参数**
   ```bash
   # 应用推荐的sysctl参数
   sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
   sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
   sysctl -w net.ipv4.tcp_congestion_control=bbr
   ```

3. **检查硬件状态**
   ```bash
   # 检查网卡速率
   ethtool eth0 | grep Speed

   # 检查CPU频率（避免省电模式）
   cpupower frequency-info
   ```

### 测试中监控

```bash
# 终端1: 运行iperf3
iperf3 -c 192.168.1.100 -t 60

# 终端2: 监控CPU
mpstat -P ALL 1

# 终端3: 监控网络
watch -n1 'ifconfig eth0 | grep -E "RX|TX"'
```

### 测试后分析

1. **检查重传次数**
   - TCP重传应 < 10次（10秒测试）
   - 大量重传说明网络质量差

2. **对比理论带宽**
   - 实际带宽应 >= 理论带宽 × 90%
   - 低于80%需要排查问题

3. **多次测试验证**
   - 至少测试3次
   - 取平均值和标准差

## 参考资料

- [iperf3官方文档](https://software.es.net/iperf/)
- [iperf3 GitHub仓库](https://github.com/esnet/iperf)
- [TCP性能调优](https://fasterdata.es.net/host-tuning/linux/)
- [网络性能测试最佳实践](https://fasterdata.es.net/network-tuning/)

## 相关工具

- **Netperf**: 更全面的网络性能测试（支持延迟测试）
- **qperf**: RDMA和Socket性能测试
- **nuttcp**: 类似iperf的网络测试工具
- **fio**: I/O性能测试（可测试网络文件系统）

---

**更新日期:** 2026-04-19
**版本:** 1.0
