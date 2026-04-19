# rt-tests - 实时性能测试套件

## 概述

rt-tests 是用于测试 Linux 实时性能的工具集，主要用于评估系统的实时响应能力和延迟特性。这对于工业控制、机器人、音频处理等对实时性要求高的应用至关重要。

## 核心测试工具

### 1. cyclictest（最常用）
测量系统延迟，包括中断延迟、调度延迟等。

### 2. pi_stress
测试优先级继承（Priority Inheritance）互斥锁。

### 3. deadline_test
测试 SCHED_DEADLINE 调度器。

### 4. signaltest
测试信号延迟。

### 5. hackbench
测试调度器性能和吞吐量。

## 目录结构

```
rt-tests/
├── README.md                              # 本文件
├── install_rt_tests.sh                    # 自动安装脚本
├── scripts/
│   ├── test_cyclictest.sh                 # cyclictest 基础测试
│   ├── cyclictest_rt_full.sh              # 完整实时性测试（NEW）
│   ├── cyclictest_three_scenarios.sh      # 三种场景对比测试（NEW）
│   ├── stress_cyclictest_integrated.sh    # 压力+实时性综合测试（NEW）
│   ├── adaptive_stress_rt_test.sh         # 动态压力调节测试（NEW）
│   ├── generate_histogram.sh              # 生成延迟直方图（NEW）
│   ├── generate_comparison_plot.sh        # 生成多场景对比图（NEW）
│   ├── generate_cdf_plot.sh               # 生成CDF累积分布图（NEW）
│   ├── test_pi_stress.sh                  # PI 互斥锁测试
│   ├── test_with_load.sh                  # 带负载的实时性测试
│   └── analyze_results.sh                 # 结果分析脚本
├── mock_programs/
│   ├── rt_workload.c                      # 实时工作负载模拟
│   ├── interrupt_generator.c              # 中断生成器
│   └── Makefile
└── results/                               # 测试结果存储
```

## 快速开始

### 1. 安装 rt-tests

```bash
# 自动安装
sudo ./install_rt_tests.sh

# 或手动安装（Ubuntu/Debian）
sudo apt-get install rt-tests

# RHEL/CentOS
sudo yum install rt-tests

# Fedora
sudo dnf install rt-tests
```

### 2. 运行基础测试

```bash
# cyclictest 基础测试（3线程，1ms间隔）
sudo cyclictest -m -a -p 99 -t 3 -i 1000 -n

# 带直方图输出
cd scripts
sudo ./test_cyclictest.sh
```

### 3. 运行带负载的测试

```bash
cd scripts
sudo ./test_with_load.sh
```

## 高级测试套件（NEW）

本测试套件新增了专业的实时性分析工具，包括完整的调度策略测试、多场景对比和可视化分析。

### 1. 完整实时性测试（cyclictest_rt_full.sh）

**功能:** 全面的实时性能评估，包括不同调度策略、CPU亲和性、优先级分布测试

```bash
cd scripts
sudo ./cyclictest_rt_full.sh
```

**测试内容:**
- ✓ 测试1: 单线程 SCHED_FIFO 优先级99（最高优先级基准）
- ✓ 测试2: 多线程优先级分布（99, 80, 60, 40）
- ✓ 测试3: CPU亲和性绑定测试（隔离CPU）
- ✓ 测试4: 调度策略对比（SCHED_FIFO vs SCHED_RR vs SCHED_OTHER）

**输出:**
```
cyclictest_rt_full_20260419_143022/
├── system_info.txt              # 系统配置信息
├── test1_fifo99.log             # 单线程FIFO测试
├── test2_multi_prio.log         # 多优先级测试
├── test3_cpu2_isolated.log      # CPU隔离测试
├── test4_fifo.log               # SCHED_FIFO策略
├── test4_rr.log                 # SCHED_RR策略
├── test4_other.log              # SCHED_OTHER策略
└── summary_report.txt           # 综合分析报告
```

