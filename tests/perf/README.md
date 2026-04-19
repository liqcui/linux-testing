# Perf 性能分析工具集

## 概述

Perf是Linux内核提供的强大性能分析工具，能够分析CPU、内存、缓存、分支预测等多个维度的性能问题。本测试套件提供了完整的性能瓶颈定位、火焰图生成和自动化分析功能，帮助快速识别和解决性能问题。

## 目录结构

```
perf/
├── README.md                           # 本文件
├── scripts/
│   ├── test_perf_complete.sh           # 完整分析工作流（推荐使用）
│   ├── perf_bottleneck_analysis.sh     # 性能瓶颈分析
│   ├── flamegraph_generation.sh        # 火焰图生成
│   └── auto_flame_analysis.sh          # 自动化火焰图分析
└── results/                            # 测试结果目录（自动生成）
```

## 核心功能

### 1. 性能瓶颈分析（perf_bottleneck_analysis.sh）

**功能:**
- CPU热点函数识别
- 调用链分析
- 源码级性能注解
- 硬件性能计数器统计
- Cache miss和分支预测分析
- 自动问题检测和优化建议

**输出:**
- 热点函数报告（hotspots_report.txt）
- 调用链分析（callgraph_report.txt）
- 性能统计摘要（stat_summary.txt）
- 源码级注解（annotate_*.txt）
- 综合分析报告（summary_report.txt）

### 2. 火焰图生成（flamegraph_generation.sh）

**功能:**
- **on-CPU火焰图**: 显示CPU执行时间分布
- **off-CPU火焰图**: 显示阻塞等待时间分布
- **差分火焰图**: 对比两个场景的性能差异
- **内核火焰图**: 专注内核态性能
- **用户态火焰图**: 专注用户态性能

**特点:**
- 自动安装FlameGraph工具
- 交互式SVG可视化
- 支持点击放大、搜索功能
- 1600px宽度，高清显示

### 3. 自动化分析（auto_flame_analysis.sh）

**功能:**
- 自动提取Top热点函数
- 调用栈深度分析
- 内核vs用户空间占比
- 性能模式智能检测：
  - 锁竞争问题
  - 内存分配热点
  - 系统调用频繁
  - 内存拷贝过多
  - 字符串操作瓶颈
  - 数据解析性能
  - 哈希计算热点
- 针对性优化建议

### 4. 完整分析工作流（test_perf_complete.sh）

**一站式解决方案:**
```
阶段1: 性能瓶颈分析
  ↓
阶段2: 火焰图生成
  ↓
阶段3: 自动化分析
  ↓
综合报告生成
```

## 快速开始

### 前置条件

**安装perf:**
```bash
# Ubuntu/Debian
sudo apt-get install linux-tools-common linux-tools-$(uname -r)

# RHEL/CentOS
sudo yum install perf

# 验证安装
perf --version
```

**权限配置:**
```bash
# 临时允许用户使用perf（推荐用于开发环境）
sudo sysctl -w kernel.perf_event_paranoid=-1

# 永久配置
echo "kernel.perf_event_paranoid = -1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 使用方法

#### 方式1: 完整分析流程（推荐）

```bash
cd scripts

# 分析指定进程（PID）
./test_perf_complete.sh -p 1234 -d 60

# 分析指定进程（名称）
./test_perf_complete.sh -n nginx -d 60

# 系统范围分析
./test_perf_complete.sh -d 60

# 快速分析（跳过火焰图）
./test_perf_complete.sh -p 1234 -d 30 -s
```

**输出示例:**
```
complete_analysis_20260419_143022/
├── SUMMARY_REPORT.txt              # 综合报告（首先查看）
├── bottleneck_analysis/
│   ├── perf.data                   # 原始采样数据
│   ├── hotspots.txt                # 热点函数详情
│   ├── callgraph.txt               # 调用链分析
│   └── stat.txt                    # 性能统计
├── flamegraphs/
│   ├── oncpu_flamegraph.svg        # on-CPU火焰图
│   ├── kernel_flamegraph.svg       # 内核火焰图
│   ├── userspace_flamegraph.svg    # 用户态火焰图
│   └── flamegraph_analysis_report.txt
└── auto_analysis_report.txt        # 自动化分析报告
```

#### 方式2: 单独使用各工具

**性能瓶颈分析:**
```bash
# 分析指定PID
./perf_bottleneck_analysis.sh -p 1234 -d 60

