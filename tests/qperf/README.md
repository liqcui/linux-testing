# qperf RDMA和Socket性能测试

## 概述

qperf是一个专业的网络性能测试工具，由OpenFabrics Alliance开发。它不仅支持传统的TCP/UDP/SCTP Socket性能测试，更重要的是提供全面的**RDMA（Remote Direct Memory Access）性能测试**能力。qperf特别适合评估高性能计算(HPC)环境、InfiniBand网络、RoCE网络以及需要超低延迟的应用场景。

## 目录结构

```
qperf/
├── README.md                       # 本文件
├── INTERPRETATION_GUIDE.md         # 结果详细解读指南
├── scripts/
│   ├── test_qperf.sh               # 综合自动化测试脚本
│   └── qperf_advanced.sh           # 高级测试场景脚本
└── results/                        # 测试结果目录（自动创建）
```

## qperf测试原理

### 测试架构

```
Client                          Server
┌─────────────┐                ┌─────────────┐
│             │                │             │
│   qperf     │────────────────>│   qperf     │
│  (客户端)    │<────────────────│  (服务端)   │
│             │                │             │
└─────────────┘                └─────────────┘
     │                              │
     ├─ Socket测试                  ├─ 接收测试数据
     │  · TCP带宽/延迟               │  · 返回统计信息
     │  · UDP带宽/延迟               │  · 提供CPU使用率
     │  · SCTP测试                  │
     │                              │
     ├─ RDMA测试（需硬件支持）       │
     │  · RC/UC/UD带宽              │
     │  · RDMA延迟                  │
     │  · 零拷贝性能                │
     └─ 生成测试报告                 └─ 详细性能数据
```

### 核心测试类型

#### 1. Socket性能测试

**TCP测试:**
```
tcp_bw:  TCP带宽测试（吞吐量）
tcp_lat: TCP延迟测试（请求响应时延）
```

**UDP测试:**
```
udp_bw:  UDP带宽测试（吞吐量和丢包）
udp_lat: UDP延迟测试（往返时延）
```

**SCTP测试:**
```
sctp_bw:  SCTP带宽测试（消息流传输）
sctp_lat: SCTP延迟测试
```

**关键指标:**
- **bw**: 带宽（MB/sec）
- **latency**: 延迟（μs或ms）
- **cpus_used**: CPU使用率（%）
- **msg_rate**: 消息速率（K/sec）

**应用场景:**
- 网络基础设施验收
- 应用性能调优
- 容量规划
- 故障诊断

#### 2. RDMA性能测试（需要RDMA硬件）

**RDMA传输类型:**

```
RC (Reliable Connection):     可靠连接，类似TCP
    rc_bw:  RDMA RC带宽测试
    rc_lat: RDMA RC延迟测试

UC (Unreliable Connection):   不可靠连接，有序传输
    uc_bw:  RDMA UC带宽测试
    uc_lat: RDMA UC延迟测试

UD (Unreliable Datagram):     不可靠数据报，类似UDP
    ud_bw:  RDMA UD带宽测试
    ud_lat: RDMA UD延迟测试
```

**RDMA技术对比:**

| 技术 | 物理层 | 典型带宽 | 典型延迟 | 部署场景 |
|------|--------|---------|---------|---------|
| **InfiniBand** | 专用IB网络 | 100-400 Gbps | < 1 μs | HPC、超算 |
| **RoCE v2** | 以太网 | 40-200 Gbps | 1-3 μs | 云数据中心 |
| **iWARP** | 以太网 | 40-100 Gbps | 2-5 μs | 企业存储 |

**RDMA关键优势:**

1. **零拷贝(Zero-Copy)**
   ```
   传统Socket: 应用 → 用户缓冲 → 内核缓冲 → 网卡
   RDMA:       应用 → 网卡 (直接DMA)
   ```

2. **内核旁路(Kernel Bypass)**
   ```
   传统Socket: 需要经过内核协议栈
   RDMA:       绕过内核，用户空间直接访问网卡
   ```

3. **CPU卸载(CPU Offload)**
   ```
   传统Socket: CPU处理协议栈（高CPU开销）
   RDMA:       网卡硬件处理（CPU几乎无负载）
   ```