**关键发现:**
- 识别最优调度策略
- 评估CPU隔离效果
- 检测SMI中断干扰
- 提供针对性优化建议

### 2. 三种场景对比测试（cyclictest_three_scenarios.sh）

**功能:** 对比空载、CPU满载、I/O压力、组合压力四种场景下的实时性能

```bash
cd scripts
sudo ./cyclictest_three_scenarios.sh
```

**测试场景:**
1. **空载（Baseline）**: 无额外负载，理想情况基准
2. **CPU满载**: 所有CPU核心100%负载，测试调度延迟
3. **I/O压力**: 磁盘I/O密集型负载，测试I/O干扰
4. **组合压力**: CPU + I/O混合负载，模拟真实环境

**输出:**
```
cyclictest_scenarios_20260419_143022/
├── scenario1_idle.log           # 空载测试日志
├── scenario1_idle.hist          # 空载延迟直方图
├── scenario2_cpu_load.log       # CPU满载日志
├── scenario2_cpu_load.hist      # CPU满载直方图
├── scenario3_io_load.log        # I/O压力日志
├── scenario3_io_load.hist       # I/O压力直方图
├── scenario4_combo.log          # 组合压力日志
├── scenario4_combo.hist         # 组合压力直方图
├── comparison_report.txt        # 对比分析报告
└── plot_data.txt                # gnuplot数据文件
```

**对比报告示例:**
```
场景          最小延迟(μs)   平均延迟(μs)   最大延迟(μs)   恶化倍数
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
空载(基准)    2              8              45             1.00x
CPU满载       3              12             78             1.73x
I/O压力       2              15             124            2.76x
组合压力      3              18             156            3.47x
```

### 3. 可视化分析工具

#### 3.1 生成单场景直方图（generate_histogram.sh）

**功能:** 从cyclictest直方图数据生成专业的SVG可视化图表

```bash
cd scripts
./generate_histogram.sh ../results/scenario1_idle.hist idle_histogram.svg
```

**图表特性:**
- 对数Y轴显示完整分布
- 自动标注99百分位线
- 显示总样本数、最大延迟统计
- SVG格式支持缩放和交互

#### 3.2 生成多场景对比图（generate_comparison_plot.sh）

**功能:** 2x2多图布局对比不同场景的延迟分布

```bash
cd scripts
./generate_comparison_plot.sh ../results/cyclictest_scenarios_20260419_143022
```

**图表布局:**
```
┌─────────────────┬─────────────────┐
│ 场景1: 空载     │ 场景2: CPU满载  │
│ (Baseline)      │ (CPU Impact)    │
├─────────────────┼─────────────────┤
│ 场景3: I/O压力  │ 场景4: 叠加对比 │
│ (I/O Impact)    │ (Normalized)    │
└─────────────────┴─────────────────┘
```

**输出:** `latency_comparison.svg`

#### 3.3 生成CDF累积分布图（generate_cdf_plot.sh）

**功能:** 生成CDF（累积分布函数）曲线，用于百分位数分析

```bash
cd scripts
./generate_cdf_plot.sh ../results/cyclictest_scenarios_20260419_143022
```

**CDF图优势:**
- 直观显示延迟分布特征
- 精确读取任意百分位数（P50, P90, P99, P99.9）
- 对比不同场景的延迟累积情况
- 识别长尾延迟问题

**输出文件:**
- `cdf_comparison.svg` - CDF对比图
- `percentile_analysis.txt` - 百分位数分析报告

**百分位数示例:**
```
场景                P50        P90        P99       P99.9
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
idle                 6μs       12μs       38μs       89μs
cpu load            10μs       24μs       72μs      145μs
io pressure         12μs       45μs      118μs      234μs
```

### 完整工作流示例