# 分析指定进程名
./perf_bottleneck_analysis.sh -n redis-server -d 60

# 系统范围分析
./perf_bottleneck_analysis.sh -d 60

# 自定义采样频率
./perf_bottleneck_analysis.sh -p 1234 -d 60 -f 999
```

**火焰图生成:**
```bash
# 使用已有perf.data
./flamegraph_generation.sh -i /path/to/perf.data

# 新采样并生成
./flamegraph_generation.sh -p 1234 -d 60

# 指定输出目录
./flamegraph_generation.sh -p 1234 -d 60 -o /tmp/flames
```

**自动化分析:**
```bash
# 分析火焰图
./auto_flame_analysis.sh oncpu_flamegraph.svg

# 指定输出报告文件
./auto_flame_analysis.sh oncpu_flamegraph.svg my_report.txt
```

## 典型使用场景

### 场景1: Web服务CPU高问题

**症状:** Nginx/Tomcat CPU使用率持续90%+

**分析步骤:**
```bash
# 1. 获取进程PID
PID=$(pidof nginx | awk '{print $1}')

# 2. 完整分析（60秒采样）
./test_perf_complete.sh -p $PID -d 60

# 3. 查看综合报告
cat ../results/complete_analysis_*/SUMMARY_REPORT.txt

# 4. 打开火焰图
open ../results/complete_analysis_*/flamegraphs/oncpu_flamegraph.svg
```

**预期发现:**
- 热点函数：可能是URL路由、正则匹配、JSON解析等
- 火焰图：查找"平顶山"（宽且平的矩形）
- 优化方向：缓存、算法优化、异步处理

### 场景2: 数据库查询慢

**症状:** MySQL/PostgreSQL查询响应慢

**分析步骤:**
```bash
# 1. 分析数据库进程
./test_perf_complete.sh -n mysqld -d 120

# 2. 重点查看
#    - off-CPU火焰图（I/O等待）
#    - 系统调用热点
#    - 锁相关函数

# 3. 查看自动化分析报告
cat ../results/complete_analysis_*/auto_analysis_report.txt
```

**常见问题:**
- 系统调用频繁 → 批量操作
- 锁竞争 → 优化事务粒度
- I/O等待 → 索引优化、查询优化

### 场景3: 程序性能对比

**目的:** 对比优化前后的性能差异

**步骤:**
```bash
# 1. 采样优化前
sudo perf record -F 99 -a -g -o perf.data.before -- sleep 60

# 2. 应用优化

# 3. 采样优化后
sudo perf record -F 99 -a -g -o perf.data.after -- sleep 60

# 4. 生成差分火焰图
sudo perf script -i perf.data.before | \
    FlameGraph/stackcollapse-perf.pl > before.folded
sudo perf script -i perf.data.after | \
    FlameGraph/stackcollapse-perf.pl > after.folded
FlameGraph/difffolded.pl before.folded after.folded | \
    FlameGraph/flamegraph.pl > diff_flamegraph.svg

# 5. 查看差分火焰图
# 红色：优化后CPU消耗增加（可能是新增功能或回归）
# 蓝色：优化后CPU消耗减少（优化成功）
open diff_flamegraph.svg
```

### 场景4: 内核性能问题

**症状:** 系统调用多、内核态CPU高

**分析步骤:**
```bash
# 1. 系统范围采样
./test_perf_complete.sh -d 60

# 2. 重点查看内核火焰图
open ../results/complete_analysis_*/flamegraphs/kernel_flamegraph.svg

# 3. 查找热点内核函数
head -30 ../results/complete_analysis_*/bottleneck_analysis/hotspots.txt | grep "\[kernel\]"
```

**常见内核热点:**
- `sys_read/sys_write` → 频繁I/O，考虑异步或批量
- `__schedule` → 上下文切换多，减少线程或进程数
- `page_fault` → 内存访问模式问题，考虑预取或huge pages
- `do_futex` → 锁竞争，优化同步机制

### 场景5: 缓存效率分析

**目的:** 分析CPU缓存命中率

**步骤:**
```bash
# 1. 性能瓶颈分析
./perf_bottleneck_analysis.sh -p 1234 -d 60

