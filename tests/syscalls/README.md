# 系统调用性能测试

## 概述

`syscalls_test` 是一个用于测试和分析 Linux 系统调用性能的工具。它可以帮助你：
- 了解不同系统调用的开销
- 分析 CPU 周期、指令数和缓存未命中
- 对比不同系统调用的性能差异

---

## 快速开始

### 编译

```bash
cd tests/syscalls
make
```

### 运行

```bash
# 基本运行
./syscalls_test

# 使用 perf 分析
make perf

# 使用 strace 跟踪
make strace
```

### 使用测试脚本（推荐）

```bash
# 运行完整测试流程
../../scripts/syscalls/syscalls-test.sh
```

---

## 测试内容

### 1. getpid() - 最简单的系统调用

**特点**:
- 直接返回进程 ID
- 无参数，无副作用
- 主要开销是用户态↔内核态切换

**典型性能**: 100-200 万次/秒

**示例**:
```bash
./syscalls_test -t 1 -n 1000000
```

### 2. gettimeofday() - 获取系统时间

**特点**:
- 读取系统时钟
- 通常有 vDSO 优化（避免真正的系统调用）
- 比 getpid() 稍慢

**典型性能**: 50-150 万次/秒

**vDSO 优化**:
```bash
# 查看是否使用 vDSO
ldd syscalls_test | grep vdso
```

### 3. read() / write() - 文件 I/O

**特点**:
- 使用 /dev/zero 和 /dev/null（避免真实磁盘 I/O）
- 涉及内核缓冲区操作
- 每次传输 4KB 数据

**典型性能**: 10-50 万次/秒

**测试**:
```bash
./syscalls_test -t 3
```

### 4. open() / close() - 文件描述符操作

**特点**:
- 打开和关闭 /dev/null
- 涉及文件表和文件描述符分配
- 比简单的系统调用慢很多

**典型性能**: 5-20 万次/秒

### 5. stat() - 获取文件元数据

**特点**:
- 路径解析
- inode 查找
- 元数据读取

**典型性能**: 10-30 万次/秒

---

## 命令行选项

```bash
./syscalls_test [选项]

选项:
  -t <type>    测试类型 (1-6)
               1 = getpid()
               2 = gettimeofday()
               3 = read()/write()
               4 = open()/close()
               5 = stat()
               6 = 全部测试 (默认)
  -n <num>     迭代次数 (默认: 1000000)
  -h           显示帮助信息
```

---

## 使用 perf 分析

### 基本分析

```bash
perf stat -e cycles -e instructions -e cache-misses ./syscalls_test
```

**输出示例**:
```
Performance counter stats for './syscalls_test':

    15,234,567,890      cycles
    12,345,678,901      instructions              #    0.81  insn per cycle
       123,456,789      cache-misses

       2.345678 seconds time elapsed
```

### 详细事件分析

```bash
# 分析更多事件
perf stat -e cycles -e instructions -e cache-misses \
          -e context-switches -e cpu-migrations \
          -e page-faults -e branch-misses \
          ./syscalls_test
```

### 每个系统调用的开销

```bash
# 记录详细事件
perf record -e cycles ./syscalls_test -t 1

# 查看报告
perf report
```

---

## 使用 strace 跟踪

### 统计系统调用

```bash
strace -c ./syscalls_test
```

**输出示例**:
```
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 99.99    2.345678           2   1000000           getpid
  0.01    0.000234         234         1           execve
  0.00    0.000045          45         1           brk
------ ----------- ----------- --------- --------- ----------------
100.00    2.345957                1000002           total
```

### 详细跟踪

```bash
# 只跟踪 getpid
strace -e trace=getpid ./syscalls_test -t 1 -n 10

# 显示时间戳
strace -t -e trace=getpid ./syscalls_test -t 1 -n 10
```

---

## 性能基准

### 系统调用开销对比

| 系统调用 | 典型性能 (ops/sec) | 相对开销 | 说明 |
|---------|-------------------|---------|------|
| getpid() | 1,000,000 - 2,000,000 | 1x | 最快 |
| gettimeofday() | 500,000 - 1,500,000 | 1.5x | vDSO 优化 |
| read()/write() | 100,000 - 500,000 | 4x | 缓冲区操作 |
| open()/close() | 50,000 - 200,000 | 10x | 文件表操作 |
| stat() | 100,000 - 300,000 | 5x | 路径解析 |

### CPU 指标

| 指标 | 含义 | 好的值 |
|------|------|--------|
| cycles | CPU 周期数 | 越少越好 |
| instructions | 执行的指令数 | 越少越好 |
| insn per cycle | 每周期指令数 (IPC) | > 1.0 |
| cache-misses | 缓存未命中次数 | 越少越好 |
| context-switches | 上下文切换次数 | 应该很少 |

---

## 结果解析

### 示例输出

