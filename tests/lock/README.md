# 锁性能和竞争测试

## 概述

`lock_test` 是一个用于测试和分析多线程锁竞争的工具。它可以帮助你：
- 了解不同锁策略的性能差异
- 分析锁竞争和等待时间
- 检测潜在的死锁场景
- 对比互斥锁和读写锁的性能

---

## 快速开始

### 编译

```bash
cd tests/lock
make
```

### 运行

```bash
# 基本运行
./lock_test

# 使用 perf lock 分析
make perf-record   # 记录锁事件
make perf-report   # 分析报告

# 或者一步完成
make perf
```

---

## 测试内容

### 1. 单个锁竞争

**特点**:
- 多个线程竞争同一个互斥锁
- 高锁竞争场景
- 大量等待时间

**典型性能**: 受线程数影响，线程越多竞争越激烈

**示例**:
```bash
./lock_test -t 1 -p 8 -n 10000
```

### 2. 多个独立锁

**特点**:
- 每个线程使用不同的锁
- 低锁竞争
- 更好的并发性能

**典型性能**: 接近线性扩展

**示例**:
```bash
./lock_test -t 2 -p 8
```

### 3. 锁链（多锁顺序获取）

**特点**:
- 线程需要同时持有多个锁
- 按固定顺序获取，避免死锁
- 较高的锁等待时间

**典型性能**: 比单锁更慢

**示例**:
```bash
./lock_test -t 3 -p 4
```

### 4. 读写锁

**特点**:
- 读操作可以并发
- 写操作互斥
- 适合读多写少的场景

**典型性能**: 读操作吞吐量高

**示例**:
```bash
./lock_test -t 4 -p 8
```

---

## 命令行选项

```bash
./lock_test [选项]

选项:
  -t <type>    测试类型 (1-5, 默认: 5)
               1 = 单个锁竞争
               2 = 多个独立锁
               3 = 锁链（多锁顺序获取）
               4 = 读写锁
               5 = 全部测试
  -p <num>     线程数 (默认: 4, 最大: 8)
  -n <num>     迭代次数 (默认: 100000)
  -h           显示帮助信息
```

---

## 使用 perf lock 分析

### 基本分析流程

```bash
# 1. 记录锁事件
perf lock record ./lock_test

# 2. 查看报告
perf lock report

# 3. 查看详细信息
perf lock report -v
```

### perf lock report 输出解析

**示例输出**:
```
                Name   acquired  contended   avg wait (ns)   total wait (ns)   max wait (ns)   min wait (ns)
   &counters[0].lock      40000      35000          125000        4375000000         1250000            5000
   &counters[1].lock      40000       5000           25000         125000000          150000            2000
```

**字段说明**:
- **Name**: 锁的地址或名称
- **acquired**: 锁被获取的总次数
- **contended**: 发生竞争的次数（尝试获取但锁已被占用）
- **avg wait**: 平均等待时间（纳秒）
- **total wait**: 总等待时间（纳秒）
- **max wait**: 最大等待时间（纳秒）
- **min wait**: 最小等待时间（纳秒）

**关键指标**:
- **竞争率** = contended / acquired
  - < 10%: 低竞争
  - 10-30%: 中等竞争
  - > 30%: 高竞争
- **平均等待时间**: 越小越好
  - < 100 µs: 优秀
  - 100-1000 µs: 良好
  - > 1000 µs: 需要优化

### 实时锁竞争分析（较新的 perf 版本）

```bash
# 实时显示锁竞争
perf lock contention ./lock_test

# 带堆栈信息
perf lock contention -v ./lock_test
```

---

## 性能基准

### 不同锁策略对比

| 策略 | 线程数 | 吞吐量 | 竞争率 | 适用场景 |
|------|--------|--------|--------|----------|
| 单个锁 | 4 | 10K ops/s | 70% | 简单场景 |
| 多个锁 | 4 | 35K ops/s | 10% | 可分片场景 |
| 读写锁 | 4 | 30K ops/s | 5% | 读多写少 |

*注: 实际性能取决于硬件和负载*

---

## 锁优化建议

### 1. 减少锁粒度

**差**: 大锁
```c
pthread_mutex_lock(&big_lock);
update_data_1();
update_data_2();
pthread_mutex_unlock(&big_lock);
```

**好**: 细粒度锁
```c
pthread_mutex_lock(&lock1);
update_data_1();
pthread_mutex_unlock(&lock1);

pthread_mutex_lock(&lock2);
update_data_2();
pthread_mutex_unlock(&lock2);
```

### 2. 减少持锁时间

**差**: 在锁内做耗时操作
```c
pthread_mutex_lock(&lock);
read_from_disk();  // 耗时！
process_data();
pthread_mutex_unlock(&lock);
```

**好**: 锁外做耗时操作
```c
data = read_from_disk();  // 锁外

pthread_mutex_lock(&lock);
process_data();
pthread_mutex_unlock(&lock);
```

### 3. 使用读写锁

**适用场景**: 读多写少
```c
// 读操作（可并发）
pthread_rwlock_rdlock(&rwlock);
value = read_data();
pthread_rwlock_unlock(&rwlock);

// 写操作（互斥）
pthread_rwlock_wrlock(&rwlock);
write_data(new_value);
pthread_rwlock_unlock(&rwlock);
```

### 4. 避免锁顺序不一致

**死锁示例**:
```c
// 线程1
lock(A); lock(B);  // A -> B

// 线程2
lock(B); lock(A);  // B -> A  死锁！
```

