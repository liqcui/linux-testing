# STREAM 内存带宽测试套件

## 概述

STREAM是业界标准的内存带宽基准测试，用于测量可持续内存带宽和简单向量操作的性能。本测试套件提供了STREAM的完整实现和自动化测试脚本。

## 目录结构

```
stream/
├── README.md                       # 本文件
├── programs/
│   └── stream.c                    # STREAM基准测试程序
├── scripts/
│   └── test_stream.sh              # 自动化测试脚本
└── results/                        # 测试结果目录
```

## STREAM测试原理

### 测试目的

STREAM测试可持续内存带宽（Sustainable Memory Bandwidth），而非峰值带宽。它模拟了实际应用中的内存访问模式，评估系统内存子系统的实际性能。

### 四个核心操作

**1. Copy: `a[i] = b[i]`**
- 简单的内存复制操作
- 每个元素: 1次读 + 1次写 = 2次内存访问
- 最基础的内存带宽测试

**2. Scale: `a[i] = q * b[i]`**
- 缩放操作（乘以标量）
- 每个元素: 1次读 + 1次写 = 2次内存访问
- 测试内存带宽 + 简单浮点运算

**3. Add: `a[i] = b[i] + c[i]`**
- 向量加法
- 每个元素: 2次读 + 1次写 = 3次内存访问
- 测试多数组读取带宽

**4. Triad: `a[i] = b[i] + q * c[i]`**
- 综合操作（最接近实际应用）
- 每个元素: 2次读 + 1次写 = 3次内存访问
- STREAM最重要的指标

### 设计要点

```
数组大小 >> 最大缓存大小
```

- 默认数组大小: 10M元素 × 8字节 = 80MB
- 总内存需求: 3个数组 = 240MB
- 目的: 确保数据不驻留在缓存中，测试真实DRAM带宽

### 内存层次结构

```
┌─────────────┬──────────────┬────────────┬─────────────┐
│ 层次        │ 大小         │ 延迟       │ 带宽        │
├─────────────┼──────────────┼────────────┼─────────────┤
│ L1 Cache    │ 32-64 KB     │ 1-2 cycle  │ 最高        │
│ L2 Cache    │ 256-512 KB   │ ~10 cycle  │ 很高        │
│ L3 Cache    │ 8-64 MB      │ ~40 cycle  │ 高          │
│ DRAM        │ GB级         │ ~100 cycle │ 相对较低    │
└─────────────┴──────────────┴────────────┴─────────────┘
```

STREAM测试DRAM带宽，避免缓存影响。

## 前置条件

### 软件要求

```bash
# Ubuntu/Debian
sudo apt-get install build-essential

# RHEL/CentOS
sudo yum install gcc

# 可选：OpenMP支持
# Ubuntu/Debian
sudo apt-get install libomp-dev

# RHEL/CentOS
sudo yum install libgomp
```

## 运行测试

### 自动化测试

```bash
cd scripts
sudo ./test_stream.sh
```

测试将编译并运行以下配置：
1. 基准版本（无优化）
2. O2优化版本
3. O3优化版本
4. OpenMP多线程版本

### 手动编译和运行

#### 基础版本

```bash
cd programs
gcc -o stream stream.c -lm
./stream
```

#### 优化版本

```bash
# O2优化
gcc -O2 -o stream_O2 stream.c -lm

# O3优化 + 本地架构优化
gcc -O3 -march=native -o stream_O3 stream.c -lm

# OpenMP并行版本
gcc -O3 -march=native -fopenmp -o stream_omp stream.c -lm

# 设置线程数
export OMP_NUM_THREADS=4
./stream_omp
```

#### 自定义数组大小

```bash
# 编译时指定数组大小（40M元素 = 320MB）
gcc -O3 -DSTREAM_ARRAY_SIZE=40000000 -o stream stream.c -lm
```

#### 自定义迭代次数

```bash
# 运行20次迭代
gcc -O3 -DNTIMES=20 -o stream stream.c -lm
```

## 结果解读

### 输出示例

```
-------------------------------------------------------------
STREAM Benchmark - Memory Bandwidth Test
-------------------------------------------------------------
Array size = 10000000 (elements), Offset = 0 (elements)
Memory per array = 76.3 MiB (= 0.1 GiB).
Total memory required = 228.9 MiB (= 0.2 GiB).
Each kernel will be executed 10 times.
Number of Threads = 4
-------------------------------------------------------------
Function    Best Rate MB/s  Avg time     Min time     Max time
Copy:           25000.0    0.006400     0.006400     0.006500
Scale:          24500.0    0.006530     0.006530     0.006600
Add:            26000.0    0.009230     0.009230     0.009300
Triad:          25800.0    0.009300     0.009300     0.009400
-------------------------------------------------------------
Solution Validates
-------------------------------------------------------------
```

### 关键指标

**Best Rate (MB/s):**
- 最重要的指标
- Triad带宽最能代表实际应用性能
- 越高越好

**Min/Avg/Max time:**
- 最小时间对应最佳带宽
- 时间稳定性反映系统一致性

### 性能参考

| 内存类型 | 理论带宽 | STREAM Triad | 效率 |
|---------|---------|-------------|------|
| DDR4-2400 (单通道) | 19.2 GB/s | 12-15 GB/s | 60-80% |
| DDR4-3200 (单通道) | 25.6 GB/s | 16-20 GB/s | 60-80% |
| DDR4-3200 (双通道) | 51.2 GB/s | 32-40 GB/s | 60-80% |
| DDR5-4800 (双通道) | 76.8 GB/s | 50-60 GB/s | 65-80% |

