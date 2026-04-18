# 内存访问性能测试

## 概述

`mem_test` 是一个用于测试和分析内存访问模式、缓存行为和伪共享的工具。它可以帮助你：
- 了解不同内存访问模式的性能差异
- 分析缓存命中率和未命中率
- 检测伪共享（False Sharing）问题
- 优化内存访问性能

---

## 快速开始

### 编译

```bash
cd tests/mem
make
```

### 运行

```bash
# 基本运行
./mem_test

# 使用 perf mem 分析
make perf-mem-record   # 记录内存访问
make perf-mem-report   # 分析报告

# 或者一步完成
make perf
```

---

## 测试内容

### 1. 顺序读（Sequential Read）

**特点**:
- 按地址顺序读取内存
- 对缓存友好
- 可利用硬件预取

**典型性能**: 5000-20000 MB/s（取决于内存带宽）

**示例**:
```bash
./mem_test -t 1 -s 128
```

### 2. 顺序写（Sequential Write）

**特点**:
- 按地址顺序写入内存
- 可利用写合并优化
- 对缓存友好

**典型性能**: 3000-15000 MB/s

**示例**:
```bash
./mem_test -t 2 -s 128
```

### 3. 随机读（Random Read）

**特点**:
- 随机地址读取
- 缓存不友好
- 大量缓存未命中

**典型性能**: 500-2000 MB/s（慢 10-20 倍）

**示例**:
```bash
./mem_test -t 3 -s 128
```

### 4. 随机写（Random Write）

**特点**:
- 随机地址写入
- 无法利用写合并
- 大量缓存未命中

**典型性能**: 300-1500 MB/s

### 5. 跨步读（Stride Read）

**特点**:
- 每次跳过一个缓存行（64 bytes）
- 浪费缓存带宽
- 测试空间局部性影响

**典型性能**: 1000-5000 MB/s

**示例**:
```bash
./mem_test -t 5
```

### 6. 伪共享（False Sharing）

**特点**:
- 多线程写相邻内存（同一缓存行）
- 缓存行颠簸
- 性能严重下降

**典型性能**: 比无伪共享慢 2-10 倍

**示例**:
```bash
./mem_test -t 6 -p 8
```

### 7. 无伪共享（Padded）

**特点**:
- 每个线程独立缓存行（有 padding）
- 无缓存行颠簸
- 性能最优

**示例**:
```bash
./mem_test -t 7 -p 8
```

---

## 命令行选项

```bash
./mem_test [选项]

选项:
  -t <type>    测试类型 (1-8, 默认: 8)
               1 = 顺序读
               2 = 顺序写
               3 = 随机读
               4 = 随机写
               5 = 跨步读
               6 = 伪共享
               7 = 无伪共享
               8 = 全部测试
  -s <size>    缓冲区大小 MB (默认: 64)
  -n <num>     迭代次数 (默认: 10)
  -p <num>     线程数 (默认: 4)
  -h           显示帮助信息
```

---

## 使用 perf mem 分析

### 基本分析流程

```bash
# 1. 记录内存访问事件
perf mem record ./mem_test

# 2. 查看报告
perf mem report

# 3. 查看详细信息
perf mem report -v
```

### perf mem report 输出解析

**示例输出**:
```
# Samples: 10K of event 'cpu/mem-loads,ldlat=30/P'
# Total Lost Samples: 0
#
# Overhead  Samples  Local Weight  Memory access
# ........  .......  ............  .............
#
    45.23%     4523        125     L1 hit
    32.15%     3215        234     L2 hit
    18.42%     1842        567     L3 hit
     4.20%      420       1234     RAM hit
```

**字段说明**:
- **Overhead**: 占总样本的百分比
- **Samples**: 采样次数
- **Local Weight**: 平均延迟（时钟周期）
- **Memory access**: 内存访问类型
  - L1 hit: L1 缓存命中
  - L2 hit: L2 缓存命中
  - L3 hit: L3 缓存命中（LLC）
  - RAM hit: 访问主内存

### 使用 perf stat 分析缓存

```bash
# 查看缓存统计
perf stat -e cache-references,cache-misses,LLC-loads,LLC-load-misses ./mem_test

# 输出示例:
#    234,567,890      cache-references
#     12,345,678      cache-misses      #    5.27% of all cache refs
#     45,678,901      LLC-loads
#      8,901,234      LLC-load-misses   #   19.49% of all LL-cache hits
```

**关键指标**:
- **cache-misses**: 缓存未命中次数
- **cache miss rate**: 缓存未命中率
  - < 1%: 优秀
  - 1-5%: 良好
  - 5-10%: 一般
  - > 10%: 需要优化

---

## 性能基准

### 不同访问模式对比

| 访问模式 | 典型带宽 | 缓存未命中率 | 相对性能 |
|---------|----------|-------------|---------|
| 顺序读 | 15000 MB/s | < 1% | 1.0x |
| 顺序写 | 10000 MB/s | < 1% | 0.67x |
| 跨步读 | 3000 MB/s | 5-10% | 0.2x |
| 随机读 | 1000 MB/s | > 20% | 0.07x |
| 随机写 | 800 MB/s | > 20% | 0.05x |

*注: 实际性能取决于硬件配置*

### 缓存层次性能

| 缓存级别 | 容量 | 延迟 | 带宽 |
|---------|------|------|------|
| L1 | 32-64 KB | ~4 cycles | ~500 GB/s |
| L2 | 256-512 KB | ~12 cycles | ~200 GB/s |
| L3 (LLC) | 8-64 MB | ~40 cycles | ~100 GB/s |
| RAM | 8-128 GB | ~200 cycles | ~50 GB/s |