**解决方案**: 固定锁顺序
```c
// 所有线程都按 A -> B 顺序
lock(A); lock(B);
```

---

## 高级用法

### 检测死锁

```bash
# 使用 lockdep (内核需要 CONFIG_LOCKDEP)
echo 1 > /proc/sys/kernel/lock_stat

# 运行测试
./lock_test

# 查看统计
cat /proc/lock_stat
```

### 锁统计

```bash
# 启用锁统计
echo 1 > /proc/sys/kernel/lock_stat

# 运行测试
perf lock record -a ./lock_test

# 查看热点锁
perf lock report --sort=wait_total
```

---

## 实际应用场景

### 1. 数据库连接池

```c
// 多个独立锁策略
pthread_mutex_t pool_locks[N_POOLS];

int get_connection(int pool_id) {
    pthread_mutex_lock(&pool_locks[pool_id]);
    conn = get_from_pool(pool_id);
    pthread_mutex_unlock(&pool_locks[pool_id]);
    return conn;
}
```

### 2. 缓存系统

```c
// 读写锁策略
pthread_rwlock_t cache_lock;

void *cache_get(key) {
    pthread_rwlock_rdlock(&cache_lock);
    value = lookup(key);
    pthread_rwlock_unlock(&cache_lock);
    return value;
}

void cache_put(key, value) {
    pthread_rwlock_wrlock(&cache_lock);
    insert(key, value);
    pthread_rwlock_unlock(&cache_lock);
}
```

### 3. 日志系统

```c
// 无锁环形缓冲区 + 后台线程
ring_buffer_t *log_buffer;

void log_message(msg) {
    // 无锁写入环形缓冲区
    ring_buffer_push(log_buffer, msg);
}

void *logger_thread(void *arg) {
    // 后台线程批量刷盘
    while (1) {
        pthread_mutex_lock(&flush_lock);
        flush_to_disk(log_buffer);
        pthread_mutex_unlock(&flush_lock);
    }
}
```

---

## 常见问题

### Q: perf lock report 只显示一条记录或数字地址怎么办？

**A**: 这是最常见的问题，有几个原因和解决方案：

#### 原因1: 内核缺少 CONFIG_LOCK_STAT 支持

```bash
# 检查内核是否支持 lock 跟踪
perf list | grep lock:

# 如果没有输出或只有很少的事件，说明内核不支持
# 解决方案：
# 1. 使用发行版的调试内核
# 2. 或者重新编译内核，启用 CONFIG_LOCK_STAT=y
```

#### 原因2: 缺少调试符号

```bash
# 用 -g 重新编译以获得符号信息
gcc -g -O2 -Wall -Wextra -pthread -o lock_test lock_test.c

# 再次运行 perf lock
perf lock record -g ./lock_test -t 1 -p 8 -n 500000
perf lock report
```

#### 原因3: 锁竞争强度不够

```bash
# 增加线程数和迭代次数
perf lock record ./lock_test -t 1 -p 8 -n 500000

# 而不是默认的 -p 4 -n 100000
```

#### 替代分析方案

如果 perf lock 不工作，可以使用以下替代方案：

**方案1: 使用程序自身的性能输出**
```bash
# 对比不同场景的 ops/sec
./lock_test -t 1 -p 8  # 单锁竞争
./lock_test -t 2 -p 8  # 多锁并发
./lock_test -t 6 -p 8  # 伪共享
./lock_test -t 7 -p 8  # 无伪共享

# 性能差异直接反映锁竞争程度
```

**方案2: 使用 perf stat 查看系统指标**
```bash
# 查看上下文切换次数（锁竞争的副作用）
perf stat -e context-switches,cpu-migrations ./lock_test -t 1 -p 8

# 对比不同场景
```

**方案3: 使用 strace 查看 futex 系统调用**
```bash
# futex 是 pthread_mutex 的底层实现
strace -c -f ./lock_test -t 1 -p 4 -n 50000

# 查看 futex 调用次数和时间占比
```

**方案4: 使用调试脚本**
```bash
# 运行完整的诊断脚本
./lock_test_debug.sh

# 会自动尝试多种分析方法并给出建议
```

### Q: 为什么 perf lock report 显示 "no data"？

**A**: 可能原因：
1. 程序运行时间太短，没有足够的锁事件
2. 内核不支持锁跟踪事件（最常见）
3. perf 版本太老

**解决方案**:
```bash
# 1. 增加测试强度
./lock_test -p 8 -n 1000000

# 2. 检查内核支持
perf list | grep lock:

# 3. 使用替代方案（见上一个问题）
```

### Q: 如何减少锁竞争？

**A**: 优化策略：
1. **分片锁**（多个独立锁）- 提升 3-5倍
2. **减少持锁时间** - 提升 2-3倍
3. **使用读写锁**（读多写少）- 提升 2-10倍
4. **无锁数据结构**（适用场景有限）- 提升 5-20倍

**验证优化效果**:
```bash
# 对比优化前后的性能
./lock_test -t 1 -p 8  # 单锁（优化前）
./lock_test -t 2 -p 8  # 多锁（优化后）

# 或使用 time 命令
time ./lock_test -t 1 -p 8
time ./lock_test -t 2 -p 8
```

---

## 参考资料

- [perf lock 文档](https://perf.wiki.kernel.org/index.php/Tutorial#Profiling_sleep_times)
- [Linux 锁机制](https://www.kernel.org/doc/html/latest/locking/index.html)
- [POSIX 线程编程](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/pthread.h.html)

---

**最后更新**: 2026-04-18
