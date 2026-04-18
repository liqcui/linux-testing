# 进程调度测试结果解析

## 概述

本文档详细解释进程调度测试的输出结果，帮助你理解调度延迟、CPU利用率和系统响应性能。

---

## 测试文件位置

```
results/sched/
├── sched_idle_latency_TIMESTAMP.txt      # 空闲系统调度延迟
├── sched_stress_latency_TIMESTAMP.txt    # 高负载调度延迟
├── sched_timehist_TIMESTAMP.txt          # 调度时间线
├── sched_map_TIMESTAMP.txt               # CPU调度映射
└── report_TIMESTAMP.txt                  # 测试报告
```

---

## 1. 调度延迟报告解析 (perf sched latency)

### 示例输出

```
 -------------------------------------------------------------------------------------------------------------------------------------------
  Task                  |   Runtime ms  | Switches | Avg delay ms    | Max delay ms    | Max delay start           | Max delay end          |
 -------------------------------------------------------------------------------------------------------------------------------------------
  stress-ng:(3)         |  29779.278 ms |      232 | avg:   0.047 ms | max:   0.891 ms | max start: 3458578.524363 s | max end: 3458578.525253 s
  systemd:1             |      3.935 ms |       15 | avg:   0.054 ms | max:   0.133 ms | max start: 3458578.540394 s | max end: 3458578.540527 s
  kworker/2:1:2955716   |      0.006 ms |        1 | avg:   0.002 ms | max:   0.002 ms | max start: 3458578.551251 s | max end: 3458578.551253 s
 -----------------------------------------------------------------------------------------------------------------
  TOTAL:                |  29808.911 ms |      282 |
```

### 字段详解

#### Task - 任务标识

**格式**: `进程名:PID` 或 `进程名:(数量)`

```
stress-ng:(3)     ← 3个stress-ng进程
systemd:1         ← PID为1的systemd进程
kworker/2:1:2955716  ← CPU 2上的第1个worker线程
```

**进程名解析**:
| 进程名 | 含义 | 类型 |
|--------|------|------|
| stress-ng | CPU压力测试进程 | 用户进程 |
| systemd | 系统初始化进程 | 系统服务 |
| kworker | 内核工作线程 | 内核线程 |
| rcu_preempt | RCU可抢占线程 | 内核线程 |
| migration/N | CPU N的迁移线程 | 内核线程 |
| ksoftirqd/N | CPU N的软中断线程 | 内核线程 |

#### Runtime ms - 运行时间

**含义**: 进程在CPU上实际执行的时间

```
stress-ng: 29779.278 ms ← 3个进程共运行29.78秒
           (10秒测试 × 3个进程 ≈ 30秒)
```

**分析**:
- **29779 ms / 10秒 = 2.98** → 平均同时运行3个进程（符合预期）
- 如果是 **10秒测试，4核CPU，4个进程 → 预期40秒**

**CPU利用率计算**:
```
CPU利用率 = Runtime / (测试时长 × CPU核心数)
         = 29779ms / (10000ms × 4核)
         = 74.4%  ← 3个进程充分利用了3个核心
```

#### Switches - 上下文切换次数

**含义**: 进程被调度的次数

```
stress-ng: 232次  ← 10秒内232次切换
平均切换频率 = 232 / 10 = 23.2次/秒
```

**切换频率分析**:
| 频率 | 评价 | 说明 |
|------|------|------|
| < 10次/秒 | 优秀 | 进程长时间连续运行 |
| 10-100次/秒 | 正常 | 典型的CPU密集型任务 |
| 100-1000次/秒 | 偏高 | 可能有频繁I/O或竞争 |
| > 1000次/秒 | 异常 | 可能有性能问题 |

**高切换次数的原因**:
1. 进程数 > CPU核心数（需要时间片轮转）
2. 高优先级进程抢占
3. 频繁的I/O操作
4. 锁竞争

#### Avg delay ms - 平均调度延迟

**含义**: 进程从可运行到实际运行的平均等待时间

```
stress-ng: 0.047 ms = 47微秒
```

**性能标准**:
| 延迟 | 评价 | 适用场景 |
|------|------|---------|
| < 0.1ms | 优秀 | 所有场景 |
| 0.1-1ms | 良好 | 桌面/服务器 |
| 1-10ms | 可接受 | 非实时应用 |
| > 10ms | 需优化 | 用户可感知卡顿 |