---

## 内存优化建议

### 1. 使用顺序访问

**差**: 随机访问
```c
for (i = 0; i < n; i++) {
    index = random() % n;
    sum += array[index];  // 随机访问
}
// 性能: 1000 MB/s
```

**好**: 顺序访问
```c
for (i = 0; i < n; i++) {
    sum += array[i];  // 顺序访问
}
// 性能: 15000 MB/s (提升 15倍)
```

### 2. 提高空间局部性

**差**: 大步长访问
```c
for (i = 0; i < n; i += 1024) {
    sum += array[i];  // 跳过很多元素
}
// 浪费缓存行，缓存未命中率高
```

**好**: 小步长访问
```c
for (i = 0; i < n; i++) {
    sum += array[i];  // 连续访问
}
// 利用缓存行，缓存未命中率低
```

### 3. 避免伪共享

**差**: 相邻数据（伪共享）
```c
struct {
    long counter1;  // 线程1写
    long counter2;  // 线程2写
} data;  // 在同一缓存行！

// 性能差，缓存行颠簸
```

**好**: 填充分离（无伪共享）
```c
struct {
    long counter1;
    char padding[64 - sizeof(long)];
} thread_data[N];  // 每个线程独立缓存行

// 性能好，无缓存行颠簸
// 提升 2-10倍
```

### 4. 数据结构布局优化

**差**: AoS (Array of Structures)
```c
struct Point {
    float x, y, z;
    int id;
};
Point points[N];

// 计算所有 x 坐标和
for (i = 0; i < N; i++) {
    sum += points[i].x;  // 跨步访问，浪费缓存
}
```

**好**: SoA (Structure of Arrays)
```c
struct {
    float x[N];
    float y[N];
    float z[N];
    int id[N];
} points;

// 计算所有 x 坐标和
for (i = 0; i < N; i++) {
    sum += points.x[i];  // 连续访问，缓存友好
}
// 提升 2-4倍
```

---

## 高级用法

### 测试不同缓冲区大小

```bash
# 测试 L1 缓存大小（32 KB）
./mem_test -s 0.03125 -t 1

# 测试 L2 缓存大小（256 KB）
./mem_test -s 0.25 -t 1

# 测试 L3 缓存大小（8 MB）
./mem_test -s 8 -t 1

# 测试超过 L3（64 MB）
./mem_test -s 64 -t 1

# 测试超大（512 MB）
./mem_test -s 512 -t 1
```

### 对比伪共享影响

```bash
# 运行两个测试对比
./mem_test -t 6 -p 8  # 伪共享
./mem_test -t 7 -p 8  # 无伪共享

# 性能差异应该是 2-10 倍
```

### 结合 perf c2c 分析

```bash
# perf c2c 可以检测缓存行颠簸
perf c2c record ./mem_test -t 6 -p 8
perf c2c report
```

---

## 实际应用场景

### 1. 数据库系统

```c
// 优化表扫描：顺序访问 vs 随机访问
// 顺序扫描：15000 MB/s
for (i = 0; i < num_rows; i++) {
    process_row(&table[i]);
}

// 索引查找：1000 MB/s（随机访问）
for (i = 0; i < num_queries; i++) {
    row = index_lookup(query[i]);
    process_row(row);
}
```

### 2. 高性能计算

```c
// 矩阵运算：优化内存访问顺序

// 差：列优先访问（C语言行优先）
for (i = 0; i < N; i++) {
    for (j = 0; j < N; j++) {
        sum += matrix[j][i];  // 跨行访问
    }
}

// 好：行优先访问
for (i = 0; i < N; i++) {
    for (j = 0; j < N; j++) {
        sum += matrix[i][j];  // 顺序访问
    }
}
```

### 3. 多线程编程

```c
// 避免伪共享

// 差：共享缓存行
long counters[NUM_THREADS];  // 可能在同一缓存行

// 好：独立缓存行
struct {
    long counter;
    char padding[64 - sizeof(long)];
} counters[NUM_THREADS];
```

---

## 常见问题

### Q: perf mem record 失败怎么办？

**A**: 检查权限和硬件支持

```bash
# 检查权限
cat /proc/sys/kernel/perf_event_paranoid
# 如果 > 1，降低限制
echo 0 | sudo tee /proc/sys/kernel/perf_event_paranoid

# 检查硬件是否支持 PEBS（Intel）或 IBS（AMD）
perf mem record -e list
```

### Q: 为什么顺序访问比随机访问快那么多？

**A**:
1. **缓存预取**: CPU 自动预取连续地址
2. **缓存命中率**: 顺序访问命中率 > 99%，随机访问 < 80%
3. **TLB**: 顺序访问减少页表查找

### Q: 如何检测伪共享？

**A**:
```bash
# 方法1: 对比性能
./mem_test -t 6  # 伪共享
./mem_test -t 7  # 无伪共享
# 如果性能差异 > 2倍，可能有伪共享

# 方法2: 使用 perf c2c
perf c2c record ./your_program
perf c2c report
```

---

## 参考资料

- [Intel 优化手册](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [What Every Programmer Should Know About Memory](https://people.freebsd.org/~lstewart/articles/cpumemory.pdf)
- [Gallery of Processor Cache Effects](http://igoro.com/archive/gallery-of-processor-cache-effects/)
- [Perf Wiki - Memory](https://perf.wiki.kernel.org/index.php/Tutorial#Profiling_memory_accesses)

---

**最后更新**: 2026-04-18
