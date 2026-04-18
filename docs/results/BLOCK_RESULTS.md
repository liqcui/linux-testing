# 块设备I/O测试结果解析

## 概述

本文档详细解释块设备I/O测试的输出结果，帮助你理解磁盘性能、页缓存行为和I/O瓶颈。

---

## 测试文件位置

```
results/block/
├── block_cached_TIMESTAMP.txt         # 缓存写入测试
├── block_direct_write_TIMESTAMP.txt   # Direct I/O写入
├── block_direct_read_TIMESTAMP.txt    # Direct I/O读取
├── block_fsync_TIMESTAMP.txt          # fsync同步写入
├── block_events_TIMESTAMP.txt         # 详细块事件
└── report_TIMESTAMP.txt               # 测试报告
```

---

## 1. 缓存写入测试解析

### 示例输出

```
Performance counter stats for 'dd if=/dev/zero of=test bs=1M count=100':

                 0      block:block_touch_buffer
                 0      block:block_dirty_buffer
                 0      block:block_rq_requeue
                 0      block:block_rq_complete
                 0      block:block_rq_error
                 0      block:block_rq_insert
                 0      block:block_rq_issue
                 0      block:block_rq_merge
                 0      block:block_bio_complete
                 0      block:block_bio_bounce
                 0      block:block_bio_backmerge
                 0      block:block:block_bio_frontmerge
                 0      block:block_bio_queue
                 0      block:block_getrq
                 0      block:block_plug
                 0      block:block_unplug
                 0      block:block_split
                 0      block:block_bio_remap
                 0      block:block_rq_remap

100+0 records in
100+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.0413462 s, 2.5 GB/s

       0.043617786 seconds time elapsed
       0.000000000 seconds user
       0.042318000 seconds sys
```

### 关键发现

#### 所有块事件都是 0

**原因**: 数据完全写入页缓存，没有触发真实磁盘I/O

**数据流向**:
```
/dev/zero → dd进程 → write()系统调用 → 页缓存（停在这里！）
                                            ↓（延迟写入）
                                      块设备层（未触发）
                                            ↓
                                        磁盘驱动
                                            ↓
                                        物理磁盘
```

#### 性能指标

| 指标 | 值 | 说明 |
|------|-----|------|
| 数据量 | 104857600 bytes (100 MiB) | dd写入的数据 |
| 耗时 | 0.0413462 s (41ms) | 总时间 |
| 速度 | 2.5 GB/s | 吞吐量 |
| 用户时间 | 0.000 s | 用户态CPU时间（几乎为0） |
| 系统时间 | 0.042318 s (42ms) | 内核态CPU时间 |

#### 性能分析

**为什么这么快？**
```
2.5 GB/s >> 普通SSD速度(500MB/s)
因为只写到内存（页缓存），没有真正的磁盘I/O
```

**内存带宽验证**:
```bash
# 测试内存带宽
dd if=/dev/zero of=/dev/null bs=1M count=10000
# 通常能达到几GB/s到几十GB/s
```

**时间分配**:
```
总时间: 41ms
  用户时间: 0ms   ← dd进程本身几乎不消耗CPU
  系统时间: 42ms  ← 系统调用开销（write、内存分配等）
```

---

## 2. Direct I/O 写入测试解析

### 示例输出

```
Performance counter stats for 'dd if=/dev/zero of=test bs=1M count=100 oflag=direct':

               100      block:block_bio_queue
               100      block:block_getrq
               100      block:block_rq_insert
               100      block:block_rq_issue
               100      block:block_rq_complete
                 2      block:block_plug
                 2      block:block_unplug
                 5      block:block_bio_backmerge
                 0      block:block_bio_frontmerge
                 0      block:block_split
                 0      block:block_rq_requeue
                 0      block:block_rq_error

100+0 records in
100+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.125643 s, 835 MB/s

       0.125643 seconds time elapsed
       0.000000000 seconds user
       0.043210000 seconds sys
```