**性能提升:**
```
带宽:     10-100倍提升（相比TCP）
延迟:     20-100倍降低（1-2 μs vs 30-100 μs）
CPU开销:  10-100倍降低（< 10% vs 50-100%）
```

**RDMA应用场景:**
- 高性能计算(HPC)
- 分布式存储系统
- 数据库集群（RAMCloud、Redis）
- 机器学习训练集群
- 高频交易系统
- 实时数据分析

## 与其他工具的区别

### qperf vs iperf3

| 特性 | qperf | iperf3 |
|------|-------|--------|
| **RDMA支持** | ★★★★★ 完整支持 | ✗ 不支持 |
| **延迟测试** | ★★★★★ 专业 | ✗ 不支持 |
| **CPU统计** | ★★★★★ 详细 | ✗ 不支持 |
| **带宽测试** | ★★★★☆ 支持 | ★★★★★ 优秀 |
| **易用性** | ★★★☆☆ 中等 | ★★★★★ 简单 |
| **JSON输出** | ✗ 不支持 | ★★★★★ 支持 |
| **双向测试** | ✗ 需分别测试 | ★★★★★ 支持 |

**使用建议:**
- **RDMA测试**: 必须使用qperf
- **延迟测试**: 优先使用qperf或netperf
- **带宽测试**: iperf3更简单直观
- **CPU分析**: 使用qperf

### qperf vs netperf

| 特性 | qperf | netperf |
|------|-------|---------|
| **RDMA支持** | ★★★★★ 完整 | ✗ 不支持 |
| **延迟测试** | ★★★★★ 优秀 | ★★★★★ 优秀 |
| **测试类型** | Socket + RDMA | 丰富（RR/CRR等） |
| **CPU统计** | ★★★★★ 详细 | ★★★☆☆ 基本 |
| **易用性** | ★★★★☆ 较好 | ★★★☆☆ 中等 |

**使用建议:**
- **RDMA环境**: 使用qperf
- **TCP_RR/CRR测试**: netperf更专业
- **通用场景**: 都可以使用

## 前置条件

### 系统要求

**基本要求:**
- Linux操作系统（RHEL/CentOS/Ubuntu/Debian）
- 网络连通性（客户端和服务器能互相访问）

**RDMA要求（可选）:**
- RDMA网卡（InfiniBand/RoCE/iWARP）
- RDMA驱动（OFED或inbox驱动）
- 配置好的RDMA网络

### 安装qperf

**RHEL/CentOS/Rocky Linux:**
```bash
sudo yum install qperf
```

**Fedora:**
```bash
sudo dnf install qperf
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install qperf
```

**源码编译:**
```bash
git clone https://github.com/linux-rdma/qperf.git
cd qperf
./autogen.sh
./configure
make
sudo make install
```

**验证安装:**
```bash
qperf --version
# 或
qperf --help
```

### RDMA环境配置（如需RDMA测试）

**1. 安装RDMA驱动:**

**RHEL/CentOS:**
```bash
# 安装OFED驱动
sudo yum install rdma-core libibverbs libibverbs-utils
sudo yum install infiniband-diags perftest

# 启动RDMA服务
sudo systemctl start rdma
sudo systemctl enable rdma
```

**Ubuntu:**
```bash
sudo apt-get install rdma-core ibverbs-utils
sudo apt-get install infiniband-diags perftest
```

**2. 验证RDMA设备:**
```bash
# 列出RDMA设备
ibstat

# 应该看到类似输出:
# CA 'mlx5_0'
#     CA type: MT4115
#     Number of ports: 1
#     Firmware version: 12.28.2006
#     Hardware version: 0
#     Port 1:
#         State: Active
#         Physical state: LinkUp
#         Rate: 100
#         Base lid: 1
#         SM lid: 1
#         Capability mask: 0x2651e848
#         Port GUID: 0x248a0703001a7480
```

**3. 配置IP over IB（如果使用InfiniBand）:**
```bash
# 配置IPoIB接口
sudo ip link set ib0 up
sudo ip addr add 192.168.100.1/24 dev ib0

# 永久配置（RHEL/CentOS）
sudo tee /etc/sysconfig/network-scripts/ifcfg-ib0 <<EOF
DEVICE=ib0
TYPE=InfiniBand
ONBOOT=yes
BOOTPROTO=static
IPADDR=192.168.100.1
NETMASK=255.255.255.0
CONNECTED_MODE=yes
EOF

# 重启网络
sudo systemctl restart network
```

