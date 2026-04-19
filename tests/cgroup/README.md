# Cgroup 测试套件

## 概述

本测试套件提供了完整的cgroup (Control Groups) 测试工具，包括CPU、内存和I/O资源限制测试。支持cgroup v1和v2两个版本。

## 目录结构

```
cgroup/
├── README.md                       # 本文件
├── programs/
│   ├── cpu_hog.c                   # CPU密集型测试程序
│   ├── mem_hog.c                   # 内存密集型测试程序
│   ├── io_hog.c                    # I/O密集型测试程序
│   └── Makefile                    # 编译配置
├── scripts/
│   ├── test_cpu_cgroup.sh          # CPU限制测试
│   ├── test_memory_cgroup.sh       # 内存限制测试
│   └── test_io_cgroup.sh           # I/O限制测试
└── results/                        # 测试结果目录
```

## Cgroup版本说明

### Cgroup v1 vs v2

**Cgroup v1:**
- 传统版本，使用多个层级结构
- 每个控制器有独立的挂载点
- 路径：`/sys/fs/cgroup/cpu`, `/sys/fs/cgroup/memory` 等
- 广泛支持，成熟稳定

**Cgroup v2:**
- 统一层级结构
- 所有控制器在同一个挂载点
- 路径：`/sys/fs/cgroup`
- 更简洁的API，更好的性能

### 检查Cgroup版本

```bash
# 检查cgroup v2
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    echo "cgroup v2"
fi

# 检查cgroup v1
if [[ -d /sys/fs/cgroup/cpu ]]; then
    echo "cgroup v1"
fi

# 查看挂载点
mount | grep cgroup
```

## 前置条件

### 系统要求

- Linux内核 >= 3.10 (cgroup v1) 或 >= 4.5 (cgroup v2)
- root权限
- gcc编译器

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install build-essential cgroup-tools

# RHEL/CentOS/Fedora
sudo yum install gcc make libcgroup-tools
```

### 启用Cgroup v2（可选）

如果想使用cgroup v2：

```bash
# 检查是否支持
grep cgroup2 /proc/filesystems

# 启用cgroup v2（需要重启）
# 编辑 /etc/default/grub
# 添加: GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"
sudo update-grub
sudo reboot
```

## 测试程序

### cpu_hog - CPU密集型程序

**功能：** 创建多线程执行CPU密集计算

**用法：**
```bash
./cpu_hog [线程数] [持续时间(秒)]

# 示例
./cpu_hog 4 10          # 4线程，运行10秒
./cpu_hog 2             # 2线程，无限运行（Ctrl+C停止）
```

**输出：**
- 实时迭代计数
- 总运行时间
- 平均速率（迭代/秒）

### mem_hog - 内存密集型程序

**功能：** 分配和访问指定大小的内存

**用法：**
```bash
./mem_hog [内存MB] [访问模式]

# 访问模式:
#   0 = 写入
#   1 = 读取
#   2 = 读写（默认）

# 示例
./mem_hog 100 2         # 分配100MB，读写模式
./mem_hog 500 0         # 分配500MB，仅写入
```

**输出：**
- 分配进度
- 分配速率（MB/s）
- 访问迭代次数

### io_hog - I/O密集型程序

**功能：** 执行文件读写操作

**用法：**
```bash
./io_hog [文件大小MB] [模式] [路径]

# 模式:
#   0 = 写入
#   1 = 读取
#   2 = 读写（默认）

# 示例
./io_hog 500 0          # 写入500MB
./io_hog 100 2 /tmp     # 在/tmp读写100MB
```

**输出：**
- 读写进度
- 吞吐量（MB/s）
- 总耗时

## 测试1: CPU限制

### 功能特性

- CPU quota限制（绝对限制）
- CPU shares/weight权重（相对限制）
- 多进程竞争测试
- CPU使用统计

### 运行测试

```bash
cd scripts
sudo ./test_cpu_cgroup.sh
```

### 手动操作

#### Cgroup v2

```bash
# 创建cgroup
mkdir /sys/fs/cgroup/mygroup

# 启用cpu控制器
echo "+cpu" > /sys/fs/cgroup/cgroup.subtree_control

# 设置CPU限制为50% (50000us / 100000us)
echo "50000 100000" > /sys/fs/cgroup/mygroup/cpu.max