### 块事件详解

#### block:block_bio_queue - BIO进入队列

**数量**: 100
**含义**: 提交了100个块I/O请求（bio）

**bio (Block I/O)**:
```
bio = 块设备I/O的基本单位
每个 bio 包含:
  - 起始扇区
  - 扇区数量
  - 数据缓冲区
  - 读/写方向
```

**计算**:
```
100个bio × 1MB = 100MB
bs=1M count=100 → 每次写1MB，共100次
```

#### block:block_getrq - 获取请求结构

**数量**: 100
**含义**: 为每个bio分配了请求结构(request)

**request vs bio**:
```
request = 块设备层的I/O请求
bio = 通用层的I/O请求

一个 request 可以包含多个 bio（合并）
```

**比例分析**:
```
bio: 100
request: 100
比例: 1:1 → 每个bio都创建了独立的request
```

#### block:block_rq_insert - 请求插入调度器

**数量**: 100
**含义**: 100个请求插入I/O调度器队列

**I/O调度器类型**:
| 调度器 | 特点 | 适用场景 |
|--------|------|---------|
| noop | 无调度（FIFO） | SSD、NVME |
| deadline | 截止时间保证 | 数据库 |
| cfq | 完全公平队列 | 桌面 |
| mq-deadline | 多队列截止时间 | 现代SSD |

**查看当前调度器**:
```bash
cat /sys/block/sda/queue/scheduler
# [mq-deadline] none
```

#### block:block_rq_issue - 请求发送到驱动

**数量**: 100
**含义**: 100个请求发送到磁盘驱动

**流程**:
```
调度器队列 → 驱动队列 → 磁盘控制器 → 物理磁盘
```

#### block:block_rq_complete - 请求完成

**数量**: 100
**含义**: 100个请求全部成功完成

**完成率**:
```
完成 / 发出 = 100 / 100 = 100%
无丢失，无错误
```

#### block:block_plug/unplug - I/O批处理

**plug**: 2次
**unplug**: 2次

**含义**:
- **plug**: 开始积累I/O请求
- **unplug**: 批量提交积累的请求

**批处理优化**:
```
不使用plug:
  write(1MB) → 立即提交 → 磁盘处理
  write(1MB) → 立即提交 → 磁盘处理
  ... 100次单独提交

使用plug:
  plug()
  write(1MB)  ┐
  write(1MB)  ├─ 积累
  ...         │
  write(50MB) ┘
  unplug() → 一次性提交50MB
```

**计算批次**:
```
100个I/O / 2次unplug ≈ 每批50个I/O
```

#### block:block_bio_backmerge - Bio后向合并

**数量**: 5
**含义**: 5次bio合并优化

**合并示例**:
```
原始:
  bio1: 扇区 0-2047    (1MB)
  bio2: 扇区 2048-4095 (1MB)  ← 连续

合并后:
  bio_merged: 扇区 0-4095 (2MB)

减少了1个I/O请求
```

**合并率**:
```
原始bio: 100
合并: 5
最终请求: 95  (100 - 5)

但实际 request 还是 100，说明合并发生在不同阶段
```

#### block:block_bio_frontmerge - Bio前向合并

**数量**: 0
**含义**: 没有前向合并

**前向vs后向合并**:
```
后向合并: 新bio追加到现有bio后面
前向合并: 新bio插入到现有bio前面（较少见）
```

### 性能指标对比

| 模式 | 速度 | 耗时 | 块事件 |
|------|------|------|--------|
| 缓存写入 | 2.5 GB/s | 41ms | 0 |
| Direct I/O | 835 MB/s | 126ms | 100+ |

**速度差异**: 2.5 GB/s / 835 MB/s = **3倍**

**原因**:
```
缓存写入: 只写内存
Direct I/O: 真实磁盘速度
```

---

## 3. fsync 同步写入测试解析

### 示例输出