**计算示例**:
```
总等待时间 = Avg delay × Switches
          = 0.047ms × 232次
          = 10.9ms

占测试时长 = 10.9ms / 10000ms = 0.11%  ← 等待时间很少
```

#### Max delay ms - 最大调度延迟

**含义**: 单次等待的最长时间

```
stress-ng: 0.891 ms = 891微秒
```

**分析**:
- **< 1ms**: 优秀，不会造成用户可感知的延迟
- **1-10ms**: 可接受，偶尔卡顿
- **> 10ms**: 需要调查原因

**最大延迟的原因**:
1. 所有CPU都在忙（饱和）
2. 高优先级进程抢占
3. 中断处理占用CPU
4. 内核锁竞争

#### Max delay start/end - 最大延迟时刻

**含义**: 发生最大延迟的时间点（绝对时间戳）

```
start: 3458578.524363 s
end:   3458578.525253 s
duration: 0.890 ms
```

**用途**:
- 结合系统日志分析当时发生了什么
- 检查是否有其他进程干扰
- 定位性能抖动的时间点

```bash
# 查看该时间点的系统日志
journalctl --since "2026-04-18 10:30:24.524" --until "2026-04-18 10:30:24.525"
```

### TOTAL - 汇总统计

```
TOTAL: 29808.911 ms | 282
       ↑             ↑
       总运行时间    总切换次数
```

**分析**:
```
平均每次运行时长 = 总运行时间 / 总切换次数
                = 29808.911ms / 282
                = 105.7ms  ← 每次调度平均运行105ms
```

**时间片分析**:
- Linux默认时间片: 100-200ms
- 105.7ms 在正常范围内
- 说明进程能够较长时间连续运行

---

## 2. 调度时间线解析 (perf sched timehist)

### 示例输出

```
           time    cpu  task name                       wait time  sch delay   run time
                        [tid/pid]                          (msec)     (msec)     (msec)
--------------- ------  ------------------------------  ---------  ---------  ---------
 3458569.254401 [0000]  stress-ng[2955708]                  0.000      0.000      1.122
 3458569.254405 [0000]  rcu_preempt[16]                     0.000      0.012      0.003
 3458569.258383 [0000]  stress-ng[2955708]                  0.003      0.000      3.977
 3458569.258386 [0000]  rcu_preempt[16]                     3.977      0.003      0.003
```

### 字段详解

#### time - 绝对时间戳

```
3458569.254401 ← 系统启动后的秒数（含微秒）
```

**转换为可读时间**:
```bash
# 查看系统启动时间
uptime -s

# 计算实际时间
启动时间 + 时间戳 = 实际时间
```

#### cpu - CPU核心编号

```
[0000] ← CPU 0
[0001] ← CPU 1
[0002] ← CPU 2
[0003] ← CPU 3
```

**CPU利用分析**:
```
同一时刻不同CPU的任务:
时间         CPU 0            CPU 1           CPU 2           CPU 3
254401    stress-ng[1]    stress-ng[2]    stress-ng[3]    <idle>
```

#### task name [tid/pid] - 任务信息

```
stress-ng[2955708]
    ↑        ↑
  进程名    TID/PID
```

**特殊任务**:
| 任务名 | 含义 |
|--------|------|
| `<idle>` | CPU空闲 |
| `swapper` | CPU空闲进程 |

#### wait time - 等待时间

**含义**: 进程在**运行队列**中等待的时间

```
rcu_preempt: wait time = 3.977 ms
```

**说明**:
- 进程可运行，但CPU在执行其他任务
- wait time = 上次结束运行 → 本次开始运行

**示例分析**:
```
254401  stress-ng 运行 1.122ms
254405  rcu_preempt 抢占，stress-ng 进入等待
258383  stress-ng 重新运行
        wait time = 258383 - 254405 = 3.978ms
```

#### sch delay - 调度延迟

**含义**: 从**唤醒**到**实际运行**的延迟

```
rcu_preempt: sch delay = 0.012 ms
```

**与 wait time 的区别**:
```
wait time:  在队列中等待的总时间（可能未被唤醒）
sch delay:  被唤醒后到运行的延迟（调度器响应时间）
```