**4. 测试RDMA连接:**
```bash
# 服务器端
ibv_rc_pingpong

# 客户端
ibv_rc_pingpong <server_ip>

# 如果成功，说明RDMA工作正常
```

### 启动qperf服务器

**基本启动:**
```bash
# 前台运行（默认端口19765）
qperf

# 后台运行
qperf &

# 指定监听地址
qperf -l 192.168.1.100
```

**设置开机自启（Systemd）:**
```bash
sudo tee /etc/systemd/system/qperf.service <<EOF
[Unit]
Description=qperf network performance server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/qperf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable qperf
sudo systemctl start qperf
```

**防火墙配置:**
```bash
# firewalld
sudo firewall-cmd --permanent --add-port=19765/tcp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport 19765 -j ACCEPT
```

## 运行测试

### 快速开始

**基本用法:**
```bash
# 客户端连接到服务器
qperf <服务器IP> <测试类型>

# 示例
qperf 192.168.1.100 tcp_bw
```

**常用测试命令:**
```bash
# TCP带宽测试（10秒，默认）
qperf 192.168.1.100 tcp_bw

# TCP延迟测试
qperf 192.168.1.100 tcp_lat

# UDP带宽和延迟测试
qperf 192.168.1.100 udp_bw udp_lat

# RDMA RC带宽和延迟测试（需要RDMA硬件）
qperf 192.168.1.100 rc_bw rc_lat

# 显示详细信息（包括CPU使用率）
qperf 192.168.1.100 -v tcp_bw tcp_lat

# 指定测试时长（秒）
qperf 192.168.1.100 -t 60 tcp_bw

# 指定消息大小
qperf 192.168.1.100 -oo msg_size:65536 tcp_bw
```

### 自动化测试脚本

**综合测试（推荐）:**
```bash
cd scripts
./test_qperf.sh [服务器IP] [测试时长]

# 本地环回测试
./test_qperf.sh localhost

# 远程服务器测试（默认10秒）
./test_qperf.sh 192.168.1.100

# 远程服务器测试（指定60秒）
./test_qperf.sh 192.168.1.100 60
```

自动执行以下测试:
1. ✓ TCP带宽测试（tcp_bw）
2. ✓ TCP延迟测试（tcp_lat）
3. ✓ UDP带宽测试（udp_bw）
4. ✓ UDP延迟测试（udp_lat）
5. ✓ SCTP带宽测试（sctp_bw）
6. ✓ 不同消息大小性能测试
7. ✓ RDMA性能测试（如果检测到RDMA设备）

**高级测试场景:**
```bash
./qperf_advanced.sh [服务器IP] [测试时长]

# 示例：对192.168.1.100进行30秒高级测试
./qperf_advanced.sh 192.168.1.100 30
```

高级测试包括:
1. Socket缓冲区大小优化测试
2. TCP vs UDP性能对比
3. 延迟分布测试
4. 带宽和CPU使用率关系测试
5. RDMA深度性能测试（RC/UC/UD对比）
6. 双向同时传输测试
7. SCTP vs TCP性能对比

## 典型测试场景

### 场景1: 网络基础性能测试

**目的:** 评估网络基本性能指标

**测试步骤:**
```bash
# 1. 启动服务器
ssh server "qperf &"

# 2. TCP性能测试
qperf 192.168.1.100 -v tcp_bw tcp_lat

# 3. UDP性能测试
qperf 192.168.1.100 -v udp_bw udp_lat

# 4. 分析结果
# - 带宽是否达到网络容量？
# - 延迟是否在合理范围？
# - CPU使用率是否正常？
```

**性能基准:**
```
1GbE网络:
  tcp_bw:  110-117 MB/s
  tcp_lat: 30-100 μs
  CPU:     5-15%

10GbE网络:
  tcp_bw:  1100-1170 MB/s
  tcp_lat: 10-50 μs
  CPU:     30-60%
```

### 场景2: RDMA性能评估