```
Performance counter stats for 'dd if=/dev/zero of=test bs=1M count=100 conv=fsync':

               100      block:block_bio_queue
               100      block:block_rq_insert
               100      block:block_rq_issue
               100      block:block_rq_complete
                 3      block:block_plug
                 3      block:block_unplug

100+0 records in
100+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.156789 s, 668 MB/s
```

### 特点分析

#### fsync 强制刷盘

**流程**:
```
1. write() → 写入页缓存
2. write() → 写入页缓存
   ...
3. fsync() → 强制将脏页刷到磁盘
```

**与 Direct I/O 的区别**:
| 特性 | Direct I/O | fsync |
|------|-----------|-------|
| 写入路径 | 绕过缓存 | 先缓存后刷盘 |
| 数据安全 | 立即持久化 | fsync后持久化 |
| 性能 | 较慢 | 可批量优化 |
| 适用 | 数据库 WAL | 普通文件 |

#### 性能比较

```
Direct I/O:  835 MB/s (126ms)
fsync:       668 MB/s (157ms)
缓存写入:    2500 MB/s (41ms)
```

**fsync 更慢的原因**:
1. 先写缓存（内存操作）
2. 再刷盘（磁盘操作）
3. 等待确认（同步操作）

---

## 4. 详细块事件解析

### 示例输出

```
dd 12345 [001] 1234.567: block:block_bio_queue: 8,0 W 2048 + 2048 [dd]
dd 12345 [001] 1234.568: block:block_getrq: 8,0 W 2048 + 2048 [dd]
dd 12345 [001] 1234.569: block:block_rq_insert: 8,0 W 2048 + 2048 [dd]
dd 12345 [001] 1234.570: block:block_rq_issue: 8,0 W 2048 + 2048 [dd]
dd 12345 [001] 1234.580: block:block_rq_complete: 8,0 W 2048 + 2048 0 [dd]
```

### 字段解析

#### 设备号 (8,0)

```
8,0
│ │
│ └─ minor number (次设备号)
└─── major number (主设备号)
```

**查看设备对应关系**:
```bash
ls -l /dev/sda
brw-rw---- 1 root disk 8, 0 Apr 18 10:00 /dev/sda
                        ↑  ↑
                        │  └─ minor
                        └──── major

# 常见主设备号
8:  SCSI 磁盘
3:  IDE 磁盘 (hda)
253: 设备映射器 (dm-0, LVM)
259: NVMe 设备
```

#### 操作类型 (W/R)

```
W = Write (写)
R = Read (读)
D = Discard (TRIM)
F = Flush (刷新)
```

#### 扇区范围 (2048 + 2048)

```
2048 + 2048
 │     │
 │     └─ 扇区数量
 └─────── 起始扇区
```

**计算**:
```
扇区大小 = 512字节（标准）
数据大小 = 2048扇区 × 512字节 = 1MB

起始位置 = 2048扇区 × 512字节 = 1MB偏移
```

**连续I/O判断**:
```
bio1: 2048 + 2048  (扇区 2048-4095)
bio2: 4096 + 2048  (扇区 4096-8191)  ← 连续

bio1: 2048 + 2048  (扇区 2048-4095)
bio2: 8192 + 2048  (扇区 8192-10239) ← 不连续（随机I/O）
```

#### 完成状态 (0)

```
block:block_rq_complete: ... 0 [dd]
                             ↑
                          错误码
```

**错误码**:
- **0**: 成功
- **-5 (EIO)**: I/O错误
- **-11 (EAGAIN)**: 资源暂时不可用
- **-28 (ENOSPC)**: 磁盘空间不足

### 时间线分析

```
事件                    时间          延迟
bio_queue           1234.567      -
getrq               1234.568      1ms   ← 获取request结构
rq_insert           1234.569      1ms   ← 插入调度器
rq_issue            1234.570      1ms   ← 发送到驱动
rq_complete         1234.580      10ms  ← 磁盘完成

I/O延迟 = 完成时间 - 队列时间
        = 1234.580 - 1234.567
        = 13ms
```