**调度延迟分析**:
| 延迟 | 评价 | 说明 |
|------|------|------|
| < 0.01ms | 优秀 | 调度器响应迅速 |
| 0.01-0.1ms | 良好 | 正常范围 |
| 0.1-1ms | 可接受 | 轻微延迟 |
| > 1ms | 需调查 | 调度器负载过高 |

#### run time - 运行时间

**含义**: 进程在CPU上实际执行的时间

```
stress-ng: 1.122 ms
rcu_preempt: 0.003 ms  ← RCU只运行3微秒
```

**分析**:
```
stress-ng 运行 1.122ms
被 rcu_preempt 抢占，运行 0.003ms
stress-ng 恢复，继续运行 3.977ms

stress-ng 被抢占影响很小: 0.003ms / (1.122 + 3.977) = 0.06%
```

---

## 3. CPU调度映射解析 (perf sched map)

### 示例输出

```
  *A0               3458569.253265 secs A0 => migration/0:17
  *B0               3458569.253279 secs B0 => stress-ng:2955708
   B0 *C0           3458569.253333 secs C0 => migration/1:21
   B0 *.            3458569.253348 secs .  => swapper:0
   B0  .  *D0       3458569.253404 secs D0 => migration/2:26
   B0  .  *E0       3458569.253417 secs E0 => stress-ng:2955710
   B0 *F0  E0       3458569.253505 secs F0 => perf-exec:2955712
   B0  F0  E0 *G0   3458569.253548 secs G0 => stress-ng:2955709
```

### 图例说明

#### 符号含义

```
*A0   ← 任务切换（* 表示切换点）
 │
 └── A0 是任务标识
```

**位置表示CPU**:
```
列1  列2  列3  列4
↓    ↓    ↓    ↓
B0   F0   E0   G0   ← 表示4个CPU上同时运行的任务
│    │    │    │
CPU0 CPU1 CPU2 CPU3
```

**特殊符号**:
- `*`: 任务切换点
- `.`: CPU空闲 (swapper)
- `任务ID`: 当前运行的任务

#### 任务映射表

```
A0 => migration/0:17      # A0 代表 migration/0 进程（PID 17）
B0 => stress-ng:2955708   # B0 代表 stress-ng 进程
.  => swapper:0           # . 代表 CPU 空闲
```

### 时间线分析

#### 1. 系统启动阶段

```
253265  *A0               ← CPU 0: migration/0 启动
253279   B0               ← CPU 0: stress-ng-1 开始
        *B0 *C0           ← CPU 1: migration/1 启动
        B0  *.            ← CPU 1: 进入空闲
```

**解读**:
- 内核先启动migration线程（负责负载均衡）
- 然后stress-ng进程开始运行
- CPU 1 启动migration后进入空闲

#### 2. 任务分布阶段

```
253548  B0  F0  E0  G0    ← 4个CPU都在运行任务
        │   │   │   │
      CPU0 CPU1 CPU2 CPU3
        │   │   │   └─ stress-ng-3
        │   │   └───── stress-ng-2
        │   └───────── perf
        └───────────── stress-ng-1
```

**分析**:
- 3个stress-ng进程分布在CPU 0、2、3
- CPU 1 运行 perf 进程（采集工具自身）
- 负载分布较均衡

#### 3. RCU抢占场景

```
258383  *H0  .   E0  G0   ← CPU 0: RCU 抢占
258386  *B0  .   E0  G0   ← CPU 0: stress-ng 恢复
```

**解读**:
- RCU (H0) 抢占 CPU 0
- 运行极短时间（3微秒）
- stress-ng 立即恢复运行

---

## 4. 空闲vs高负载对比分析

### 空闲系统

```
Task             Runtime    Switches   Avg delay   Max delay
htop:2954692     30.548 ms      1      0.000 ms    0.000 ms
systemd-oomd     6.072 ms       1      0.000 ms    0.000 ms
sleep:2955360    1.217 ms       1      0.000 ms    0.000 ms

TOTAL:           41.507 ms      23
```

**特点**:
- ✅ 调度延迟 = 0（CPU充足）
- ✅ 切换次数少（任务少）
- ✅ 总运行时间少（CPU空闲率高）
- ✅ CPU利用率 = 41.507 / 10000 = 0.4%

### 高负载系统

