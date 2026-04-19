# FIO I/O 性能测试套件

## 概述

FIO (Flexible I/O Tester) 是一个强大而灵活的I/O基准测试工具，可以模拟各种I/O负载模式。本测试套件提供了常见场景的FIO配置文件和自动化测试脚本。

## 目录结构

```
fio/
├── README.md                       # 本文件
├── configs/
│   ├── sequential_read.fio         # 顺序读测试
│   ├── sequential_write.fio        # 顺序写测试
│   ├── random_read.fio             # 随机读测试
│   ├── random_write.fio            # 随机写测试
│   ├── mixed_rw.fio                # 混合读写测试
│   ├── iops_test.fio               # IOPS测试
│   └── latency_test.fio            # 延迟测试
├── scripts/
│   └── test_fio.sh                 # 自动化测试脚本
└── results/                        # 测试结果目录
```

## FIO测试原理

### 核心概念

**1. I/O模式 (rw)**

| 模式 | 说明 | 应用场景 |
|------|------|---------|
| `read` | 顺序读 | 日志分析、流媒体 |
| `write` | 顺序写 | 日志写入、备份 |
| `randread` | 随机读 | 数据库查询 |
| `randwrite` | 随机写 | 数据库更新 |
| `randrw` | 随机读写混合 | 数据库负载 |
| `readwrite` | 顺序读写混合 | 一般应用 |

**2. 块大小 (bs)**

```
4K      - 数据库、随机I/O（关注IOPS）
16K-64K - 一般应用
128K-1M - 顺序I/O、流媒体（关注带宽）
```

**关系：** `IOPS = 带宽 / 块大小`

**3. I/O深度 (iodepth)**

队列中未完成的I/O请求数：

```
1-4      - 测试延迟（单个I/O延迟）
16-32    - 一般性能测试
64-128   - 最大吞吐量/IOPS测试
```

**4. I/O引擎 (ioengine)**

| 引擎 | 说明 | 使用场景 |
|------|------|---------|
| `sync` | 同步I/O (read/write) | 简单测试 |
| `libaio` | Linux异步I/O | 推荐，生产环境 |
| `io_uring` | 新异步I/O接口 | 5.1+内核，高性能 |
| `mmap` | 内存映射I/O | 特殊场景 |

**5. 直接I/O (direct)**

```
direct=1  - 绕过缓存(O_DIRECT)，测试真实磁盘性能
direct=0  - 使用系统缓存，测试缓存性能
```

### 关键指标

**1. IOPS (I/O Operations Per Second)**
- 每秒完成的I/O操作数
- 小块随机I/O场景的关键指标
- 数据库、虚拟化关注

**2. 带宽 (Bandwidth)**
- MB/s 或 GB/s
- 大块顺序I/O场景的关键指标
- 流媒体、大数据关注

**3. 延迟 (Latency)**
- 单个I/O操作的时间（微秒或毫秒）
- 关键指标：平均、P50、P95、P99、最大
- 交互式应用关注

**4. CPU利用率**
- I/O操作消耗的CPU资源
- 影响系统整体效率

## 前置条件

### 安装FIO

```bash
# Ubuntu/Debian
sudo apt-get install fio

# RHEL/CentOS
sudo yum install fio

# Fedora
sudo dnf install fio

# 从源码编译（获取最新版本）
git clone https://github.com/axboe/fio.git
cd fio
./configure
make
sudo make install
```

### 检查版本

```bash
fio --version
```

推荐版本：3.x 或更高

## 测试场景

### 1. 顺序读测试 (sequential_read.fio)

**场景：** 大文件顺序读取，如视频流、日志分析

**配置：**
```ini
rw=read           # 顺序读
bs=128k           # 大块I/O
iodepth=32        # 中等队列深度
```

**运行：**
```bash
fio configs/sequential_read.fio
```

**关注指标：** 带宽 (MB/s)

### 2. 顺序写测试 (sequential_write.fio)

**场景：** 大文件顺序写入，如数据备份、日志写入

**配置：**
```ini
rw=write          # 顺序写
bs=128k           # 大块I/O
```

