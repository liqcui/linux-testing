# stress-ng 压力测试套件

## 概述

stress-ng 是一个全面的系统压力测试工具，可以测试各种系统资源和子系统。本测试套件提供了按测试场景分类的完整测试用例。

## 目录结构

```
stress-ng/
├── README.md                           # 本文件
├── cpu/
│   └── test_cpu_stress.sh              # CPU压力测试
├── memory/
│   └── test_memory_stress.sh           # 内存压力测试
├── io/
│   └── test_io_stress.sh               # I/O压力测试
├── network/
│   └── test_network_stress.sh          # 网络压力测试
└── comprehensive/
    └── test_comprehensive_stress.sh    # 综合压力测试
```

## 安装 stress-ng

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install stress-ng
```

### RHEL/CentOS
```bash
sudo yum install epel-release
sudo yum install stress-ng
```

### Fedora
```bash
sudo dnf install stress-ng
```

### 从源码编译
```bash
git clone https://github.com/ColinIanKing/stress-ng.git
cd stress-ng
make
sudo make install
```

## 专项测试套件（NEW）

本测试套件新增了专业的子系统专项测试脚本，包含详细的性能评级和结果解读。所有专项测试均位于 `scripts/` 目录。

### 1. 内存子系统专项测试（test_memory.sh）

**功能:** 全面的内存子系统性能评估

```bash
cd scripts
sudo ./test_memory.sh
```

**测试内容（共9项）:**
- ✓ VM 内存分配压力测试（所有内存操作方法）
- ✓ memcpy 内存拷贝带宽测试（评估内存带宽 GB/sec）
- ✓ mmap 内存映射压力测试（页面错误处理性能）
- ✓ bigheap 大堆内存测试（大页内存性能）
- ✓ malloc 动态内存分配测试（内存分配器性能）
- ✓ NUMA 内存访问测试（本地 vs 远程节点）
- ✓ memory 内存综合压力测试（多种操作混合）
- ✓ stream 内存流带宽测试（STREAM基准）
- ✓ cache 缓存压力测试（CPU缓存性能）

**性能评级:**
- VM内存分配: > 2000 ops/s ★★★★★ 优秀
- memcpy带宽: > 15 GB/s ★★★★★ 优秀(DDR4-3200)
- mmap页面错误: < 1000/s ★★★★★ 优秀

### 2. 网络子系统专项测试（test_network.sh）

**功能:** 全面的网络协议栈性能评估

```bash
cd scripts
sudo ./test_network.sh
```

**测试内容（共9项）:**
- ✓ TCP Socket 压力测试（TCP协议栈性能）
- ✓ UDP Socket 压力测试（UDP协议栈性能）
- ✓ Unix Domain Socket 测试（本地IPC性能）
- ✓ socketpair 套接字对测试（socketpair IPC）
- ✓ netdev 网络设备压力测试（网络吞吐量）
- ✓ TCP连接洪水测试（快速建立/销毁连接）
- ✓ UDP数据包洪水测试（UDP处理能力）
- ✓ ICMP Echo 压力测试（ICMP协议处理）
- ✓ sendfile 零拷贝传输测试（零拷贝性能）

**性能评级:**
- TCP Socket: > 100K ops/s ★★★★★ 优秀
- UDP Socket: > 150K ops/s ★★★★★ 优秀
- Unix Socket: > 200K ops/s ★★★★★ 优秀

### 3. 文件系统专项测试（test_filesystem.sh）

**功能:** 全面的文件系统性能评估

```bash
cd scripts
sudo ./test_filesystem.sh