**延迟分段**:
| 阶段 | 时间 | 说明 |
|------|------|------|
| 软件层 | 3ms | 内核处理（getrq+insert+issue） |
| 硬件层 | 10ms | 磁盘处理（issue→complete） |
| 总计 | 13ms | 端到端延迟 |

---

## 5. 性能基准和标准

### 磁盘类型性能基准

#### SSD (SATA)

| 指标 | 优秀 | 良好 | 可接受 | 需检查 |
|------|------|------|--------|--------|
| 顺序读 | > 500 MB/s | > 400 MB/s | > 300 MB/s | < 200 MB/s |
| 顺序写 | > 500 MB/s | > 400 MB/s | > 300 MB/s | < 200 MB/s |
| 随机读 4K | > 80K IOPS | > 50K IOPS | > 30K IOPS | < 10K IOPS |
| 随机写 4K | > 70K IOPS | > 40K IOPS | > 20K IOPS | < 10K IOPS |
| 延迟 | < 0.1ms | < 0.5ms | < 1ms | > 2ms |

#### NVMe SSD

| 指标 | 优秀 | 良好 | 可接受 | 需检查 |
|------|------|------|--------|--------|
| 顺序读 | > 3000 MB/s | > 2000 MB/s | > 1500 MB/s | < 1000 MB/s |
| 顺序写 | > 2500 MB/s | > 1500 MB/s | > 1000 MB/s | < 800 MB/s |
| 随机读 4K | > 500K IOPS | > 300K IOPS | > 200K IOPS | < 100K IOPS |
| 随机写 4K | > 400K IOPS | > 250K IOPS | > 150K IOPS | < 80K IOPS |
| 延迟 | < 0.02ms | < 0.05ms | < 0.1ms | > 0.2ms |

#### HDD (机械硬盘)

| 指标 | 优秀 | 良好 | 可接受 | 需检查 |
|------|------|------|--------|--------|
| 顺序读 | > 200 MB/s | > 150 MB/s | > 100 MB/s | < 80 MB/s |
| 顺序写 | > 200 MB/s | > 150 MB/s | > 100 MB/s | < 80 MB/s |
| 随机读 4K | > 200 IOPS | > 150 IOPS | > 100 IOPS | < 80 IOPS |
| 随机写 4K | > 180 IOPS | > 120 IOPS | > 80 IOPS | < 50 IOPS |
| 延迟 | < 10ms | < 15ms | < 20ms | > 30ms |

### I/O模式性能对比

| 模式 | 典型速度 | 说明 |
|------|---------|------|
| 页缓存写入 | 2-10 GB/s | 仅内存操作 |
| Direct I/O (顺序) | SSD: 500MB/s, HDD: 150MB/s | 绕过缓存 |
| Direct I/O (随机) | SSD: 50MB/s, HDD: 5MB/s | 寻道开销 |
| fsync 同步 | 比Direct I/O慢10-30% | 双重写入 |
| mmap 内存映射 | 接近页缓存 | 延迟写入 |

---

## 6. 常见问题诊断

### 问题1: 所有块事件都是0

**症状**:
```
所有 block:* 事件计数都是 0
但是 dd 报告写入成功
```

**原因**: 数据只写到页缓存

**验证**:
```bash
# 写入前查看缓存
free -h

# 写入100MB
dd if=/dev/zero of=test bs=1M count=100

# 写入后查看缓存（应该增加100MB）
free -h
```

**解决**: 使用 `oflag=direct` 或 `conv=fsync`

### 问题2: I/O速度异常慢

**症状**:
```
Direct I/O: 50 MB/s (预期500MB/s的SSD)
```

**可能原因**:
1. 磁盘故障或降级
2. I/O调度器不合适
3. 文件系统碎片
4. RAID降级