```bash
cd scripts

# 步骤1: 运行完整实时性测试
sudo ./cyclictest_rt_full.sh

# 步骤2: 运行三种场景对比测试（需要15-20分钟）
sudo ./cyclictest_three_scenarios.sh

# 步骤3: 生成可视化图表
RESULT_DIR="../results/cyclictest_scenarios_20260419_143022"

# 3.1 生成单场景直方图
./generate_histogram.sh $RESULT_DIR/scenario1_idle.hist $RESULT_DIR/idle_hist.svg

# 3.2 生成多场景对比图
./generate_comparison_plot.sh $RESULT_DIR

# 3.3 生成CDF分析
./generate_cdf_plot.sh $RESULT_DIR

# 步骤4: 查看分析报告
cat $RESULT_DIR/comparison_report.txt
cat $RESULT_DIR/percentile_analysis.txt

# 步骤5: 在浏览器中查看图表
open $RESULT_DIR/*.svg
```

### 4. 压力+实时性综合测试（stress_cyclictest_integrated.sh）

**功能:** 在多种系统压力下全面评估实时性能，识别不同负载类型对延迟的影响

```bash
cd scripts
sudo ./stress_cyclictest_integrated.sh
```

**测试场景（共6种）:**
1. **CPU压力 (ackermann)**: Ackermann递归算法，模拟CPU密集型计算
2. **内存压力 (80%)**: 占用80%系统内存，测试内存压力影响
3. **I/O压力 (混合)**: 8个I/O线程 + 4个HDD线程，测试磁盘I/O干扰
4. **组合压力**: CPU + I/O + 内存混合负载，最坏情况测试
5. **FFT算法压力**: 快速傅里叶变换，模拟科学计算场景
6. **矩阵运算压力**: 矩阵乘法，模拟密集计算场景

**每个场景测试时长**: 300秒（5分钟）

**输出文件:**
```
stress_rt_test_20260419_143022/
├── system_info.txt                  # 系统配置
├── test1_cpu_rt.log                 # CPU压力测试日志
├── test1_cpu_rt.hist                # CPU压力直方图
├── test2_memory_rt.log              # 内存压力日志
├── test2_memory_rt.hist             # 内存压力直方图
├── test3_io_rt.log                  # I/O压力日志
├── test3_io_rt.hist                 # I/O压力直方图
├── test4_combo_rt.log               # 组合压力日志
├── test4_combo_rt.hist              # 组合压力直方图
├── test5_fft_rt.log                 # FFT压力日志
├── test5_fft_rt.hist                # FFT压力直方图
├── test6_matrix_rt.log              # 矩阵压力日志
├── test6_matrix_rt.hist             # 矩阵压力直方图
├── stress_cpu_ackermann.log         # stress-ng CPU指标
├── stress_memory.log                # stress-ng 内存指标
├── stress_io.log                    # stress-ng I/O指标
├── stress_combo.log                 # stress-ng 组合指标
├── stress_fft.log                   # stress-ng FFT指标
├── stress_matrix.log                # stress-ng 矩阵指标
└── integrated_report.txt            # 综合分析报告
```

**报告示例:**
```
测试场景汇总
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
场景                 最小(μs)   平均(μs)   最大(μs)   性能评级
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CPU压力(ackermann)   3          15         89         ★★★★☆ 良好(软实时)
内存压力(80%)        2          12         124        ★★★☆☆ 一般(准实时)
I/O压力(混合)        3          18         156        ★★★☆☆ 一般(准实时)
组合压力             4          22         234        ★★☆☆☆ 差(非实时)
FFT算法压力          3          16         102        ★★★☆☆ 一般(准实时)
矩阵运算压力         3          14         78         ★★★★☆ 良好(软实时)
```

**关键分析:**
- **压力类型影响**: 识别哪种负载类型影响最大
- **算法对比**: 比较不同CPU密集型算法的延迟差异
- **SMI中断检测**: 组合压力测试包含SMI检测
- **最差场景识别**: 自动找出最影响实时性的场景

### 5. 动态压力调节测试（adaptive_stress_rt_test.sh）