**关注指标：** 带宽 (MB/s)

### 3. 随机读测试 (random_read.fio)

**场景：** 数据库查询、随机访问

**配置：**
```ini
rw=randread       # 随机读
bs=4k             # 小块I/O
iodepth=32
```

**关注指标：** IOPS、延迟

### 4. 随机写测试 (random_write.fio)

**场景：** 数据库更新、随机写入

**配置：**
```ini
rw=randwrite      # 随机写
bs=4k
```

**关注指标：** IOPS、延迟

### 5. 混合读写测试 (mixed_rw.fio)

**场景：** 数据库负载（70%读 + 30%写）

**配置：**
```ini
rw=randrw         # 随机读写
rwmixread=70      # 读比例70%
bs=4k
```

**关注指标：** 混合IOPS、延迟

### 6. IOPS测试 (iops_test.fio)

**场景：** 最大IOPS性能测试

**配置：**
```ini
rw=randread
bs=4k
iodepth=64        # 高队列深度
numjobs=4         # 4个并发任务
```

**关注指标：** 最大IOPS

### 7. 延迟测试 (latency_test.fio)

**场景：** I/O延迟敏感应用

**配置：**
```ini
rw=randread
bs=4k
iodepth=1         # 低队列深度
```

**关注指标：** 延迟分布（P95、P99）

## 运行测试

### 自动化测试

运行所有测试场景：

```bash
cd scripts
sudo ./test_fio.sh
```

### 单独测试

```bash
# 运行特定测试
fio configs/random_read.fio

# 指定输出文件
fio configs/random_read.fio --output=results/random_read.txt

# JSON格式输出
fio configs/random_read.fio --output-format=json --output=results/random_read.json
```

### 自定义参数

```bash
# 覆盖配置文件参数
fio configs/random_read.fio --runtime=120 --numjobs=8

# 指定测试文件
fio configs/random_read.fio --filename=/mnt/nvme/testfile

# 调整块大小
fio configs/random_read.fio --bs=16k
```

## 结果解读

### 输出示例

```
random-read: (groupid=0, jobs=1): err= 0: pid=12345
  read: IOPS=45.5k, BW=178MiB/s (186MB/s)(10.4GiB/60001msec)
    slat (usec): min=2, max=1234, avg=5.23, stdev=12.45
    clat (usec): min=45, max=89012, avg=698.12, stdev=1234.56
     lat (usec): min=50, max=89020, avg=703.35, stdev=1235.67
    clat percentiles (usec):
     |  1.00th=[   78],  5.00th=[  102], 10.00th=[  126], 20.00th=[  169],
     | 30.00th=[  225], 40.00th=[  306], 50.00th=[  420], 60.00th=[  594],
     | 70.00th=[  840], 80.00th=[ 1188], 90.00th=[ 1680], 95.00th=[ 2212],
     | 99.00th=[ 3556], 99.50th=[ 4490], 99.90th=[ 7504], 99.95th=[ 9896],
     | 99.99th=[18220]
   bw (  KiB/s): min=156780, max=198234, per=100.00%, avg=182156.78, stdev=5678.90
   iops        : min=39195, max=49558, avg=45539.19, stdev=1419.72
  lat (usec)   : 50=0.01%, 100=4.56%, 250=28.34%, 500=32.12%, 750=9.87%
  lat (usec)   : 1000=8.45%
  lat (msec)   : 2=10.23%, 4=5.67%, 10=0.70%, 20=0.05%, 50=0.01%
  cpu          : usr=12.34%, sys=23.45%, ctx=123456, majf=0, minf=78
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.2%, 32=99.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
```

### 关键指标说明

**IOPS和带宽：**
```
IOPS=45.5k          # 每秒45,500次I/O操作
BW=178MiB/s         # 带宽178 MB/s
```

**延迟：**
```
slat - 提交延迟 (Submission Latency)
clat - 完成延迟 (Completion Latency) - 最重要
lat  - 总延迟 (Total Latency)
```

**延迟百分位：**
```
50.00th=[420]     # P50（中位数）= 420微秒
95.00th=[2212]    # P95 = 2212微秒
99.00th=[3556]    # P99 = 3556微秒（尾延迟）
```