**诊断步骤**:
```bash
# 1. 检查磁盘健康
smartctl -a /dev/sda

# 2. 查看I/O统计
iostat -x 1

# 3. 检查调度器
cat /sys/block/sda/queue/scheduler

# 4. 测试原始设备
dd if=/dev/zero of=/dev/sda bs=1M count=100 oflag=direct
# 注意：这会破坏数据！仅用于空设备测试

# 5. 查看系统日志
dmesg | grep -i error
```

**优化**:
```bash
# 更换调度器
echo none > /sys/block/sda/queue/scheduler  # SSD
echo mq-deadline > /sys/block/sda/queue/scheduler

# 增加队列深度
echo 1024 > /sys/block/sda/queue/nr_requests

# 启用write cache
hdparm -W1 /dev/sda
```

### 问题3: block_rq_error 不为0

**症状**:
```
block:block_rq_error: 15
```

**含义**: 有15个I/O请求失败

**诊断**:
```bash
# 查看详细错误
dmesg | tail -50

# 检查文件系统
fsck /dev/sda1

# 查看SMART信息
smartctl -a /dev/sda | grep -i error
```

### 问题4: 合并率低

**症状**:
```
block_bio_queue: 1000
block_bio_backmerge: 5  ← 合并率 < 1%
```

**原因**: 随机I/O，无法合并

**验证**:
```bash
# 查看I/O模式
perf script | grep block_bio_queue | \
  awk '{print $8, $10}' | head -20

# 随机I/O示例:
# 1000 + 200
# 5000 + 200
# 2000 + 200  ← 位置跳跃

# 顺序I/O示例:
# 0 + 200
# 200 + 200
# 400 + 200  ← 连续
```

**优化**:
```bash
# 顺序写入
dd if=/dev/zero of=test bs=1M count=1000 oflag=direct

# 预分配文件空间
fallocate -l 1G test
```

---

## 7. 进阶分析技巧

### 分析I/O延迟分布

```bash
# 记录详细事件
perf record -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 oflag=direct

# 计算每个I/O的延迟
perf script | awk '
  /block_rq_issue/ {issue[$8] = $4}
  /block_rq_complete/ {
    if ($8 in issue) {
      latency = ($4 - issue[$8]) * 1000
      print latency " ms"
      delete issue[$8]
    }
  }
' | sort -n

# 输出延迟分布
# 8.5 ms
# 9.2 ms
# 10.1 ms
# ...
```

### 分析I/O大小分布

```bash
perf script | grep block_bio_queue | \
  awk '{print $10}' | sort -n | uniq -c

# 输出:
# 50  + 2048   ← 50个 1MB I/O
# 30  + 4096   ← 30个 2MB I/O
# 20  + 8192   ← 20个 4MB I/O
```

### 分析设备利用率

```bash
# 实时监控
iostat -x 1

# 输出:
# Device  rrqm/s wrqm/s   r/s   w/s  rMB/s  wMB/s  %util
# sda        0.00   5.00  0.00 100.00  0.00  100.00  95.00
#                                                    ↑
#                                              设备利用率95%
```

**利用率分析**:
- **< 70%**: 设备空闲充足
- **70-90%**: 设备繁忙
- **> 90%**: 设备接近饱和
- **100%**: 设备饱和（有I/O等待）

---

## 8. 报告示例解读

### 完整报告

```
块设备 I/O 性能测试报告
======================
测试时间: 2026-04-18 10:30:00
主机名: test-server
测试文件: ./test
测试大小: 100MB

## 性能对比

### 1. 缓存写入
104857600 bytes (105 MB, 100 MiB) copied, 0.041 s, 2.5 GB/s
块事件: 0 (全部在缓存中)

### 2. Direct I/O 写入
104857600 bytes (105 MB, 100 MiB) copied, 0.126 s, 835 MB/s
块事件:
  block_bio_queue: 100
  block_rq_issue: 100
  block_rq_complete: 100

### 3. Direct I/O 读取
104857600 bytes (105 MB, 100 MiB) copied, 0.118 s, 889 MB/s
块事件:
  block_bio_queue: 100
  block_rq_issue: 100
  block_rq_complete: 100

### 4. fsync 同步写入
104857600 bytes (105 MB, 100 MiB) copied, 0.157 s, 668 MB/s
块事件:
  block_bio_queue: 100
  block_rq_issue: 100
  block_rq_complete: 100

## 块事件统计
bio_queue 事件数: 100
rq_issue 事件数: 100
rq_complete 事件数: 100
错误: 0
```

