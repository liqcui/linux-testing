# stress-ng 结果详细解读指南

本文档提供 stress-ng 测试结果的详细解读，帮助理解各项指标的含义和性能优化方向。

## 目录

- [基础概念](#基础概念)
- [内存测试结果解读](#内存测试结果解读)
- [网络测试结果解读](#网络测试结果解读)
- [文件系统测试结果解读](#文件系统测试结果解读)
- [性能优化建议](#性能优化建议)

## 基础概念

### bogo ops (bogus operations)

**定义:**
bogo ops 是 stress-ng 执行的操作次数，用于性能对比和基准测试。

**计算方式:**
```
bogo ops/s (real time) = 总操作数 / 实际运行时间
bogo ops/s (usr+sys time) = 总操作数 / (用户态时间 + 系统态时间)
```

**意义:**
- **real time 版本**: 反映实际性能，考虑I/O等待
- **usr+sys time 版本**: 反映CPU效率，不考虑等待时间

### 时间指标

| 指标 | 说明 | 典型场景 |
|------|------|----------|
| **real time** | 墙上时钟时间（实际经过时间） | 60.01秒 |
| **user time** | CPU在用户态执行时间 | CPU密集型高 |
| **system time** | CPU在内核态执行时间 | I/O、网络密集型高 |

**时间比例分析:**
```
usr time >> sys time   → CPU密集型（计算主导）
sys time >> usr time   → 系统调用密集型（I/O、网络主导）
real time >> (usr+sys) → 有大量等待（I/O阻塞）
real time ≈ (usr+sys)  → CPU密集型，无等待
```

## 内存测试结果解读

### 1. VM 内存分配测试

**典型输出:**
```
stress-ng: info:  [12345] vm           125000     60.01     180.23     58.45      2083.32       524.45
```

**字段解读:**
- `bogo ops`: 125000 - 内存操作总数
- `real time`: 60.01秒 - 实际运行时间
- `usr time`: 180.23秒 - 用户态时间（4个worker × 45秒/worker）
- `sys time`: 58.45秒 - 内核态时间（内存分配和页表管理）
- `bogo ops/s (real)`: **2083.32** - 关键指标
- `bogo ops/s (cpu)`: 524.45

**性能评级:**
```
bogo ops/s (real time):
  > 2000  ★★★★★ 优秀 - 内存分配器和虚拟内存管理高效
  1000-2000 ★★★★☆ 良好 - 性能正常
  500-1000  ★★★☆☆ 一般 - 可能存在内存碎片或swap
  < 500     ★★☆☆☆ 较差 - 内存压力过大，需要优化
```

**分析要点:**
1. **高 sys time**: 说明内核花费大量时间在页表管理、TLB刷新
2. **real > usr+sys**: 可能触发了swap或磁盘I/O
3. **多worker性能**: 检查NUMA影响，多节点可能性能下降

### 2. memcpy 内存拷贝测试

**典型输出:**
```
stress-ng: info:  [12345] memcpy        350000     60.00     220.45     15.23      5833.33      1487.91
stress-ng: info:  [12345] memcpy:         12.5 GB/sec
```

**性能指标:**
- **带宽 (GB/sec)**: 12.5 GB/sec
- **bogo ops/s**: 5833 ops/sec

**性能评级 (DDR4内存):**
```
内存带宽:
  > 15 GB/s   ★★★★★ 优秀 - DDR4-3200双通道
  10-15 GB/s  ★★★★☆ 良好 - DDR4-2666
  5-10 GB/s   ★★★☆☆ 一般 - DDR4-2400或单通道
  < 5 GB/s    ★★☆☆☆ 较差 - DDR3或内存故障
```

**影响因素:**
1. **内存频率**: DDR4-3200 > DDR4-2666 > DDR4-2400
2. **通道数**: 双通道 > 单通道（性能翻倍）
3. **CPU缓存**: L1/L2/L3 缓存命中率
4. **NUMA架构**: 跨节点访问性能下降

**优化方向:**
- 升级到更高频率内存
- 启用双通道配置
- 优化数据局部性，提高缓存命中率
- NUMA系统中绑定内存到本地节点

### 3. mmap 内存映射测试

**典型输出:**
```
stress-ng: info:  [12345] mmap          420000     60.02     190.34     68.12      6999.00      1625.71
stress-ng: info:  [12345] mmap: 4096 page faults/sec
```

**关键指标:**
- **page faults/sec**: 4096次/秒
- **bogo ops/s**: 6999 ops/sec

**页面错误分析:**
```
Page Faults < 1000/s   ★★★★★ 优秀 - 良好的内存管理
Page Faults 1000-5000/s ★★★★☆ 良好 - 正常范围
Page Faults 5000-10000/s ★★★☆☆ 一般 - 内存压力增大
Page Faults > 10000/s   ★★☆☆☆ 较差 - 频繁换页，性能下降
```

**Page Fault类型:**
- **Minor Page Fault**: 页面在内存中，只需更新页表（快速）
- **Major Page Fault**: 需要从磁盘读取页面（慢速）

**检查方式:**
```bash
# 查看page fault统计
vmstat 1

# 输出解读
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 4  0      0 123456  12345 234567    0    0     0     0 1234 5678 25 10 65  0  0
        ↑                           ↑    ↑
     swap使用                      si   so
                                (swap in/out - 关键指标)
```

**si/so (swap in/out) 分析:**
```
si/so = 0      ★★★★★ 优秀 - 无swap，内存充足
si/so < 100    ★★★★☆ 良好 - 轻微换页
si/so 100-1000 ★★★☆☆ 一般 - 内存压力
si/so > 1000   ★★☆☆☆ 较差 - 严重内存不足，性能严重下降
```

### 4. bigheap 大页内存测试

**典型输出:**
```
stress-ng: info:  [12345] bigheap        8500     60.01      85.23     12.45       141.64        86.89
stress-ng: info:  [12345] bigheap: 2MB hugepages used
```

**Hugepage性能优势:**
- 减少TLB miss（Translation Lookaside Buffer）
- 降低页表管理开销
- 适合大内存应用（数据库、虚拟化）

**性能对比:**
```
标准4KB页面:
  - TLB entries: 512-1024
  - 覆盖内存: 2-4MB
  - TLB miss率: 较高

2MB Hugepage:
  - TLB entries: 512-1024
  - 覆盖内存: 1-2GB
  - TLB miss率: 显著降低（10-50%性能提升）
```

**启用Hugepage:**
```bash
# 查看当前配置
cat /proc/meminfo | grep Huge

# 配置2MB hugepage数量
echo 1024 > /proc/sys/vm/nr_hugepages

# 永久配置
echo "vm.nr_hugepages = 1024" >> /etc/sysctl.conf
sysctl -p
```

### 5. NUMA 内存测试

**典型输出:**
```
stress-ng: info:  [12345] numa          95000     60.00     210.34     45.67      1583.33       371.43
stress-ng: info:  [12345] numa: local access 85%, remote access 15%
```

**NUMA访问模式:**
```
Local Access (本地节点):
  延迟: ~60ns
  带宽: 全速（20+ GB/s）

Remote Access (远程节点):
  延迟: ~120ns (2倍)
  带宽: 降低30-50%
```

**性能评级:**
```
Local Access > 90%  ★★★★★ 优秀 - 良好的NUMA亲和性
Local Access 80-90% ★★★★☆ 良好
Local Access 60-80% ★★★☆☆ 一般 - 需要优化亲和性
Local Access < 60%  ★★☆☆☆ 较差 - NUMA配置不当
```

**NUMA优化:**
```bash
# 查看NUMA拓扑
numactl --hardware

# 绑定进程到NUMA节点0
numactl --cpunodebind=0 --membind=0 <command>

# 查看NUMA统计
numastat

# 查看进程NUMA分布
numastat -p <PID>
```

## 网络测试结果解读

### 1. TCP Socket 压力测试

**典型输出:**
```
stress-ng: info:  [12345] sock          285000     60.01     120.45     180.23      4749.58      947.62
```

**性能指标:**
- **bogo ops**: 285000 - socket操作总数
- **bogo ops/s**: **4749.58** - 每秒socket操作数
- **sys time高**: 180.23秒 - 大量内核态时间（协议栈处理）

**性能评级:**
```
Socket ops/s (TCP):
  > 100000   ★★★★★ 优秀 - 高性能网络栈
  50000-100000 ★★★★☆ 良好
  10000-50000  ★★★☆☆ 一般
  < 10000      ★★☆☆☆ 较差 - 可能存在网络配置问题
```

**系统态时间分析:**
```
sys_time / real_time > 2.0  → 协议栈开销大（多worker情况）
sys_time / usr_time > 5.0   → 网络密集型，正常现象
```

**影响因素:**
1. **TCP参数配置**:
   ```bash
   # 查看TCP参数
   sysctl -a | grep tcp

   # 优化建议
   net.ipv4.tcp_fin_timeout = 30
   net.ipv4.tcp_tw_reuse = 1
   net.core.somaxconn = 65535
   net.core.netdev_max_backlog = 16384
   ```

2. **Socket缓冲区**:
   ```bash
   # 增大缓冲区
   net.core.rmem_max = 134217728  # 128MB
   net.core.wmem_max = 134217728
   net.ipv4.tcp_rmem = 4096 87380 67108864
   net.ipv4.tcp_wmem = 4096 65536 67108864
   ```

3. **连接数限制**:
   ```bash
   # 检查文件描述符限制
   ulimit -n

   # 增加限制
   ulimit -n 65535
   ```

### 2. UDP Socket 压力测试

**典型输出:**
```
stress-ng: info:  [12345] udp           520000     60.00     95.34      145.67      8666.67      2158.11
```

**性能指标:**
- **bogo ops/s**: 8666.67
- **UDP vs TCP**: UDP通常ops/s更高（无连接建立开销）

**性能评级:**
```
UDP ops/s:
  > 150000    ★★★★★ 优秀
  80000-150000 ★★★★☆ 良好
  30000-80000  ★★★☆☆ 一般
  < 30000      ★★☆☆☆ 较差
```

**UDP特性:**
- **无连接**: 无三次握手开销
- **无拥塞控制**: 可能丢包
- **低延迟**: 适合实时应用

**丢包检测:**
```bash
# 查看UDP统计
netstat -su | grep -i "packet receive errors\|RcvbufErrors"

# 输出示例
    12345 packet receive errors
    5678 receive buffer errors

# 解读
packet receive errors > 1000/s  → 网络拥塞或硬件问题
RcvbufErrors > 100/s → 接收缓冲区不足，需增大
```

**UDP优化:**
```bash
# 增大UDP缓冲区
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216

# 增大接收队列
net.core.netdev_max_backlog = 30000
```

### 3. Unix Domain Socket测试

**典型输出:**
```
stress-ng: info:  [12345] sock-unix     650000     60.01     110.23     165.45     10832.86      2358.74
```

**性能特点:**
- **ops/s最高**: 通常是TCP的2-3倍
- **无网络栈**: 直接内存拷贝
- **低延迟**: 适合本地IPC

**性能评级:**
```
Unix Socket ops/s:
  > 200000    ★★★★★ 优秀 - 高效的本地通信
  100000-200000 ★★★★☆ 良好
  50000-100000  ★★★☆☆ 一般
  < 50000       ★★☆☆☆ 较差
```

**典型应用场景:**
- 数据库连接（PostgreSQL, MySQL）
- Docker容器通信
- 系统守护进程通信

### 4. 网络吞吐量测试

**典型输出:**
```
stress-ng: info:  [12345] netdev         45000     60.02      85.23     120.45       749.75       218.73
stress-ng: info:  [12345] netdev: 8.5 Gbps throughput
```

**吞吐量评级:**
```
Loopback接口:
  > 30 Gbps   ★★★★★ 优秀
  20-30 Gbps  ★★★★☆ 良好
  10-20 Gbps  ★★★☆☆ 一般
  < 10 Gbps   ★★☆☆☆ 较差

物理网卡(1GbE):
  > 950 Mbps  ★★★★★ 优秀 - 接近线速
  850-950 Mbps ★★★★☆ 良好
  700-850 Mbps ★★★☆☆ 一般
  < 700 Mbps   ★★☆☆☆ 较差 - 可能存在问题

物理网卡(10GbE):
  > 9.5 Gbps  ★★★★★ 优秀
  8-9.5 Gbps  ★★★★☆ 良好
  6-8 Gbps    ★★★☆☆ 一般
  < 6 Gbps    ★★☆☆☆ 较差
```

**瓶颈分析:**
```bash
# 检查网卡统计
ethtool -S eth0 | grep -i error

# 检查中断分布
cat /proc/interrupts | grep eth0

# 检查网卡队列
ethtool -l eth0

# 检查offload特性
ethtool -k eth0
```

## 文件系统测试结果解读

### 1. HDD 文件写入测试

**典型输出:**
```
stress-ng: info:  [12345] hdd            25000     60.01     45.23      125.67       416.60       146.93
stress-ng: info:  [12345] hdd: 150 MB/sec write throughput
```

**性能指标:**
- **吞吐量**: 150 MB/sec
- **bogo ops/s**: 416.60
- **sys time高**: 125.67秒（I/O系统调用）

**性能评级 (顺序写入):**
```
NVMe SSD:
  > 2000 MB/s  ★★★★★ 优秀 - PCIe 3.0 x4
  1000-2000    ★★★★☆ 良好 - PCIe 3.0 x2
  500-1000     ★★★☆☆ 一般 - SATA SSD
  < 500        ★★☆☆☆ 较差 - 可能是HDD

SATA SSD:
  > 500 MB/s   ★★★★★ 优秀
  400-500      ★★★★☆ 良好
  250-400      ★★★☆☆ 一般
  < 250        ★★☆☆☆ 较差

HDD (7200 RPM):
  > 150 MB/s   ★★★★★ 优秀
  100-150      ★★★★☆ 良好
  50-100       ★★★☆☆ 一般
  < 50         ★★☆☆☆ 较差 - 硬盘故障或碎片严重
```

**I/O模式分析:**
```bash
# 查看I/O统计
iostat -x 1

Device   r/s  w/s   rMB/s   wMB/s  rrqm/s  wrqm/s  %util  await
sda      5.0  125.0  0.2     150.0  0.0     245.0   98.5   8.2
         ↑    ↑      ↑       ↑      ↑       ↑       ↑      ↑
        读/s  写/s  读MB/s  写MB/s 读合并 写合并  利用率 平均等待
```

**关键指标解读:**
```
%util (利用率):
  > 90%   → 磁盘接近饱和，可能是瓶颈
  50-90%  → 中等负载
  < 50%   → 轻度负载

await (平均等待时间):
  SSD: < 1ms 正常
  HDD: < 10ms 正常
  > 20ms 存在性能问题

wrqm/s (写请求合并):
  > 100   → I/O调度器合并效果好
  < 10    → 随机I/O，难以合并
```

### 2. I/O 压力测试

**典型输出:**
```
stress-ng: info:  [12345] io            450000     60.00     75.23      215.45      7500.00      1549.15
```

**性能指标:**
- **bogo ops/s**: 7500 I/O ops/sec
- **sys time >> usr time**: I/O密集型特征

**IOPS性能评级:**
```
NVMe SSD:
  > 200000 IOPS ★★★★★ 优秀
  100000-200000 ★★★★☆ 良好
  50000-100000  ★★★☆☆ 一般
  < 50000       ★★☆☆☆ 较差

SATA SSD:
  > 50000 IOPS  ★★★★★ 优秀
  20000-50000   ★★★★☆ 良好
  10000-20000   ★★★☆☆ 一般
  < 10000       ★★☆☆☆ 较差

HDD:
  > 200 IOPS    ★★★★★ 优秀 (7200 RPM)
  150-200       ★★★★☆ 良好
  100-150       ★★★☆☆ 一般
  < 100         ★★☆☆☆ 较差
```

### 3. sync-file 同步I/O测试

**典型输出:**
```
stress-ng: info:  [12345] sync-file      12000     60.02     25.34      145.67       199.93        70.11
```

**性能特点:**
- **ops/s较低**: sync/fsync是昂贵操作
- **sys time高**: 大量内核态时间

**sync操作成本:**
```
fsync() 延迟:
  SSD: 0.1-1ms
  HDD: 5-10ms

每秒sync次数:
  > 500   ★★★★★ 优秀 (SSD)
  200-500 ★★★★☆ 良好
  50-200  ★★★☆☆ 一般
  < 50    ★★☆☆☆ 较差 (HDD或高延迟设备)
```

**优化建议:**
1. **批量同步**: 累积多个写入后一次sync
2. **异步I/O**: 使用aio避免阻塞
3. **文件系统选择**: ext4 (data=writeback) 比 data=ordered 快
4. **禁用日志**: 仅测试环境，生产环境不推荐

### 4. dir 目录操作测试

**典型输出:**
```
stress-ng: info:  [12345] dir            85000     60.01     35.23      95.45      1416.43       651.70
stress-ng: info:  [12345] dir: 1024 directories, 10240 files
```

**元数据操作性能:**
```
文件/目录创建速率:
  > 2000/s  ★★★★★ 优秀 - SSD + 优化的文件系统
  1000-2000 ★★★★☆ 良好
  500-1000  ★★★☆☆ 一般
  < 500     ★★☆☆☆ 较差 - HDD或文件系统碎片
```

**文件系统对比:**
```
元数据性能排序 (由快到慢):
  1. XFS - 优秀的元数据性能，适合大量小文件
  2. ext4 - 平衡性能
  3. Btrfs - 功能丰富但元数据操作较慢
  4. ZFS - 写时复制，元数据操作开销大
```

### 5. flock 文件锁测试

**典型输出:**
```
stress-ng: info:  [12345] flock         650000     60.00     120.45     85.23     10833.33      3161.05
```

**文件锁性能:**
```
File Lock ops/s:
  > 10000   ★★★★★ 优秀 - 低争用
  5000-10000 ★★★★☆ 良好
  1000-5000  ★★★☆☆ 一般 - 中等争用
  < 1000     ★★☆☆☆ 较差 - 高度争用或锁实现问题
```

**锁争用检测:**
```bash
# 查看文件锁
lslocks

# 查看进程持有的锁
cat /proc/<PID>/locks

# 监控锁等待
perf record -e 'syscalls:sys_enter_flock' -ag -- sleep 10
perf report
```

## 性能优化建议

### 内存优化

**1. 启用Transparent Huge Pages (THP)**
```bash
# 查看THP状态
cat /sys/kernel/mm/transparent_hugepage/enabled

# 启用THP
echo always > /sys/kernel/mm/transparent_hugepage/enabled

# 永久配置
echo "transparent_hugepage=always" >> /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
```

**2. 调整swap策略**
```bash
# 查看当前swappiness
cat /proc/sys/vm/swappiness

# 降低swappiness（减少swap使用）
echo 10 > /proc/sys/vm/swappiness

# 永久配置
echo "vm.swappiness = 10" >> /etc/sysctl.conf
```

**3. NUMA优化**
```bash
# 自动NUMA平衡
echo 1 > /proc/sys/kernel/numa_balancing

# 应用级NUMA绑定
numactl --cpunodebind=0 --membind=0 <application>
```

### 网络优化

**1. TCP参数调优**
```bash
# 增大TCP缓冲区
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# 快速回收TIME_WAIT
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1

# 增大连接队列
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
```

**2. 中断亲和性**
```bash
# 查看网卡中断
cat /proc/interrupts | grep eth0

# 设置中断CPU亲和性
echo 1 > /proc/irq/<IRQ>/smp_affinity

# 或使用irqbalance
systemctl enable irqbalance
systemctl start irqbalance
```

### 文件系统优化

**1. I/O调度器选择**
```bash
# 查看当前调度器
cat /sys/block/sda/queue/scheduler

# SSD推荐: none 或 mq-deadline
echo none > /sys/block/sda/queue/scheduler

# HDD推荐: mq-deadline
echo mq-deadline > /sys/block/sda/queue/scheduler
```

**2. 文件系统挂载选项**
```bash
# ext4优化（/etc/fstab）
/dev/sda1 /data ext4 noatime,nodiratime,data=writeback,barrier=0 0 0

# XFS优化
/dev/sda1 /data xfs noatime,nodiratime,logbufs=8,logbsize=256k 0 0
```

**3. 提前读取调整**
```bash
# 查看当前readahead
blockdev --getra /dev/sda

# 增大readahead（SSD可设置更大值）
blockdev --setra 8192 /dev/sda  # 4MB
```

---

**更新日期:** 2026-04-19
**版本:** 1.0