**CPU使用率：**
```
usr=12.34%        # 用户态CPU
sys=23.45%        # 内核态CPU
```

## 性能参考值

### 存储类型性能

| 存储类型 | 顺序读/写 | 随机IOPS (4K) | 延迟 |
|---------|----------|--------------|------|
| HDD (7200转) | 100-200 MB/s | 100-200 | 5-15 ms |
| SATA SSD | 500-600 MB/s | 50K-100K | 50-100 us |
| NVMe SSD | 3000-7000 MB/s | 500K-1M | 10-50 us |
| NVMe Gen4 | 5000-7000 MB/s | 1M+ | < 10 us |
| Optane SSD | 2500 MB/s | 550K | < 10 us |

### 性能等级判断

**随机读IOPS (4K):**
```
优秀:  > 100K IOPS
良好:  50K-100K IOPS
一般:  10K-50K IOPS
较差:  < 10K IOPS
```

**顺序读带宽:**
```
优秀:  > 3000 MB/s (NVMe)
良好:  500-3000 MB/s
一般:  100-500 MB/s
较差:  < 100 MB/s
```

**延迟 (4K随机读):**
```
优秀:  < 100 us
良好:  100-500 us
一般:  500-5000 us (0.5-5 ms)
较差:  > 5000 us (5 ms)
```

## 性能优化

### 1. 文件系统优化

**ext4:**
```bash
# noatime: 禁用访问时间更新
# data=writeback: 异步数据写入
mount -o noatime,data=writeback /dev/sda1 /mnt

# 永久配置 /etc/fstab
/dev/sda1  /mnt  ext4  noatime,data=writeback  0  0
```

**XFS:**
```bash
# XFS对大文件和并发I/O性能更好
mount -o noatime,nodiratime,largeio,swalloc /dev/sda1 /mnt
```

**Btrfs:**
```bash
mount -o noatime,compress=zstd,space_cache=v2 /dev/sda1 /mnt
```

### 2. I/O调度器

**查看当前调度器:**
```bash
cat /sys/block/nvme0n1/queue/scheduler
```

**SSD/NVMe推荐:**
```bash
# none (无调度器) 或 mq-deadline
echo none > /sys/block/nvme0n1/queue/scheduler
echo mq-deadline > /sys/block/nvme0n1/queue/scheduler
```

**HDD推荐:**
```bash
# bfq 对机械盘更友好
echo bfq > /sys/block/sda/queue/scheduler
```

### 3. 队列深度和预读

```bash
# 增加设备队列深度
echo 1024 > /sys/block/nvme0n1/queue/nr_requests

# 调整预读大小（KB）
echo 512 > /sys/block/nvme0n1/queue/read_ahead_kb

# NVMe特定设置
nvme set-feature /dev/nvme0 -f 0x06 -v 1  # write cache
```

### 4. 虚拟内存调优

```bash
# 减少swap使用
sysctl -w vm.swappiness=10

# 调整脏页刷新
sysctl -w vm.dirty_ratio=10
sysctl -w vm.dirty_background_ratio=5

# 持久化配置 /etc/sysctl.conf
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
```

### 5. CPU性能模式

```bash
# 设置性能模式
cpupower frequency-set -g performance

# 查看当前策略
cpupower frequency-info
```

### 6. NUMA优化

```bash
# 查看NUMA拓扑
numactl --hardware

# 绑定到本地NUMA节点
numactl --cpunodebind=0 --membind=0 fio config.fio
```

## 常见问题

### 1. Permission denied

**错误：**
```
fio: failed to open file /dev/sda: Permission denied
```

**解决：**
```bash
# 使用sudo运行
sudo fio config.fio

# 或添加用户到disk组
sudo usermod -a -G disk $USER
```

### 2. 性能远低于预期

**原因：**
- 未使用direct I/O（测试的是缓存）
- I/O调度器不合适
- 文件系统未优化
- CPU节能模式