```
╔═══════════════════════════════════════════════════════════╗
║         Linux 系统调用性能测试                            ║
╚═══════════════════════════════════════════════════════════╝

测试配置:
  迭代次数: 1000000
  测试类型: 全部测试

[1/5] 测试 getpid() 系统调用
----------------------------------------
说明: getpid() 是最简单的系统调用之一，直接返回进程ID
开销: 主要是用户态→内核态的切换开销

getpid()            :    1000000 iterations in     852.34 ms ->   1173236 ops/sec
最后一次PID: 12345

[2/5] 测试 gettimeofday() 系统调用
----------------------------------------
说明: 获取当前时间，需要读取系统时钟
开销: 比getpid()稍重，但通常有vDSO优化

gettimeofday()      :    1000000 iterations in    1234.56 ms ->    810000 ops/sec

...
```

### 关键指标解读

**ops/sec (每秒操作数)**:
- > 1,000,000: 非常快（getpid 级别）
- 100,000 - 1,000,000: 快（大多数系统调用）
- 10,000 - 100,000: 中等（涉及 I/O 的调用）
- < 10,000: 慢（复杂的系统调用）

**IPC (每周期指令数)**:
- > 1.5: 优秀（CPU 流水线效率高）
- 1.0 - 1.5: 良好
- 0.5 - 1.0: 一般
- < 0.5: 较差（可能有大量缓存未命中）

**cache-misses**:
- 应该 < 总指令数的 1%
- 过高说明数据访问模式不友好

---

## 高级用法

### 对比不同优化级别

```bash
# 编译不同优化级别
gcc -O0 -o syscalls_test_O0 syscalls_test.c
gcc -O2 -o syscalls_test_O2 syscalls_test.c
gcc -O3 -o syscalls_test_O3 syscalls_test.c

# 对比性能
perf stat ./syscalls_test_O0
perf stat ./syscalls_test_O2
perf stat ./syscalls_test_O3
```

### CPU 亲和性测试

```bash
# 绑定到 CPU 0
taskset -c 0 ./syscalls_test

# 绑定到 CPU 1
taskset -c 1 ./syscalls_test

# 对比性能差异
```

### 多线程系统调用测试

可以扩展程序支持多线程，测试并发系统调用的性能。

---

## 常见问题

### Q: 为什么 gettimeofday() 有时比 getpid() 还快？

**A**: 因为 vDSO (virtual Dynamic Shared Object) 优化。

```bash
# 查看是否启用 vDSO
cat /proc/self/maps | grep vdso

# vDSO 将某些系统调用在用户空间实现，避免陷入内核
# 受益的系统调用: gettimeofday, time, clock_gettime
```

### Q: read()/write() 为什么比 open()/close() 快？

**A**:
- read/write: 文件描述符已存在，只需缓冲区操作
- open/close: 需要文件表查找、分配/释放文件描述符

### Q: 如何减少系统调用开销？

**A**:
1. **批处理**: 一次系统调用处理更多数据
2. **缓存**: 缓存频繁访问的数据（如 pid）
3. **异步 I/O**: 避免阻塞等待
4. **用户态实现**: 使用 vDSO 或用户态库

---

## 实际应用

### 1. 性能调优

```bash
# 测试应用的系统调用分布
strace -c ./your_application

# 找出最频繁的系统调用
# 优化或减少这些调用
```

### 2. 基准测试

```bash
# 建立系统调用性能基线
./syscalls_test > baseline.txt

# 系统升级后对比
./syscalls_test > after_upgrade.txt
diff baseline.txt after_upgrade.txt
```

### 3. 学习内核

```bash
# 观察系统调用的实现
strace -v -e trace=getpid ./syscalls_test -t 1 -n 1

# 查看内核源码
# kernel/sys.c - getpid() 实现
# kernel/time.c - gettimeofday() 实现
```

---

## 扩展

### 添加新的测试

编辑 `syscalls_test.c`，添加新的测试函数：

```c
void test_my_syscall(long iterations) {
    double start, end;
    long i;
    perf_stats_t stats;

    start = get_time_us();
    for (i = 0; i < iterations; i++) {
        // 调用你的系统调用
        my_syscall();
    }
    end = get_time_us();

    stats.name = "my_syscall()";
    stats.iterations = iterations;
    stats.elapsed_time = end - start;
    stats.ops_per_sec = (double)iterations / (stats.elapsed_time / 1000000.0);
    print_stats(&stats);
}
```

---

## 参考资料

- [Linux 系统调用表](https://filippo.io/linux-syscall-table/)
- [vDSO 文档](https://man7.org/linux/man-pages/man7/vdso.7.html)
- [Perf Wiki](https://perf.wiki.kernel.org/)
- [系统调用性能分析](http://www.brendangregg.com/blog/2014-05-11/strace-wow-much-syscall.html)

---

**最后更新**: 2026-04-18