**注意:** 实际带宽通常为理论峰值的60-80%

## 性能优化

### 1. 编译优化

**推荐编译选项:**
```bash
gcc -O3 -march=native -mtune=native -fopenmp stream.c -lm
```

**重要标志:**
- `-O3`: 最高优化级别
- `-march=native`: 针对当前CPU优化
- `-mtune=native`: 调整指令调度
- `-fopenmp`: 启用OpenMP多线程

### 2. 运行时优化

**CPU频率:**
```bash
# 禁用节能模式
sudo cpupower frequency-set -g performance

# 查看当前频率
cat /proc/cpuinfo | grep "cpu MHz"
```

**CPU亲和性（NUMA系统）:**
```bash
# 绑定到NUMA节点0
numactl --cpunodebind=0 --membind=0 ./stream

# 查看NUMA拓扑
numactl --hardware
```

**Huge Pages:**
```bash
# 配置Huge Pages
echo 1024 | sudo tee /proc/sys/vm/nr_hugepages

# 编译支持Huge Pages的版本（需要修改代码）
```

**禁用透明大页（某些场景）:**
```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

### 3. OpenMP线程数

```bash
# 设置为物理核心数（推荐）
export OMP_NUM_THREADS=$(lscpu | grep "Core(s)" | awk '{print $NF}')

# 或设置为逻辑核心数
export OMP_NUM_THREADS=$(nproc)

# 禁用超线程可能更好
export OMP_NUM_THREADS=4  # 假设4个物理核心
```

## 常见问题

### 1. 带宽远低于预期

**原因:**
- 编译器优化不足
- CPU节能模式启用
- NUMA配置不当
- 后台进程占用

**解决:**
```bash
# 1. 使用O3优化
gcc -O3 -march=native stream.c -lm

# 2. 性能模式
sudo cpupower frequency-set -g performance

# 3. NUMA优化
numactl --cpunodebind=0 --membind=0 ./stream

# 4. 减少后台进程
sudo systemctl stop <不必要的服务>
```

### 2. 验证失败 (Solution Does Not Validate)

**原因:**
- 编译器过度优化导致错误
- 硬件问题
- 数组大小不合适

**解决:**
```bash
# 降低优化级别
gcc -O2 stream.c -lm

# 或禁用特定优化
gcc -O3 -fno-tree-vectorize stream.c -lm
```

### 3. OpenMP版本性能反而下降

**原因:**
- 线程数设置不当
- NUMA访问不均衡
- 伪共享（False Sharing）

**解决:**
```bash
# 设置合适的线程数
export OMP_NUM_THREADS=物理核心数

# NUMA绑定
export OMP_PROC_BIND=true
```

### 4. 结果波动大

**原因:**
- Turbo Boost动态调频
- 后台进程干扰
- 温度限制降频

**解决:**
```bash
# 禁用Turbo Boost
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# 固定频率
sudo cpupower frequency-set -f 3.0GHz

# 关闭不必要的服务
```

## 测试结果

运行`test_stream.sh`后生成以下文件：

- `principles.txt` - STREAM测试原理
- `sysinfo.txt` - 系统信息（CPU、缓存、内存）
- `compile.txt` - 编译配置
- `stream_baseline.txt` - 基准版本结果
- `stream_O2.txt` - O2优化结果
- `stream_O3.txt` - O3优化结果
- `stream_omp.txt` - OpenMP版本结果
- `comparison.txt` - 结果对比
- `analysis.txt` - 性能分析和建议
- `summary.txt` - 测试总结

## 应用场景

### 1. 硬件选型

比较不同系统的内存性能：
```bash
# 系统A
Triad: 25000 MB/s

# 系统B
Triad: 18000 MB/s

# 系统A内存带宽优势明显
```

### 2. 性能回归测试

```bash
# 内核升级前
Triad: 25000 MB/s

# 内核升级后
Triad: 23000 MB/s

# 发现性能退化，需调查原因
```

### 3. 优化效果验证

```bash
# 优化前（默认编译）
Triad: 15000 MB/s

# 优化后（O3 + OpenMP）
Triad: 25000 MB/s

# 性能提升 67%
```

### 4. 虚拟化性能评估

```bash
# 物理机
Triad: 25000 MB/s

# 虚拟机
Triad: 22000 MB/s

# 虚拟化开销约 12%
```

## 与其他基准测试对比

| 基准测试 | 测试对象 | 优势 | 劣势 |
|---------|---------|------|------|
| STREAM | 内存带宽 | 简单、标准、可重复 | 仅测试顺序访问 |
| LMbench | 系统微基准 | 全面（延迟+带宽） | 复杂度高 |
| SPEC CPU | 应用性能 | 接近实际应用 | 运行时间长 |
| Sysbench | 数据库/IO | 实际应用场景 | 配置复杂 |

## 参考资料

- [STREAM官方网站](https://www.cs.virginia.edu/stream/)
- [STREAM FAQ](https://www.cs.virginia.edu/stream/ref.html)
- [内存带宽优化指南](https://software.intel.com/content/www/us/en/develop/articles/memory-bandwidth-optimization.html)
- [OpenMP最佳实践](https://www.openmp.org/resources/tutorials-articles/)

---

**更新日期:** 2026-04-19
**版本:** 1.0