**目的:** 评估RDMA网络性能和优势

**前提条件:**
- InfiniBand或RoCE网络
- 已安装RDMA驱动
- 已验证RDMA设备正常

**测试步骤:**
```bash
# 1. 验证RDMA设备
ibstat

# 2. TCP基准测试
qperf 192.168.100.2 -v tcp_bw tcp_lat

# 记录结果作为对比基准

# 3. RDMA RC测试
qperf 192.168.100.2 -v rc_bw rc_lat

# 4. RDMA UC测试
qperf 192.168.100.2 -v uc_bw uc_lat

# 5. RDMA UD测试
qperf 192.168.100.2 -v ud_bw ud_lat

# 6. 性能对比分析
```

**预期结果（InfiniBand FDR）:**
```
TCP:
  tcp_bw:  1170 MB/s
  tcp_lat: 30 μs
  CPU:     50%

RDMA RC:
  rc_bw:   6500 MB/s  (5.5倍提升)
  rc_lat:  1.2 μs     (25倍降低)
  CPU:     8%         (6倍降低)
```

### 场景3: 数据库网络延迟测试

**目的:** 评估数据库查询网络延迟

**测试步骤:**
```bash
# 1. 小消息延迟测试（模拟查询）
qperf 192.168.1.100 -v -oo msg_size:256 tcp_lat

# 2. 中等消息延迟测试（模拟带数据查询）
qperf 192.168.1.100 -v -oo msg_size:4096 tcp_lat

# 3. 大消息延迟测试（模拟大结果集）
qperf 192.168.1.100 -v -oo msg_size:65536 tcp_lat
```

**延迟评估:**
```
< 50 μs:   ★★★★★ 优秀 - 适合OLTP高并发
50-100 μs: ★★★★☆ 良好 - 标准数据库查询
100-200 μs:★★★☆☆ 一般 - 可接受
> 200 μs:  需要优化
```

### 场景4: 视频流传输性能测试

**目的:** 评估UDP视频流传输质量

**测试步骤:**
```bash
# 1. UDP带宽测试（模拟高清视频）
qperf 192.168.1.100 -v -t 30 udp_bw

# 2. 检查丢包情况
# 对比 send_bw 和 recv_bw

# 3. UDP延迟测试
qperf 192.168.1.100 -v udp_lat

# 4. 不同消息大小测试（模拟不同码率）
for size in 1K 4K 8K 16K; do
    echo "Testing message size: $size"
    qperf 192.168.1.100 -oo msg_size:$size -t 10 udp_bw
done
```

**质量评估:**
```
丢包率:
  < 0.1%:  ★★★★★ 完美 - 4K视频流
  0.1-1%:  ★★★★☆ 良好 - 1080p视频
  1-3%:    ★★★☆☆ 可接受 - 720p视频
  > 3%:    需要优化
```

### 场景5: CPU效率分析

**目的:** 评估网络处理的CPU效率

**测试步骤:**
```bash
# 1. 不同消息大小的CPU效率
for size in 1K 4K 16K 64K; do
    echo "Testing message size: $size"
    qperf 192.168.1.100 -oo msg_size:$size -v tcp_bw
done

# 2. 计算每%CPU的带宽
# 效率 = bw / send_cpus_used
```

**效率评估:**
```
> 50 MB/s per %CPU:  ★★★★★ 卓越 - RDMA级别
20-50:               ★★★★☆ 优秀 - 高效offload
10-20:               ★★★☆☆ 良好 - 标准配置
5-10:                ★★☆☆☆ 一般 - 需要优化
< 5:                 ★☆☆☆☆ 较低 - CPU瓶颈
```

### 场景6: Socket缓冲区优化

**目的:** 找到最优Socket缓冲区大小

**测试步骤:**
```bash
# 测试不同消息大小
for size in 1K 4K 16K 64K 256K; do
    echo "Testing buffer size: $size"
    qperf 192.168.1.100 -oo msg_size:$size -t 10 -v tcp_bw
done

# 分析结果，找到带宽最高、CPU最低的配置
```

**优化建议:**
```
低延迟应用:  使用小缓冲区（1-4 KB）
高吞吐应用:  使用大缓冲区（64 KB+）
平衡配置:    使用中等缓冲区（16-32 KB）
```