**功能:** 阶梯式增加系统压力，绘制压力-延迟曲线，找到系统实时性能极限

```bash
cd scripts
sudo ./adaptive_stress_rt_test.sh
```

**测试内容:**

**1. 阶梯式CPU压力测试**
- 压力级别: 10%, 25%, 50%, 75%, 90%, 100%
- 每级测试时长: 60秒
- 自动检测系统实时性能极限

**2. CPU算法影响对比**
- 测试算法: ackermann, fft, matrixprod, correlate, trig
- 评估不同算法类型的延迟影响
- 识别最优和最差算法

**输出文件:**
```
adaptive_rt_20260419_143022/
├── load_10.log                      # 10%负载测试日志
├── load_10.hist                     # 10%负载直方图
├── load_25.log                      # 25%负载测试日志
├── load_25.hist                     # 25%负载直方图
├── load_50.log                      # 50%负载测试日志
├── load_50.hist                     # 50%负载直方图
├── load_75.log                      # 75%负载测试日志
├── load_75.hist                     # 75%负载直方图
├── load_90.log                      # 90%负载测试日志
├── load_90.hist                     # 90%负载直方图
├── load_100.log                     # 100%负载测试日志
├── load_100.hist                    # 100%负载直方图
├── method_ackermann.log             # Ackermann算法测试
├── method_fft.log                   # FFT算法测试
├── method_matrixprod.log            # 矩阵乘法测试
├── method_correlate.log             # 相关性计算测试
├── method_trig.log                  # 三角函数测试
├── latency_curve.txt                # 压力-延迟数据点
├── latency_curve.svg                # 压力-延迟曲线图（SVG）
├── method_comparison.txt            # 算法对比数据
├── method_comparison.svg            # 算法对比柱状图（SVG）
└── adaptive_report.txt              # 综合分析报告
```

**压力-延迟曲线图特性:**
- X轴: CPU负载百分比 (0-100%)
- Y轴: 延迟 (μs)
- 三条曲线:
  - 最大延迟（红色）
  - 平均延迟（蓝色）
  - 最小延迟（绿色）
- 参考线: 50μs（硬实时）、100μs（软实时）

**关键分析指标:**

1. **压力-延迟线性度**
```
10%负载延迟: 15μs
100%负载延迟: 89μs
延迟增长: +74μs (5.93倍)

结论: ★★★★☆ 延迟增长适中，实时性能良好
```

2. **CPU算法影响**
```
CPU方法              平均延迟(μs)   最大延迟(μs)
────────────────────────────────────────────
ackermann            15             89
fft                  18             124
matrixprod           12             67
correlate            16             98
trig                 14             78

最优算法: matrixprod (67μs)
最差算法: fft (124μs)
```

3. **系统极限检测**
- 自动检测延迟超过1ms的负载级别
- 提供负载上限建议
- 评估系统可承受的最大压力

**使用建议:**
- **容量规划**: 了解系统在不同负载下的实时性表现
- **负载上限**: 确定实时任务可承受的最大系统负载
- **算法选择**: 为实时系统选择延迟影响较小的算法

### 压力测试完整工作流

```bash
cd scripts

# 步骤1: 压力+实时性综合测试（约30分钟）
sudo ./stress_cyclictest_integrated.sh

# 步骤2: 动态压力调节测试（约10分钟）
sudo ./adaptive_stress_rt_test.sh

# 步骤3: 查看综合报告
STRESS_DIR="../results/stress_rt_test_20260419_143022"
ADAPTIVE_DIR="../results/adaptive_rt_20260419_143022"

cat $STRESS_DIR/integrated_report.txt
cat $ADAPTIVE_DIR/adaptive_report.txt

# 步骤4: 查看可视化图表
open $ADAPTIVE_DIR/latency_curve.svg
open $ADAPTIVE_DIR/method_comparison.svg

# 步骤5: 生成对比图表（可选）
./generate_comparison_plot.sh $STRESS_DIR
./generate_cdf_plot.sh $STRESS_DIR
```