```
Task             Runtime       Switches   Avg delay   Max delay
stress-ng:(3)    29779.278 ms   232       0.047 ms    0.891 ms
systemd:1        3.935 ms       15        0.054 ms    0.133 ms

TOTAL:           29808.911 ms   282
```

**特点**:
- ⚠️ 出现调度延迟（CPU竞争）
- ⚠️ 切换次数增加（任务轮转）
- ✅ 总运行时间高（CPU充分利用）
- ✅ CPU利用率 = 29808.911 / 40000 = 74.5%

### 性能对比表

| 指标 | 空闲系统 | 高负载系统 | 变化 |
|------|---------|----------|------|
| 总运行时间 | 41.5ms | 29808.9ms | **↑ 717倍** |
| 上下文切换 | 23次 | 282次 | **↑ 12倍** |
| 平均延迟 | 0ms | 0.047ms | **↑ 可测量** |
| 最大延迟 | 0ms | 0.891ms | **↑ 可测量** |
| CPU利用率 | 0.4% | 74.5% | **↑ 186倍** |

---

## 5. 性能基准和标准

### 调度延迟标准

| 系统类型 | 平均延迟目标 | 最大延迟目标 | 说明 |
|---------|------------|------------|------|
| 桌面系统 | < 5ms | < 20ms | 用户交互流畅 |
| 服务器 | < 10ms | < 50ms | 请求响应及时 |
| 低延迟 | < 1ms | < 10ms | 金融交易、游戏 |
| 实时系统 | < 100μs | < 1ms | 工业控制 |
| 硬实时 | < 10μs | < 100μs | 航空航天 |

### 上下文切换频率标准

| 频率 | 评价 | 适用场景 |
|------|------|---------|
| < 100次/秒 | 优秀 | CPU密集型 |
| 100-1000次/秒 | 正常 | 混合负载 |
| 1000-10000次/秒 | 偏高 | I/O密集型 |
| > 10000次/秒 | 异常 | 可能有问题 |

### CPU利用率标准

| 利用率 | 评价 | 说明 |
|--------|------|------|
| < 30% | 空闲 | 资源未充分利用 |
| 30-70% | 正常 | 健康的负载 |
| 70-90% | 繁忙 | 需要关注 |
| > 90% | 饱和 | 可能影响性能 |
| 100% | 满载 | 有延迟风险 |

---

## 6. 常见问题诊断

### 问题1: 调度延迟过高

**症状**:
```
Task              Avg delay    Max delay
my-app:12345      15.234 ms    125.678 ms  ← 延迟很高
```

**可能原因**:
1. CPU核心数不足
2. 进程优先级低
3. CPU被其他任务占用
4. 内核锁竞争

**诊断步骤**:
```bash
# 1. 查看CPU使用率
mpstat -P ALL 1

# 2. 查看进程优先级
ps -eo pid,ni,pri,comm | grep my-app

# 3. 查看运行队列
vmstat 1

# 4. 分析等待时间
perf sched timehist
```

**优化方法**:
```bash
# 1. 提高进程优先级
nice -n -10 ./my-app

# 2. 使用实时调度
chrt -f 99 ./my-app

# 3. CPU绑定
taskset -c 0,1 ./my-app

# 4. CPU隔离（内核参数）
# isolcpus=2,3 rcu_nocbs=2,3
```

### 问题2: 上下文切换过多

**症状**:
```
Task              Switches    Runtime
my-app:12345      15000       100 ms    ← 切换频率 150次/ms
```

**可能原因**:
1. 进程数远大于CPU核心数
2. 频繁的I/O操作
3. 锁竞争
4. 时间片过小

**诊断**:
```bash
# 查看切换详情
perf sched script | grep my-app

# 查看系统级切换率
vmstat 1
# cs列: context switches per second
```

**优化**:
```bash
# 1. 减少进程数
# 2. 批量处理I/O
# 3. 优化锁粒度
# 4. 使用异步I/O
```

### 问题3: CPU利用率不均

**症状**:
```
CPU 0: 100%
CPU 1: 100%
CPU 2: 5%
CPU 3: 3%
```

**原因**:
- 进程没有正确分布
- CPU亲和性设置不当
- 调度器负载不均

**诊断**:
```bash
# 查看各CPU负载
mpstat -P ALL 1

# 查看进程CPU亲和性
taskset -cp <PID>

# 查看调度映射
perf sched map
```