# 将进程加入cgroup
echo $PID > /sys/fs/cgroup/mygroup/cgroup.procs

# 设置CPU权重（10-10000，默认100）
echo 200 > /sys/fs/cgroup/mygroup/cpu.weight

# 查看统计
cat /sys/fs/cgroup/mygroup/cpu.stat
```

#### Cgroup v1

```bash
# 创建cgroup
mkdir /sys/fs/cgroup/cpu/mygroup

# 设置CPU限制为50%
echo 100000 > /sys/fs/cgroup/cpu/mygroup/cpu.cfs_period_us
echo 50000 > /sys/fs/cgroup/cpu/mygroup/cpu.cfs_quota_us

# 将进程加入cgroup
echo $PID > /sys/fs/cgroup/cpu/mygroup/tasks

# 设置CPU shares（相对权重）
echo 2048 > /sys/fs/cgroup/cpu/mygroup/cpu.shares

# 查看统计
cat /sys/fs/cgroup/cpu/mygroup/cpuacct.usage
cat /sys/fs/cgroup/cpu/mygroup/cpu.stat
```

### CPU Quota说明

- **Period**: 时间周期（通常100ms = 100000us）
- **Quota**: 周期内可用CPU时间
- **限制百分比** = Quota / Period × 100%

示例：
- 50% CPU: quota=50000, period=100000
- 25% CPU: quota=25000, period=100000
- 200% CPU (2核): quota=200000, period=100000

### CPU Shares/Weight说明

- 相对权重，仅在竞争时生效
- 比例：2048:1024 = 2:1
- Cgroup v1默认1024，v2默认100

### 测试结果

- `baseline.txt` - 无限制基准性能
- `quota-50.txt` - 50% quota限制结果
- `shares-a.txt` - 低权重进程
- `shares-b.txt` - 高权重进程
- `summary.txt` - 测试总结

## 测试2: 内存限制

### 功能特性

- 内存使用限制
- Swap限制
- OOM (Out of Memory) 测试
- 内存使用统计
- Failcnt计数

### 运行测试

```bash
cd scripts
sudo ./test_memory_cgroup.sh
```

### 手动操作

#### Cgroup v2

```bash
# 创建cgroup
mkdir /sys/fs/cgroup/mygroup

# 启用memory控制器
echo "+memory" > /sys/fs/cgroup/cgroup.subtree_control

# 设置内存限制（100MB）
echo $((100 * 1024 * 1024)) > /sys/fs/cgroup/mygroup/memory.max

# 设置swap限制
echo $((50 * 1024 * 1024)) > /sys/fs/cgroup/mygroup/memory.swap.max

# 将进程加入cgroup
echo $PID > /sys/fs/cgroup/mygroup/cgroup.procs

# 查看当前使用
cat /sys/fs/cgroup/mygroup/memory.current

# 查看详细统计
cat /sys/fs/cgroup/mygroup/memory.stat

# 查看事件（OOM等）
cat /sys/fs/cgroup/mygroup/memory.events
```

#### Cgroup v1

```bash
# 创建cgroup
mkdir /sys/fs/cgroup/memory/mygroup

# 设置内存限制（100MB）
echo $((100 * 1024 * 1024)) > /sys/fs/cgroup/memory/mygroup/memory.limit_in_bytes

# 设置memory+swap总限制
echo $((150 * 1024 * 1024)) > /sys/fs/cgroup/memory/mygroup/memory.memsw.limit_in_bytes

# 禁用OOM killer（可选）
echo 0 > /sys/fs/cgroup/memory/mygroup/memory.oom_control

# 将进程加入cgroup
echo $PID > /sys/fs/cgroup/memory/mygroup/tasks

# 查看当前使用
cat /sys/fs/cgroup/memory/mygroup/memory.usage_in_bytes

# 查看峰值使用
cat /sys/fs/cgroup/memory/mygroup/memory.max_usage_in_bytes

# 查看限制失败次数
cat /sys/fs/cgroup/memory/mygroup/memory.failcnt