# 2. 查看性能统计
cat ../results/bottleneck_analysis_*/stat_summary.txt

# 3. 分析关键指标
grep -E "cache-misses|cache-references" ../results/bottleneck_analysis_*/stat_summary.txt
```

**指标解读:**
```
Cache Miss率 = cache-misses / cache-references × 100%

< 1%:    ★★★★★ 优秀
1-3%:    ★★★★☆ 良好
3-10%:   ★★★☆☆ 一般
10-20%:  ★★☆☆☆ 较差 - 需要优化数据结构或访问模式
> 20%:   ★☆☆☆☆ 很差 - 严重的缓存效率问题
```

## 火焰图解读指南

### 基本概念

```
 火焰图结构:

 Y轴（高度）           X轴（宽度）
    ↑                     ←→
    │
    │  [函数C]          宽度 = CPU时间占比
    │  [函数B]          （越宽越重要）
    │  [函数A]
    │  [main]
    └─────────────────→
      调用栈深度
```

### 关键模式

**1. 平顶山（Plateau）**
```
     ┌──────────────────┐
     │                  │  ← 宽且平
     │    Hot Function  │  ← 该函数直接消耗大量CPU
     │                  │  ← ★★★★★ 最值得优化
     └──────────────────┘
```

**含义:** 函数本身消耗大量CPU（非子函数）
**优先级:** 最高
**示例:** 加密算法、数据压缩、复杂计算

**2. 塔尖（Tower）**
```
         │
         │
         │  ← 窄且高
       ┌─┴─┐
       │   │  ← 深度调用
       └─┬─┘
         │
         │
```

**含义:** 调用链很长或深度递归
**优先级:** 中等
**问题:** 过度抽象、递归深度大、框架开销

**3. 火山（Volcano）**
```
     ┌───┐
    ┌┴───┴┐  ← 底部宽
   ┌┴─────┴┐ ← 顶部窄
  ┌┴───────┴┐
  └─────────┘
```

**含义:** 函数调用了多个子函数，子函数消耗CPU
**优先级:** 分析子函数
**示例:** 框架入口函数、循环调用多个函数

### 颜色含义

- **随机颜色:** 仅用于区分函数，无性能含义
- **红色/橙色:** 通常表示CPU密集（某些工具）
- **蓝色/绿色:** 可能表示I/O或内核（某些工具）
- **差分火焰图:**
  - 红色 → 问题场景CPU消耗更多
  - 蓝色 → 正常场景CPU消耗更多

### 交互操作

1. **点击函数框:** 放大该函数及其子调用
2. **Ctrl+F:** 搜索函数名
3. **Reset Zoom:** 恢复初始视图
4. **鼠标悬停:** 显示详细信息

## 性能问题速查表

### 症状 vs 工具使用

| 症状 | 使用工具 | 关注指标 |
|------|---------|---------|
| CPU使用率高 | on-CPU火焰图 | 平顶山函数 |
| 响应慢但CPU低 | off-CPU火焰图 | I/O、锁等待 |
| 内核态CPU高 | 内核火焰图 | 系统调用热点 |
| 缓存效率低 | perf stat | cache-miss率 |
| 分支预测失败 | perf stat | branch-miss率 |
| 上下文切换多 | perf stat | context-switches |

### 常见热点 vs 优化方向

| 热点类型 | 函数特征 | 优化方向 |
|---------|---------|---------|
| 锁竞争 | mutex/spinlock/rwlock | 减小锁粒度、无锁结构 |
| 内存分配 | malloc/free/new/delete | 内存池、对象复用 |
| 内存拷贝 | memcpy/memmove | 减少拷贝、引用传递 |
| 系统调用 | sys_*/syscall | 批量操作、异步I/O |
| 字符串操作 | strcmp/strcpy/strlen | 缓存、更高效的库 |
| JSON解析 | json/parse | 更快的解析器、二进制格式 |
| 哈希计算 | hash/__hash | 更快的哈希算法 |

## 高级技巧

### 1. 采样频率选择

```bash
# 低频率（减少开销，适合长时间采样）
perf record -F 49 ...