**优化**:
```bash
# 1. 移除CPU亲和性限制
taskset -cp 0-3 <PID>

# 2. 启用自动负载均衡
# (默认开启，检查是否被禁用)

# 3. 使用 numactl 优化
numactl --interleave=all ./my-app
```

---

## 7. 进阶分析技巧

### 分析特定进程

```bash
# 只分析stress-ng进程
perf sched script | grep stress-ng

# 统计stress-ng的调度事件
perf sched script | grep stress-ng | \
  awk '{print $5}' | sort | uniq -c
```

### 分析CPU热点

```bash
# 哪个CPU最忙
perf sched map | awk '{print $1}' | sort | uniq -c | sort -rn

# 各CPU的切换次数
perf sched script | awk '{print $3}' | sort | uniq -c
```

### 时间切片分析

```bash
# 计算平均时间片
perf sched timehist | awk 'NR>3 {sum+=$NF; count++} END {print sum/count}'

# 找出运行时间最长的任务
perf sched timehist | sort -k7 -rn | head -10
```

### 生成调度延迟直方图

```bash
# 提取调度延迟
perf sched script | awk '{print $8}' | grep -v "msec" | \
  awk '{print int($1)}' | sort -n | uniq -c

# 生成分布图
# 延迟(ms)  次数
# 0         150
# 1         45
# 2         12
# 3         3
```

---

## 8. 报告示例解读

### 完整报告

```
进程调度性能测试报告
====================
测试时间: 2026-04-18 10:30:00
主机名: test-server
CPU 核心数: 4
测试时长: 10s

## 空闲系统调度延迟

Task                Runtime    Switches   Avg delay   Max delay
htop:2954692        30.548ms   1          0.000ms     0.000ms
TOTAL:              41.507ms   23

## 高负载调度延迟

Task                Runtime      Switches   Avg delay   Max delay
stress-ng:(3)       29779.278ms  232        0.047ms     0.891ms
TOTAL:              29808.911ms  282

## 性能总结

最大调度延迟: 0.891ms (优秀)
平均切换频率: 28.2次/秒 (正常)
CPU利用率: 74.5% (良好)
```

### 解读

**调度性能**: ✅ 优秀
- 平均延迟 47μs < 100μs
- 最大延迟 0.891ms < 1ms
- 无异常卡顿

**系统负载**: ✅ 健康
- CPU利用率 74.5%（3核满载）
- 切换频率正常
- 负载分布均衡

**建议**: 系统调度性能优秀，无需优化

---

## 9. 优化建议

### 降低延迟的方法

1. **使用实时调度策略**
   ```bash
   chrt -f 99 ./my-app  # SCHED_FIFO
   chrt -r 99 ./my-app  # SCHED_RR
   ```

2. **CPU隔离**
   ```bash
   # 内核参数 (GRUB配置)
   isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3

   # 将关键任务绑定到隔离CPU
   taskset -c 2,3 ./my-app
   ```

3. **禁用节能**
   ```bash
   # 设置性能模式
   cpupower frequency-set -g performance

   # 禁用C-states
   cpupower idle-set -D 0
   ```

### 降低切换开销的方法

1. **增加时间片**
   ```bash
   # 调整调度参数
   sysctl -w kernel.sched_min_granularity_ns=10000000  # 10ms
   sysctl -w kernel.sched_wakeup_granularity_ns=15000000  # 15ms
   ```

2. **减少竞争**
   ```bash
   # 减少进程数到CPU核心数
   # 或使用进程池/线程池
   ```

3. **使用大页内存**
   ```bash
   # 减少TLB miss
   echo 128 > /proc/sys/vm/nr_hugepages
   ```

---

## 总结

进程调度测试结果解读的关键点：

1. **延迟分析** - 平均和最大延迟是否在目标范围
2. **切换频率** - 过高说明竞争激烈
3. **CPU分布** - 负载是否均衡
4. **时间片** - 是否能连续运行
5. **优先级** - 关键任务是否被及时调度

通过系统的测试和分析，可以：
- ✅ 识别调度瓶颈
- ✅ 优化系统响应性
- ✅ 提升用户体验
- ✅ 满足实时要求

---

**相关文档**:
- [网络测试结果解析](NETWORK_RESULTS.md)
- [详细测试指南](../DETAILED_GUIDE.md)
- [快速参考](../QUICK_REFERENCE.md)