# 查看详细统计
cat /sys/fs/cgroup/memory/mygroup/memory.stat
```

### OOM行为

当进程超过内存限制：
1. 内核尝试回收内存
2. 如果无法回收，触发OOM killer
3. 终止cgroup内的进程
4. 记录到memory.events (v2) 或 memory.oom_control (v1)

### 测试结果

- `baseline.txt` - 无限制基准测试
- `limited-100mb.txt` - 100MB限制测试
- `oom-test.txt` - OOM测试
- `summary.txt` - 测试总结

## 测试3: I/O限制

### 功能特性

- I/O带宽限制（读/写）
- I/O权重分配
- I/O统计信息
- 支持块设备限制

### 运行测试

```bash
cd scripts
sudo ./test_io_cgroup.sh
```

### 手动操作

#### Cgroup v2

```bash
# 创建cgroup
mkdir /sys/fs/cgroup/mygroup

# 启用io控制器
echo "+io" > /sys/fs/cgroup/cgroup.subtree_control

# 获取设备号（主:次）
# 示例: 8:0 (sda)
ls -l /dev/sda

# 设置读写带宽限制（10MB/s）
echo "8:0 rbps=$((10 * 1024 * 1024))" > /sys/fs/cgroup/mygroup/io.max
echo "8:0 wbps=$((10 * 1024 * 1024))" > /sys/fs/cgroup/mygroup/io.max

# 设置IOPS限制
echo "8:0 riops=1000" > /sys/fs/cgroup/mygroup/io.max
echo "8:0 wiops=1000" > /sys/fs/cgroup/mygroup/io.max

# 设置I/O权重（1-10000，默认100）
echo "default 200" > /sys/fs/cgroup/mygroup/io.weight
echo "8:0 200" > /sys/fs/cgroup/mygroup/io.weight

# 将进程加入cgroup
echo $PID > /sys/fs/cgroup/mygroup/cgroup.procs

# 查看统计
cat /sys/fs/cgroup/mygroup/io.stat
```

#### Cgroup v1

```bash
# 创建cgroup
mkdir /sys/fs/cgroup/blkio/mygroup

# 获取设备号
ls -l /dev/sda  # 示例: 8:0

# 设置读带宽限制（10MB/s）
echo "8:0 $((10 * 1024 * 1024))" > /sys/fs/cgroup/blkio/mygroup/blkio.throttle.read_bps_device

# 设置写带宽限制（10MB/s）
echo "8:0 $((10 * 1024 * 1024))" > /sys/fs/cgroup/blkio/mygroup/blkio.throttle.write_bps_device

# 设置IOPS限制
echo "8:0 1000" > /sys/fs/cgroup/blkio/mygroup/blkio.throttle.read_iops_device
echo "8:0 1000" > /sys/fs/cgroup/blkio/mygroup/blkio.throttle.write_iops_device

# 设置I/O权重（10-1000，默认500）
# 注意：需要CFQ或BFQ调度器
echo 800 > /sys/fs/cgroup/blkio/mygroup/blkio.weight

# 将进程加入cgroup
echo $PID > /sys/fs/cgroup/blkio/mygroup/tasks

# 查看统计
cat /sys/fs/cgroup/blkio/mygroup/blkio.throttle.io_service_bytes
cat /sys/fs/cgroup/blkio/mygroup/blkio.throttle.io_serviced
```

### I/O调度器

I/O权重功能需要特定调度器：

```bash
# 查看当前调度器
cat /sys/block/sda/queue/scheduler

# 设置调度器
echo bfq > /sys/block/sda/queue/scheduler  # BFQ（推荐）
echo cfq > /sys/block/sda/queue/scheduler  # CFQ（旧版）
```

### 设备号获取

```bash
# 方法1: ls -l
ls -l /dev/sda
# brw-rw---- 1 root disk 8, 0 ...
# 主设备号=8, 次设备号=0

# 方法2: stat
stat -c "%t %T" /dev/sda | while read maj min; do
    echo "$((0x$maj)):$((0x$min))"
done

# 方法3: 从df获取
DEVICE=$(df /tmp | tail -1 | awk '{print $1}')
ls -l $DEVICE | awk '{print $5, $6}' | tr -d ','
```

### 测试结果

- `baseline.txt` - 无限制基准性能
- `limited-10mbs.txt` - 10MB/s限制结果
- `weight-a.txt` - 低权重进程
- `weight-b.txt` - 高权重进程
- `summary.txt` - 测试总结

## 常见问题排查

### Cgroup未挂载

**现象：** 找不到 `/sys/fs/cgroup`

**解决：**
```bash
# 检查挂载
mount | grep cgroup