# 标准频率（默认，推荐）
perf record -F 99 ...

# 高频率（更高精度，适合短时间采样）
perf record -F 999 ...

# 自适应（根据系统负载自动调整）
perf record -F max ...
```

**建议:**
- 开发环境: 99-999 Hz
- 生产环境: 49-99 Hz（减少性能影响）
- 长时间采样: 49 Hz
- 精确分析: 999 Hz

### 2. 特定事件采样

```bash
# Cache miss采样
sudo perf record -e cache-misses -c 10000 -p PID -- sleep 30

# 分支预测失败采样
sudo perf record -e branch-misses -c 10000 -p PID -- sleep 30

# 页缺失采样
sudo perf record -e page-faults -p PID -- sleep 30

# TLB miss采样
sudo perf record -e dTLB-load-misses -p PID -- sleep 30
```

### 3. 调用图优化

```bash
# 使用DWARF（最完整，但数据量大）
perf record -g --call-graph dwarf ...

# 使用frame pointer（轻量，需编译时-fno-omit-frame-pointer）
perf record -g --call-graph fp ...

# 使用LBR（Intel CPU，硬件支持）
perf record -g --call-graph lbr ...
```

### 4. 过滤和聚合

```bash
# 只采样特定CPU
sudo perf record -C 0,1 -a ...

# 只采样用户态
sudo perf record --exclude-kernel ...

# 只采样内核态
sudo perf record --exclude-user ...

# 限制数据大小
sudo perf record --mmap-pages=128 ...
```

## 故障诊断

### 问题1: perf record失败

**症状:**
```
perf_event_open(..., PERF_FLAG_FD_CLOEXEC) failed with unexpected error 1 (Operation not permitted)
```

**解决:**
```bash
# 方案1: 临时调整权限
sudo sysctl -w kernel.perf_event_paranoid=-1

# 方案2: 使用sudo
sudo perf record ...

# 方案3: 设置capabilities
sudo setcap cap_perfmon,cap_sys_ptrace,cap_syslog=ep $(which perf)
```

### 问题2: 符号缺失

**症状:** 火焰图中显示地址而非函数名（如[unknown]、0x7f8b3c）

**解决:**
```bash
# 1. 安装调试符号
# Ubuntu/Debian
sudo apt-get install linux-image-$(uname -r)-dbg

# RHEL/CentOS
sudo debuginfo-install kernel

# 2. 编译时带调试信息
gcc -g -O2 -fno-omit-frame-pointer ...

# 3. 设置符号路径
export PERF_BUILDID_DIR=/usr/lib/debug
```

### 问题3: 数据文件过大

**症状:** perf.data文件几GB，处理慢

**解决:**
```bash
# 1. 减少采样频率
perf record -F 49 ...  # 而不是99或999

# 2. 减少采样时长
perf record -t 30 ...  # 30秒而不是60秒

# 3. 只采样特定PID
perf record -p PID ...  # 而不是 -a

# 4. 压缩数据文件
perf record --compression-level=5 ...

# 5. 限制栈深度
perf record --call-graph dwarf,8192 ...  # 限制8KB
```

### 问题4: FlameGraph安装失败

**解决:**
```bash
# 手动克隆
cd tests/perf/scripts
git clone https://github.com/brendangregg/FlameGraph.git

# 或下载ZIP
wget https://github.com/brendangregg/FlameGraph/archive/refs/heads/master.zip
unzip master.zip
mv FlameGraph-master FlameGraph
```

## 参考资料

- [Perf Wiki](https://perf.wiki.kernel.org/)
- [Brendan Gregg's Perf Examples](http://www.brendangregg.com/perf.html)
- [FlameGraph GitHub](https://github.com/brendangregg/FlameGraph)
- [Linux Performance](http://www.brendangregg.com/linuxperf.html)

---

**更新日期:** 2026-04-19
**版本:** 1.0