**解决：**
```bash
# 1. 确保使用direct I/O
direct=1

# 2. 优化I/O调度器
echo none > /sys/block/nvme0n1/queue/scheduler

# 3. 性能模式
cpupower frequency-set -g performance

# 4. 检查是否使用了正确的设备
lsblk
```

### 3. 磁盘空间不足

**错误：**
```
fio: No space left on device
```

**解决：**
```bash
# 检查可用空间
df -h

# 减小测试文件大小
size=1G  # 在配置文件中

# 或使用更大的分区
filename=/mnt/large_partition/testfile
```

### 4. Too many open files

**错误：**
```
fio: cannot create I/O file: Too many open files
```

**解决：**
```bash
# 临时增加文件描述符限制
ulimit -n 65536

# 永久配置 /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
```

### 5. 结果波动大

**原因：**
- 后台进程干扰
- Turbo Boost动态调频
- 温度限制降频
- 缓存影响

**解决：**
```bash
# 1. 关闭不必要的服务
systemctl stop <service>

# 2. 禁用Turbo Boost
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# 3. 固定CPU频率
cpupower frequency-set -f 3.0GHz

# 4. 增加运行时间
runtime=300  # 5分钟
```

## 高级用法

### 1. 多文件测试

```ini
[global]
ioengine=libaio
direct=1

[job1]
filename=/mnt/ssd1/testfile
rw=randread
bs=4k

[job2]
filename=/mnt/ssd2/testfile
rw=randread
bs=4k
```

### 2. 延迟目标测试

```ini
[global]
ioengine=libaio
direct=1
latency_target=500us    # 目标延迟500微秒
latency_window=10s      # 采样窗口
latency_percentile=99.0 # P99延迟

[job]
rw=randread
bs=4k
iodepth=32
```

### 3. 压力测试

```ini
[global]
ioengine=libaio
direct=1
runtime=3600            # 运行1小时
time_based=1

[stress]
rw=randrw
rwmixread=70
bs=4k
iodepth=128
numjobs=8               # 8个并发任务
```

### 4. 带宽限制

```ini
[global]
ioengine=libaio
rate=100m               # 限制带宽100MB/s

[job]
rw=write
bs=128k
```

## 测试结果

运行`test_fio.sh`后生成以下文件：

- `principles.txt` - FIO测试原理
- `sysinfo.txt` - 系统和存储信息
- `summary.txt` - 测试结果汇总
- `analysis.txt` - 性能分析
- `optimization.txt` - 优化建议
- `config_guide.txt` - 配置参数说明
- `report.txt` - 完整报告
- `<test_name>.txt` - 各测试详细结果
- `<test_name>.json` - JSON格式结果

## 应用场景

### 1. 存储选型

比较不同存储方案：
```bash
# 测试SATA SSD
fio configs/random_read.fio --filename=/mnt/sata_ssd/test

# 测试NVMe SSD
fio configs/random_read.fio --filename=/mnt/nvme/test

# 对比结果选择合适的存储
```

### 2. 性能基准

建立性能基线用于后续对比：
```bash
# 初始基准测试
./test_fio.sh

# 保存结果
cp -r results/fio-* baseline/

# 后续对比
diff baseline/summary.txt results/fio-*/summary.txt
```

### 3. 问题诊断

发现I/O性能问题：
```bash
# 如果应用I/O慢，运行FIO测试
fio configs/latency_test.fio

# 分析延迟分布，找出瓶颈
# P99 > 10ms 可能表明存储问题
```

### 4. 优化验证

验证优化效果：
```bash
# 优化前测试
fio configs/random_read.fio > before.txt

# 应用优化（如更改调度器）
echo none > /sys/block/nvme0n1/queue/scheduler

# 优化后测试
fio configs/random_read.fio > after.txt

# 对比结果
```

## 参考资料

- [FIO官方文档](https://fio.readthedocs.io/)
- [FIO GitHub](https://github.com/axboe/fio)
- [I/O调度器文档](https://www.kernel.org/doc/html/latest/block/index.html)
- [Linux I/O性能优化](https://www.brendangregg.com/linuxperf.html)

---

**更新日期:** 2026-04-19
**版本:** 1.0