### 场景7: RDMA传输类型选择

**目的:** 选择最适合的RDMA传输类型

**测试步骤:**
```bash
# 1. RC测试（可靠连接）
echo "Testing RDMA RC..."
qperf 192.168.100.2 -v rc_bw rc_lat

# 2. UC测试（不可靠连接）
echo "Testing RDMA UC..."
qperf 192.168.100.2 -v uc_bw uc_lat

# 3. UD测试（不可靠数据报）
echo "Testing RDMA UD..."
qperf 192.168.100.2 -v ud_bw ud_lat
```

**选择建议:**

| 应用场景 | 推荐类型 | 原因 |
|---------|---------|------|
| 分布式存储 | RC | 需要可靠性和顺序保证 |
| 数据库复制 | RC | 数据一致性要求 |
| HPC计算 | UC或RC | 高带宽，可容忍少量丢失 |
| 服务发现 | UD | 组播支持 |
| 低延迟消息 | UD | 最低延迟 |

## 参数详解

### 基本参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-t <time>` | 测试时长（秒，默认10） | `-t 60` |
| `-v` | 显示详细信息（包括CPU） | `-v` |
| `-l <addr>` | 服务器监听地址 | `-l 0.0.0.0` |
| `-lp <port>` | 服务器监听端口（默认19765） | `-lp 12345` |
| `-oo <opts>` | 测试选项 | `-oo msg_size:64K` |

### 测试类型

**Socket测试:**
```
tcp_bw      TCP带宽测试
tcp_lat     TCP延迟测试
udp_bw      UDP带宽测试
udp_lat     UDP延迟测试
sctp_bw     SCTP带宽测试
sctp_lat    SCTP延迟测试
```

**RDMA测试（需要RDMA硬件）:**
```
rc_bw       RDMA RC带宽测试
rc_lat      RDMA RC延迟测试
uc_bw       RDMA UC带宽测试
uc_lat      RDMA UC延迟测试
ud_bw       RDMA UD带宽测试
ud_lat      RDMA UD延迟测试
```

### 高级选项（-oo参数）

```bash
# 消息大小
-oo msg_size:64K

# Socket缓冲区大小
-oo sock_buf_size:1M

# 发送/接收缓冲区
-oo send_buf_size:2M
-oo recv_buf_size:2M

# 消息数量
-oo msg_count:10000

# CPU亲和性
-oo loc_cpu:0
-oo rem_cpu:1
```

## 性能基准参考

### Socket性能基准

| 网络类型 | TCP带宽 | TCP延迟 | UDP带宽 | CPU(%) |
|---------|--------|---------|---------|--------|
| Loopback | 5-10 GB/s | 5-20 μs | 3-8 GB/s | 30-60 |
| 1GbE | 110-117 MB/s | 30-100 μs | 110-117 MB/s | 5-15 |
| 10GbE | 1100-1170 MB/s | 10-50 μs | 1100-1170 MB/s | 30-60 |
| 100GbE | 11000-11700 MB/s | 5-20 μs | 11000-11700 MB/s | 60-100 |

### RDMA性能基准

| RDMA类型 | 带宽 | 延迟 | CPU(%) |
|---------|------|------|--------|
| IB FDR (56G) RC | 6000-6500 MB/s | 0.7-1.5 μs | 3-8 |
| IB EDR (100G) RC | 11500-12500 MB/s | 0.5-1.2 μs | 5-10 |
| RoCE v2 50G | 5500-6000 MB/s | 1.5-3 μs | 8-15 |
| RoCE v2 100G | 11000-12000 MB/s | 1-2.5 μs | 10-20 |

### RDMA vs TCP性能对比

| 指标 | TCP (10GbE) | RDMA RC (IB FDR) | 提升倍数 |
|------|------------|-----------------|---------|
| 带宽 | 1170 MB/s | 6500 MB/s | 5.6x |
| 延迟 | 30 μs | 1.2 μs | 25x降低 |
| CPU | 50% | 8% | 6x降低 |

## 故障诊断

### 问题1: qperf连接失败

**症状:**
```
qperf: unable to connect to 192.168.1.100:19765
```