# 指定测试路径（默认/tmp）
sudo TEST_MOUNT=/data ./test_filesystem.sh
```

**测试内容（共10项）:**
- ✓ HDD 文件写入压力测试（顺序写入吞吐量）
- ✓ I/O 综合压力测试（随机I/O性能 IOPS）
- ✓ sync-file 同步I/O测试（fsync/fdatasync延迟）
- ✓ dir 目录操作测试（元数据操作性能）
- ✓ flock 文件锁测试（文件锁争用）
- ✓ dentry 目录项缓存测试（目录项缓存性能）
- ✓ seek 文件seek测试（随机访问性能）
- ✓ readahead 预读测试（预读机制效率）
- ✓ aio 异步I/O测试（异步I/O性能）
- ✓ fallocate 文件预分配测试（文件空间预分配）

**性能评级:**
- NVMe SSD写入: > 2000 MB/s ★★★★★ 优秀
- SATA SSD写入: > 500 MB/s ★★★★★ 优秀
- HDD写入: > 150 MB/s ★★★★★ 优秀

### 结果详细解读

**所有测试结果的详细解读请参考: INTERPRETATION_GUIDE.md**

该指南包含：
- 基础概念（bogo ops、时间指标）
- 内存测试结果解读（VM、memcpy带宽、mmap、hugepage、NUMA）
- 网络测试结果解读（TCP/UDP/Unix Socket、吞吐量）
- 文件系统测试结果解读（HDD、I/O、sync、元数据）
- 性能优化建议（内存、网络、文件系统）

查看完整解读：
```bash
cat INTERPRETATION_GUIDE.md
```

## 测试场景说明

### 1. CPU 压力测试 (`cpu/`)

测试 CPU 计算能力和各种算法性能。

**测试内容：**
- 所有 CPU 算法测试（60秒）
- 特定算法测试（ackermann, bitops, cfloat, correlate, crc16, fibonacci, fft, int8, int64, matrix, pi, prime, sqrt）
- CPU 负载分级测试（25%, 50%, 75%, 100%）
- CPU 缓存压力测试（L1, L2, L3）

**运行方式：**
```bash
cd cpu
sudo ./test_cpu_stress.sh
```

**关键指标：**
- `bogo ops/s` - 每秒操作数（越高越好）
- `CPU used %` - CPU 使用率
- `usr time` - 用户态时间
- `sys time` - 系统态时间

### 2. 内存压力测试 (`memory/`)

测试内存分配、访问和管理性能。

**测试内容：**
- 虚拟内存压力测试（所有方法）
- 特定内存方法（flip, memset, memcpy, memmove, mmap, zero, matrix, prime）
- 内存分配/释放压力（malloc, mmap）
- 内存页面压力
- 内存带宽测试
- 内存泄漏模拟
- NUMA 内存测试（如果支持）

**运行方式：**
```bash
cd memory
sudo ./test_memory_stress.sh
```

**关键指标：**
- `bogo ops/s` - 每秒操作数
- `page faults` - 页面错误次数
- `page faults/s` - 每秒页面错误
- 内存带宽

### 3. I/O 压力测试 (`io/`)

测试磁盘和文件系统 I/O 性能。

**测试内容：**
- 同步 I/O 压力
- 异步 I/O 压力（AIO）
- 硬盘 I/O 测试（顺序/随机读写）
- Direct I/O（绕过缓存）
- fsync 压力
- 文件系统压力（目录、文件操作）
- inode 压力测试
- 文件锁压力
- 综合 I/O 压力

**运行方式：**
```bash
cd io
sudo ./test_io_stress.sh
```

**关键指标：**
- `bogo ops/s` - 每秒 I/O 操作数
- `MB/s` - 吞吐量
- I/O 延迟
- 系统态时间比例

### 4. 网络压力测试 (`network/`)

测试网络协议栈和通信性能。

**测试内容：**
- Socket 配对压力
- UDP 压力测试（IPv4/IPv6）
- UDP 洪泛测试
- TCP 压力测试
- TCP 连接建立/关闭压力
- TCP 大数据传输
- Unix Domain Socket 压力
- ICMP Echo (Ping) 压力
- Raw Socket 压力
- 多协议并发测试
- 网络缓冲区压力
- 连接数压力测试

**运行方式：**
```bash
cd network
sudo ./test_network_stress.sh
```

**关键指标：**
- `bogo ops/s` - 每秒数据包/连接数
- 网络吞吐量
- 系统态时间（协议栈开销）

### 5. 综合压力测试 (`comprehensive/`)

组合多种资源进行全面压力测试。

**测试内容：**
- CPU + 内存综合压力
- CPU + 内存 + I/O 综合压力
- 全系统压力测试（所有资源）
- 高强度短时压力（峰值负载）
- 持久稳定性测试（长时间低强度）
- 资源争用测试（文件锁、信号量、消息队列）
- 上下文切换压力
- 分阶段综合压力
- 类生产环境模拟

**运行方式：**
```bash
cd comprehensive
sudo ./test_comprehensive_stress.sh
```

**关键指标：**
- 各资源的综合使用情况
- 系统稳定性
- 资源竞争效应
- 负载均衡情况

## 快速开始

### 运行单个测试

```bash
# CPU 测试
cd tests/stress-ng/cpu
sudo ./test_cpu_stress.sh