## cyclictest 详解

### 基础用法

```bash
# 最简单的测试
sudo cyclictest -t 1 -p 99 -i 1000 -n

# 参数说明：
#   -t NUM   : 线程数
#   -p PRIO  : 实时优先级 (1-99，99最高)
#   -i USEC  : 间隔时间（微秒）
#   -n       : 使用 clock_nanosleep
```

### 常用参数组合

```bash
# 1. 标准测试（推荐）
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n -q -D 60m

# 参数详解：
#   -m          : 锁定内存（防止页面交换）
#   -a          : 亲和性，将线程绑定到各个 CPU
#   -p 99       : 最高实时优先级
#   -t 4        : 4 个线程（通常等于 CPU 核心数）
#   -i 1000     : 1000 微秒 = 1 毫秒间隔
#   -n          : 使用 clock_nanosleep（更精确）
#   -q          : 安静模式（减少输出）
#   -D 60m      : 运行 60 分钟

# 2. 生成直方图数据
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n \
    --histogram=1000 -D 60m > histogram.dat

# 3. 带统计信息
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n \
    -S -D 10m

# 参数：
#   -S          : 打印统计信息
```

### 结果解读

```
T: 0 ( 1234) P:99 I:1000 C:  60000 Min:   2 Act:   5 Avg:   6 Max:  18
```

| 字段 | 说明 |
|------|------|
| T:0  | 线程 0 |
| PID  | 进程 ID |
| P:99 | 优先级 99 |
| I:1000 | 间隔 1000μs |
| C:60000 | 已完成 60000 次循环 |
| Min:2 | 最小延迟 2μs |
| Act:5 | 当前延迟 5μs |
| Avg:6 | 平均延迟 6μs |
| Max:18 | **最大延迟 18μs（关键指标）** |

**延迟评估标准：**
- **优秀**: Max < 50μs
- **良好**: Max < 100μs
- **可接受**: Max < 200μs
- **需要优化**: Max > 200μs

## 带负载的实时性测试

实时系统必须在高负载下保持低延迟。

### 使用 stress-ng 生成负载

```bash
# 启动系统负载（后台运行）
stress-ng --cpu 4 --io 2 --vm 2 --timeout 300s &

# 在负载下测试实时性
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n -q -D 300s

# 对比：无负载 vs 有负载的延迟差异
```

### 组合测试脚本

```bash
#!/bin/bash
# 先测试无负载情况
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n -D 60s > no-load.log

# 启动负载
stress-ng --cpu $(nproc) --io 4 --vm 2 --timeout 120s &

sleep 5

# 测试有负载情况
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n -D 60s > with-load.log

# 对比结果
echo "无负载最大延迟:"
grep "Max:" no-load.log
echo ""
echo "有负载最大延迟:"
grep "Max:" with-load.log
```

## 直方图生成与可视化

### 生成直方图数据

```bash
# 运行测试并保存直方图
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n \
    --histogram=1000 -D 60m > histogram.dat

# 参数：
#   --histogram=1000  : 记录延迟分布，最大值1000μs
```

### 使用 gnuplot 可视化

```bash
# 安装 gnuplot
sudo apt-get install gnuplot    # Ubuntu/Debian
sudo yum install gnuplot        # RHEL/CentOS

# 生成图表
gnuplot << 'EOF'
set terminal png size 1024,768
set output 'latency.png'
set title "Cyclictest Latency Histogram"
set xlabel "Latency (microseconds)"
set ylabel "Samples"
set grid
plot 'histogram.dat' using 1:2 with lines title "Thread 0", \
     'histogram.dat' using 1:3 with lines title "Thread 1", \
     'histogram.dat' using 1:4 with lines title "Thread 2", \
     'histogram.dat' using 1:5 with lines title "Thread 3"
EOF

# 查看图表
xdg-open latency.png
```