**诊断步骤:**
```bash
# 1. 检查服务器是否运行qperf
ssh server "pgrep qperf"

# 2. 检查网络连通性
ping 192.168.1.100

# 3. 检查端口
telnet 192.168.1.100 19765

# 4. 检查防火墙
sudo firewall-cmd --list-all
```

**解决方案:**
```bash
# 启动qperf服务器
ssh server "qperf &"

# 开放防火墙端口
sudo firewall-cmd --permanent --add-port=19765/tcp
sudo firewall-cmd --reload
```

### 问题2: RDMA测试失败

**症状:**
```
qperf: rc_bw: error: operation not supported
```

**诊断步骤:**
```bash
# 1. 检查RDMA设备
ibstat

# 2. 检查RDMA驱动
lsmod | grep -E "mlx|ib"

# 3. 检查IB链路状态
ibstat | grep -E "State|Physical"

# 4. 测试RDMA基本功能
ibv_devinfo
```

**解决方案:**
```bash
# 1. 加载RDMA驱动
sudo modprobe ib_core
sudo modprobe mlx5_core
sudo modprobe mlx5_ib

# 2. 启动RDMA服务
sudo systemctl start rdma

# 3. 检查子网管理器
sudo systemctl start opensm

# 4. 验证连接
ibv_rc_pingpong <server_ip>
```

### 问题3: 性能低于预期

**诊断流程:**
```
性能低？
    ↓
┌─────────────┐
│ 检查CPU使用  │ → > 90%? → CPU瓶颈
└──────┬──────┘
       ↓
┌─────────────┐
│ 检查消息大小  │ → 太小? → 增大消息
└──────┬──────┘
       ↓
┌─────────────┐
│ 检查网卡设置  │ → offload? → 启用TSO/GSO
└──────┬──────┘
       ↓
┌─────────────┐
│ 检查网络MTU  │ → < 9000? → 启用Jumbo Frames
└─────────────┘
```

**优化措施:**
```bash
# 1. 增大消息大小
qperf <host> -oo msg_size:65536 tcp_bw

# 2. 启用网卡offload
ethtool -K eth0 tso on gso on gro on

# 3. 启用Jumbo Frames（如果支持）
ip link set eth0 mtu 9000

# 4. 增大Socket缓冲区
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
```

## 最佳实践

### 测试前准备

1. **确保网络空闲**
   - 避免其他流量干扰
   - 选择非高峰时段

2. **优化系统参数**
   ```bash
   # TCP参数
   sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
   sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

   # 网络队列
   sysctl -w net.core.netdev_max_backlog=10000
   ```

3. **检查硬件状态**
   ```bash
   # 网卡速率
   ethtool eth0 | grep Speed

   # RDMA设备（如有）
   ibstat
   ```

### 测试中监控

```bash
# 终端1: 运行qperf
qperf 192.168.1.100 -v -t 60 tcp_bw

# 终端2: 监控CPU
mpstat -P ALL 1

# 终端3: 监控网络
watch -n1 'ifconfig eth0 | grep -E "RX|TX"'

# 终端4: 监控RDMA（如有）
watch -n1 ibstat
```

### 测试后分析

1. **对比性能基准**
   - 是否达到预期？
   - 与理论值差距多大？

2. **CPU效率评估**
   - 计算 带宽/CPU 比率
   - 是否存在CPU瓶颈？

3. **多次测试验证**
   - 至少测试3次
   - 计算平均值和标准差

## 参考资料

- [qperf GitHub仓库](https://github.com/linux-rdma/qperf)
- [RDMA技术白皮书](https://www.mellanox.com/related-docs/whitepapers/WP_2018_Introduction_to_RDMA.pdf)
- [InfiniBand架构规范](https://www.infinibandta.org/)
- [Linux RDMA文档](https://www.kernel.org/doc/Documentation/infiniband/)

## 相关工具

- **perftest**: RDMA性能测试工具集（ib_write_bw, ib_write_lat等）
- **iperf3**: 通用网络带宽测试（不支持RDMA）
- **netperf**: 网络性能测试（不支持RDMA）
- **sockperf**: Socket性能测试工具

---

**更新日期:** 2026-04-19
**版本:** 1.0