### 解读

**缓存性能**: ⚡ 2.5 GB/s
- 仅内存操作
- 未触发磁盘I/O
- 适合批量写入后台刷盘

**真实磁盘性能**: 📊 835 MB/s (写) / 889 MB/s (读)
- 符合SATA SSD性能标准
- 读略快于写（正常现象）
- 无I/O错误

**同步写入性能**: 🔒 668 MB/s
- 比Direct I/O慢20%
- 双重写入开销
- 数据安全性高

**建议**:
- 性能正常，磁盘健康
- 应用可根据需求选择I/O模式
- 关键数据使用fsync或Direct I/O

---

## 9. 优化建议

### 提升吞吐量

1. **使用大块I/O**
   ```bash
   # 小块I/O
   dd bs=4K count=25600  # 100MB, 25600次I/O

   # 大块I/O
   dd bs=1M count=100    # 100MB, 100次I/O (更快)
   ```

2. **启用write cache**
   ```bash
   hdparm -W1 /dev/sda
   ```

3. **调整队列深度**
   ```bash
   echo 1024 > /sys/block/sda/queue/nr_requests
   ```

### 降低延迟

1. **使用合适的调度器**
   ```bash
   # SSD使用none或mq-deadline
   echo none > /sys/block/sda/queue/scheduler

   # HDD使用deadline或bfq
   echo deadline > /sys/block/sda/queue/scheduler
   ```

2. **禁用read-ahead (随机I/O)**
   ```bash
   blockdev --setra 0 /dev/sda
   ```

3. **SSD: 启用discard**
   ```bash
   # 挂载选项
   mount -o discard /dev/sda1 /mnt

   # 或在fstab中
   /dev/sda1 /mnt ext4 defaults,discard 0 0
   ```

### 应用级优化

1. **选择合适的I/O模式**
   ```c
   // 数据库WAL: Direct I/O
   fd = open("wal.log", O_WRONLY | O_DIRECT);

   // 普通文件: 缓存 + fsync
   fd = open("data.txt", O_WRONLY);
   write(fd, ...);
   fsync(fd);

   // 临时文件: 纯缓存
   fd = open("temp.txt", O_WRONLY);
   write(fd, ...);
   // 不需要fsync
   ```

2. **批量I/O**
   ```c
   // 差: 多次小I/O
   for (i = 0; i < 1000; i++) {
       write(fd, buf, 4096);
   }

   // 好: 一次大I/O
   write(fd, big_buf, 4096000);
   ```

3. **异步I/O**
   ```c
   // 使用 aio
   io_submit(...);  // 提交多个I/O
   io_getevents(...); // 批量等待完成
   ```

---

## 总结

块设备I/O测试结果解读的关键点：

1. **区分缓存和磁盘** - 块事件是否触发
2. **性能基准对比** - 与设备类型标准比较
3. **错误监控** - rq_error 应该为 0
4. **合并优化** - 顺序I/O有更好合并率
5. **延迟分析** - 软件层vs硬件层延迟

通过系统的测试和分析，可以：
- ✅ 评估磁盘性能
- ✅ 发现I/O瓶颈
- ✅ 选择合适的I/O策略
- ✅ 优化应用性能

---

**相关文档**:
- [网络测试结果解析](NETWORK_RESULTS.md)
- [调度测试结果解析](SCHED_RESULTS.md)
- [详细测试指南](../DETAILED_GUIDE.md)