### Python 可视化（推荐）

```python
#!/usr/bin/env python3
import matplotlib.pyplot as plt
import numpy as np

# 读取数据
data = np.loadtxt('histogram.dat')

# 绘制直方图
plt.figure(figsize=(12, 6))
for i in range(1, data.shape[1]):
    plt.plot(data[:, 0], data[:, i], label=f'Thread {i-1}')

plt.xlabel('Latency (μs)')
plt.ylabel('Samples')
plt.title('Cyclictest Latency Distribution')
plt.legend()
plt.grid(True)
plt.savefig('latency_distribution.png', dpi=150)
print("图表已保存: latency_distribution.png")
```

## pi_stress - 优先级继承测试

### 基础用法

```bash
# 基本测试
sudo pi_stress

# 指定测试参数
sudo pi_stress --groups=10 --duration=300

# 参数：
#   --groups=N    : 线程组数量
#   --duration=S  : 测试时长（秒）
#   --verbose     : 详细输出
```

### 测试目的

验证系统是否正确实现优先级继承（Priority Inheritance），防止优先级反转问题。

**优先级反转场景：**
1. 低优先级任务 L 获得锁
2. 高优先级任务 H 尝试获取同一锁，被阻塞
3. 中优先级任务 M 抢占 L
4. 结果：H 被 M 间接阻塞（优先级反转）

**优先级继承解决方案：**
当 H 被 L 持有的锁阻塞时，L 临时继承 H 的优先级。

## deadline_test - SCHED_DEADLINE 测试

### 基础用法

```bash
# SCHED_DEADLINE 调度器测试
sudo deadline_test -p 80 -r 100 -d 10 -i 1000

# 参数：
#   -p PERCENT : CPU 使用率百分比
#   -r RUNTIME : 运行时间（微秒）
#   -d DEADLINE: 截止时间（微秒）
#   -i PERIOD  : 周期（微秒）
```

### SCHED_DEADLINE 解释

SCHED_DEADLINE 是 Linux 的实时调度策略，基于 EDF (Earliest Deadline First) 算法。

**三个参数：**
- **Runtime**: 任务在一个周期内需要的 CPU 时间
- **Deadline**: 任务的截止时间
- **Period**: 任务的周期

**示例：**
```
Runtime  = 10ms   (每个周期需要 10ms CPU 时间)
Deadline = 20ms   (必须在 20ms 内完成)
Period   = 100ms  (每 100ms 执行一次)
```

## 其他 rt-tests 工具

### signaltest - 信号延迟

```bash
# 测试信号延迟
sudo signaltest -t 4 -p 99 -i 1000 -D 60s

# 类似 cyclictest，但测试信号处理延迟
```

### hackbench - 调度器性能

```bash
# 测试调度器吞吐量
hackbench -p -l 10000

# 参数：
#   -p        : 使用管道（而非socket）
#   -l LOOPS  : 循环次数
#   -g GROUPS : 进程组数
```

### hwlatdetect - 硬件延迟检测

```bash
# 检测硬件引起的延迟（SMI等）
sudo hwlatdetect --duration=60

# 检测由固件/BIOS引起的延迟
```

## 实时内核优化建议

### 1. 使用 PREEMPT_RT 内核

```bash
# 检查当前内核配置
uname -a | grep PREEMPT

# 安装 PREEMPT_RT 内核（Ubuntu）
sudo apt-get install linux-image-rt-amd64

# 重启并选择 RT 内核
```

### 2. 系统调优

```bash
# 禁用 CPU 频率调节
sudo cpupower frequency-set -g performance

# 禁用节能特性
sudo sh -c 'echo 0 > /sys/devices/system/cpu/cpu*/cpufreq/boost'

# 设置 CPU 隔离（隔离 CPU 2-3）
# 编辑 /etc/default/grub
# GRUB_CMDLINE_LINUX="isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3"
sudo update-grub
```