# 手动挂载cgroup v1
mount -t tmpfs cgroup_root /sys/fs/cgroup
mkdir /sys/fs/cgroup/cpu
mount -t cgroup -o cpu cpu /sys/fs/cgroup/cpu

# 手动挂载cgroup v2
mount -t cgroup2 none /sys/fs/cgroup
```

### 控制器未启用

**现象：** 写入控制文件失败

**解决（cgroup v2）：**
```bash
# 查看可用控制器
cat /sys/fs/cgroup/cgroup.controllers

# 启用控制器
echo "+cpu +memory +io" > /sys/fs/cgroup/cgroup.subtree_control
```

### I/O限制不生效

**现象：** 设置blkio限制后无效

**可能原因：**
1. 使用了错误的设备号
2. 文件系统不在块设备上（如tmpfs）
3. I/O调度器不支持

**解决：**
```bash
# 1. 确认设备类型
df /tmp
lsblk

# 2. 使用实际块设备，不是分区
# 错误: /dev/sda1 (分区)
# 正确: /dev/sda (磁盘)

# 3. 更换调度器
echo bfq > /sys/block/sda/queue/scheduler
```

### 权限错误

**现象：** 无法写入cgroup文件

**解决：**
```bash
# 使用root权限
sudo -i

# 检查文件权限
ls -l /sys/fs/cgroup/mygroup/

# 检查cgroup所有权
stat /sys/fs/cgroup/mygroup/
```

### OOM Killer行为

**现象：** 进程意外被终止

**解决：**
```bash
# 查看OOM事件
dmesg | grep -i "killed process"

# cgroup v2
cat /sys/fs/cgroup/mygroup/memory.events

# cgroup v1
cat /sys/fs/cgroup/memory/mygroup/memory.oom_control

# 增加内存限制
echo $((200 * 1024 * 1024)) > .../memory.max
```

## 最佳实践

### 1. 资源限制设置

**CPU:**
- 使用quota进行绝对限制
- 使用shares/weight进行相对限制
- 避免设置过低的quota导致进程饥饿

**内存:**
- 设置合理的限制，避免频繁OOM
- 考虑设置swap限制
- 监控memory.stat中的cache和RSS

**I/O:**
- 基于实际工作负载设置限制
- 使用权重而不是硬限制（更灵活）
- 注意文件系统缓存的影响

### 2. 监控和调优

```bash
# 定期检查统计
watch -n 1 cat /sys/fs/cgroup/mygroup/cpu.stat
watch -n 1 cat /sys/fs/cgroup/mygroup/memory.current

# 记录性能数据
while true; do
    echo "$(date) $(cat /sys/fs/cgroup/mygroup/memory.current)"
    sleep 5
done > memory_usage.log
```

### 3. 层级设计

```bash
# 创建层级结构
/sys/fs/cgroup/
├── production/
│   ├── web-servers/
│   ├── databases/
│   └── workers/
└── development/
    └── test-apps/

# 父cgroup限制整体资源
# 子cgroup分配具体任务
```

### 4. 进程迁移

```bash
# 批量移动进程
for pid in $(cat old_cgroup/cgroup.procs); do
    echo $pid > new_cgroup/cgroup.procs
done

# 确保进程已移动
cat new_cgroup/cgroup.procs
```

## 性能影响

### Cgroup开销

- CPU限制：< 1% 开销
- 内存限制：< 1% 开销
- I/O限制：1-5% 开销（取决于调度器）

### 基准测试建议

1. 先运行无限制基准测试
2. 应用cgroup限制
3. 对比性能差异
4. 调整限制参数

## 参考资料

- [Linux Cgroup Documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)
- [Red Hat Resource Management Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/managing_monitoring_and_updating_the_kernel/using-cgroups-v2-to-control-distribution-of-cpu-time-for-applications_managing-monitoring-and-updating-the-kernel)
- [Cgroup v1 vs v2](https://facebookmicrosites.github.io/cgroup2/docs/overview.html)
- [systemd and cgroups](https://www.freedesktop.org/wiki/Software/systemd/ControlGroupInterface/)

---

**更新日期：** 2026-04-19
**版本：** 1.0