# 内存测试
cd tests/stress-ng/memory
sudo ./test_memory_stress.sh

# I/O 测试
cd tests/stress-ng/io
sudo ./test_io_stress.sh

# 网络测试
cd tests/stress-ng/network
sudo ./test_network_stress.sh

# 综合测试
cd tests/stress-ng/comprehensive
sudo ./test_comprehensive_stress.sh
```

### 运行所有测试

```bash
cd tests/stress-ng

# 依次运行所有测试
for test in cpu memory io network comprehensive; do
    echo "Running $test tests..."
    cd $test
    sudo ./*.sh | tee ../results_${test}.log
    cd ..
done
```

## 结果解读

### 典型输出格式

```
stress-ng: info:  [PID] dispatching hogs: N <stressor>
stress-ng: info:  [PID] successful run completed in XX.XXs
stress-ng: info:  [PID] stressor       bogo ops real time  usr time  sys time   bogo ops/s
stress-ng: info:  [PID] <stressor>       XXXXX     XX.XX    XXX.XX     XX.XX      XXXX.XX
```

### 关键指标说明

| 指标 | 说明 | 最佳值 |
|------|------|--------|
| `bogo ops` | 完成的操作总数 | 越高越好 |
| `bogo ops/s (real time)` | 实际每秒操作数 | 越高越好 |
| `bogo ops/s (usr+sys time)` | CPU 时间每秒操作数 | 越高越好 |
| `real time` | 实际经过的时间 | - |
| `usr time` | 用户态 CPU 时间 | CPU密集型高 |
| `sys time` | 内核态 CPU 时间 | I/O/网络密集型高 |

### 性能分析

**CPU 密集型：**
- `usr time` >> `sys time`
- 高 `bogo ops/s`
- CPU 使用率接近 100%

**I/O 密集型：**
- `sys time` >> `usr time`
- 高 `iowait`
- 磁盘队列深度增加

**内存密集型：**
- 大量 `page faults`
- 高 `sys time`
- 可能触发 swap

**网络密集型：**
- 高 `sys time`（协议栈处理）
- 网络缓冲区使用增加

## 监控建议

在运行压力测试时，在另一个终端运行监控命令：

### 系统总览
```bash
htop              # 交互式进程查看器
top               # 传统进程监控
glances           # 综合监控
```

### CPU 监控
```bash
mpstat -P ALL 1   # 每个 CPU 的统计
sar -u 1          # CPU 使用率
```

### 内存监控
```bash
vmstat 1          # 虚拟内存统计
free -h -s 1      # 内存使用
watch -n1 'cat /proc/meminfo | head -20'
```

### I/O 监控
```bash
iostat -x 1       # I/O 统计
iotop -o          # I/O 进程监控
```

### 网络监控
```bash
iftop             # 网络流量
nload             # 网络负载
ss -s             # Socket 统计
netstat -s        # 网络统计
```

### 综合监控
```bash
dstat -tcmndylp   # 全面系统统计
```

## 最佳实践

### 测试前准备

1. **关闭不必要的服务**
   ```bash
   # 停止非关键服务
   systemctl stop <service_name>
   ```

2. **检查系统资源**
   ```bash
   # CPU 信息
   lscpu

   # 内存信息
   free -h

   # 磁盘空间
   df -h

   # 网络接口
   ip addr
   ```

3. **备份重要数据**
   ```bash
   # 备份关键配置和数据
   tar czf backup.tar.gz /path/to/data
   ```

### 测试执行

1. **从低强度开始**
   - 先运行短时间测试（10-30秒）
   - 观察系统反应
   - 逐步增加强度和时间

2. **留冷却时间**
   - 每次测试间等待 10-30 秒
   - 让系统恢复到空闲状态
   - 清理临时文件

3. **监控系统日志**
   ```bash
   # 实时监控系统日志
   tail -f /var/log/syslog

   # 监控内核消息
   dmesg -w
   ```

4. **记录测试结果**
   ```bash
   # 重定向输出到日志文件
   ./test_cpu_stress.sh | tee cpu_test_$(date +%Y%m%d_%H%M%S).log
   ```

### 安全注意事项

1. **不要在生产环境运行高强度测试**
   - 在测试环境或开发环境运行
   - 如必须在生产环境测试，选择低峰期并降低强度

2. **监控系统温度**
   ```bash
   # 查看 CPU 温度
   sensors

   # 持续监控温度
   watch -n1 sensors
   ```

3. **准备紧急停止方案**
   ```bash
   # 停止所有 stress-ng 进程
   killall stress-ng

   # 强制终止
   killall -9 stress-ng
   ```

4. **避免资源耗尽**
   - 不要使用 100% 内存（留 10-20% 余量）
   - 不要填满磁盘空间
   - 监控 swap 使用

## 故障排查

### OOM (Out of Memory)

**症状：**
- 进程被 killed
- dmesg 显示 "Out of memory"

**解决：**
```bash
# 减少内存使用
--vm-bytes 256M  # 降低内存分配

# 减少进程数
--vm 2           # 减少工作进程
```

### 磁盘空间不足

**症状：**
- "No space left on device"

**解决：**
```bash
# 清理临时文件
rm -rf /tmp/stress-ng-*

# 检查磁盘使用
df -h

# 指定较小的测试大小
--hdd-bytes 512M
```

### 系统无响应

**症状：**
- SSH 连接卡住
- 命令执行缓慢

**解决：**
1. 通过带外管理（IPMI/iLO）连接
2. 降低测试强度
3. 增加测试间隔

### 测试结果异常

**症状：**
- bogo ops/s 异常低
- 大量错误消息

**检查：**
```bash
# 检查系统负载
uptime

# 检查是否有其他进程占用资源
top

# 检查硬件错误
dmesg | grep -i error

# 检查磁盘健康
smartctl -a /dev/sda
```

## 性能基准参考

以下是典型硬件的参考值（仅供参考）：

### CPU 性能
| CPU 类型 | 核心数 | matrix ops/s (per core) |
|----------|--------|-------------------------|
| Intel i5-8250U | 4 | ~2000 |
| AMD Ryzen 5 3600 | 6 | ~2500 |
| Intel Xeon E5-2680 v4 | 14 | ~1800 |

### 内存性能
| 内存类型 | 带宽 (GB/s) | 延迟 (ns) |
|----------|-------------|-----------|
| DDR4-2400 | ~15-20 | ~60-80 |
| DDR4-3200 | ~20-25 | ~50-70 |

### I/O 性能
| 存储类型 | 顺序读 (MB/s) | 随机读 IOPS |
|----------|---------------|-------------|
| SATA SSD | ~500 | ~50k |
| NVMe SSD | ~2000+ | ~200k+ |
| HDD 7200RPM | ~150 | ~150 |

## 扩展阅读

- [stress-ng 官方文档](https://kernel.ubuntu.com/~cking/stress-ng/)
- [stress-ng GitHub](https://github.com/ColinIanKing/stress-ng)
- [stress-ng man page](https://manpages.ubuntu.com/manpages/focal/man1/stress-ng.1.html)

## 许可

本测试套件遵循与 stress-ng 相同的 GPLv2 许可。

---

**更新日期：** 2026-04-18
**作者：** Claude Code
**版本：** 1.0