### 3. 进程优先级设置

```bash
# 使用 chrt 设置调度策略
sudo chrt -f 99 ./my_realtime_app

# 参数：
#   -f : SCHED_FIFO
#   -r : SCHED_RR
#   99 : 优先级（1-99）
```

### 4. 内存锁定

```c
// 在程序中锁定内存
#include <sys/mman.h>

int main() {
    // 锁定所有当前和未来的页面
    mlockall(MCL_CURRENT | MCL_FUTURE);

    // 预分配栈空间（防止页面错误）
    char stack[8192];
    memset(stack, 0, sizeof(stack));

    // 实时代码...

    munlockall();
    return 0;
}
```

## 测试场景示例

### 场景 1: 音频应用测试

```bash
# 音频应用通常需要 < 5ms 延迟
sudo cyclictest -m -a -p 99 -t 1 -i 500 -n -D 10m

# 期望: Max < 5000μs
```

### 场景 2: 工业控制系统

```bash
# 工控通常需要 < 100μs 延迟
sudo cyclictest -m -a -p 99 -t 4 -i 100 -n -D 60m

# 期望: Max < 100μs
```

### 场景 3: 机器人控制

```bash
# 机器人控制需要 < 1ms 延迟，高稳定性
sudo cyclictest -m -a -p 99 -t 8 -i 1000 -n \
    -S --histogram=1000 -D 120m

# 期望: Max < 1000μs, 99.9% < 500μs
```

## 结果分析工具

### 提取统计信息

```bash
# 从 cyclictest 输出提取最大延迟
grep "Max:" cyclictest.log | awk '{print $9}'

# 计算平均最大延迟
grep "Max:" cyclictest.log | awk '{sum+=$9; count++} END {print sum/count}'

# 找出最坏情况
grep "Max:" cyclictest.log | sort -k9 -n | tail -1
```

### 对比测试结果

```bash
#!/bin/bash
# compare_results.sh

echo "测试配置对比"
echo "================================"

for log in *.log; do
    echo "$log:"
    max=$(grep "Max:" "$log" | awk '{print $9}' | sort -n | tail -1)
    avg=$(grep "Avg:" "$log" | awk '{sum+=$7; count++} END {print sum/count}')
    echo "  最大延迟: ${max}μs"
    echo "  平均延迟: ${avg}μs"
    echo ""
done
```

## 常见问题排查

### 1. 延迟过高

**可能原因：**
- 未使用 PREEMPT_RT 内核
- CPU 频率调节启用
- 中断亲和性未设置
- SMI（System Management Interrupt）

**排查步骤：**
```bash
# 检查内核配置
zcat /proc/config.gz | grep PREEMPT

# 检查 CPU 频率
cpupower frequency-info

# 检查中断分布
cat /proc/interrupts

# 检测 SMI
sudo hwlatdetect --duration=60
```

### 2. 测试结果不稳定

```bash
# 关闭不必要的服务
sudo systemctl stop cron
sudo systemctl stop bluetooth

# 禁用 swap
sudo swapoff -a

# 重新测试
sudo cyclictest -m -a -p 99 -t 4 -i 1000 -n -D 60m
```

### 3. 权限问题

```bash
# 设置实时优先级限制
# 编辑 /etc/security/limits.conf
echo "@realtime soft rtprio 99" | sudo tee -a /etc/security/limits.conf
echo "@realtime hard rtprio 99" | sudo tee -a /etc/security/limits.conf

# 将用户添加到 realtime 组
sudo groupadd realtime
sudo usermod -a -G realtime $USER
```

## 参考资源

- **rt-tests 官方仓库**: https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
- **PREEMPT_RT Patch**: https://wiki.linuxfoundation.org/realtime/start
- **Real-Time Linux Wiki**: https://rt.wiki.kernel.org/
- **Cyclictest 文档**: https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest

---

**更新日期：** 2026-04-18
**文档版本：** 1.0
