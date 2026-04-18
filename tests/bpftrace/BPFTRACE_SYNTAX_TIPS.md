# bpftrace 语法技巧和常见问题

## 概述

bpftrace 使用一种类似 awk 的语法，但有一些特殊的限制和注意事项。本文档总结常见的语法问题和解决方案。

## 常见错误和解决方案

### 1. 浮点数运算

**❌ 错误示例：**
```c
printf("平均值: %.2f\n", @total / @count);  // 错误！
printf("结果: %d ms\n", @value / 1000.0);   // 错误！
```

**错误信息：**
```
ERROR: Type mismatch for '/': comparing 'unsigned int64' with 'none'
ERROR: Can not access index 0 on expression of type 'int64'
```

**原因：**
bpftrace 在 printf 中不支持浮点除法运算。

**✅ 正确示例：**
```c
// 方法1：使用整数除法
printf("结果: %d ms\n", @value / 1000);

// 方法2：先计算再打印（如果需要小数）
BEGIN {
    @value = 12345;
    $ms = @value / 1000;  // 整数除法
    printf("结果: %d ms\n", $ms);
}

// 方法3：如果一定要浮点数，在 END 块外处理
END {
    // 输出原始值，让外部脚本处理
    printf("%d\n", @value);
}
```

### 2. 有符号/无符号整数运算

**❌ 错误示例：**
```c
printf("平均: %d\n", @total_us / @count);
```

**警告信息：**
```
WARNING: arithmetic on integers of different signs: 'unsigned int64' and 'int64'
WARNING: signed operands for '/' can lead to undefined behavior
```

**✅ 正确示例：**
```c
// 显式转换为 uint64
printf("平均: %d\n", (uint64)@total_us / (uint64)@count);

// 或者使用一致的类型
printf("平均: %llu\n", @total_us / @count);
```

### 3. 格式字符串参数不匹配

**❌ 错误示例：**
```c
printf("值1: %d, 值2: %d\n", @value1);  // 缺少第二个参数
printf("值: %d\n", @value1, @value2);   // 参数过多
```

**错误信息：**
```
ERROR: printf: Too many arguments for format string
ERROR: printf: Not enough arguments for format string
```

**✅ 正确示例：**
```c
// 参数数量匹配
printf("值1: %d, 值2: %d\n", @value1, @value2);

// 或者分开打印
printf("值1: %d\n", @value1);
printf("值2: %d\n", @value2);
```

### 4. 变量作用域

**❌ 错误示例：**
```c
kprobe:func1 {
    $temp = 100;
}

kprobe:func2 {
    printf("%d\n", $temp);  // 错误！$temp 超出作用域
}
```

**✅ 正确示例：**
```c
// 使用全局变量（@）
kprobe:func1 {
    @temp = 100;
}

kprobe:func2 {
    printf("%d\n", @temp);  // 正确
}

// 或使用关联数组
kprobe:func1 {
    @data[tid] = 100;
}

kprobe:func2 /@data[tid]/ {
    printf("%d\n", @data[tid]);
}
```

### 5. 字符串操作

**❌ 错误示例：**
```c
printf("用户: %s\n", str(arg0) + str(arg1));  // 不支持字符串拼接
```

**✅ 正确示例：**
```c
// 方法1：分别打印
printf("用户: %s %s\n", str(arg0), str(arg1));

// 方法2：使用 join（如果是路径）
printf("路径: %s\n", str(arg0));
```

### 6. 条件判断中的变量

**❌ 错误示例：**
```c
kprobe:func /@count > 0/ {
    @avg = @total / @count;  // 如果 @count 未初始化会出错
}
```

**✅ 正确示例：**
```c
// 确保变量已初始化
BEGIN {
    @count = 0;
    @total = 0;
}

kprobe:func /@count > 0/ {
    @avg = @total / @count;
}

// 或在条件中检查
kprobe:func {
    if (@count > 0) {
        @avg = @total / @count;
    }
}
```

## 最佳实践

### 1. 变量命名约定

```c
// 局部变量：$variable
kprobe:func {
    $pid = pid;
    $duration = nsecs - @start[tid];
}

// 全局变量/Map：@variable
BEGIN {
    @count = 0;
    @sum = 0;
}

// 关联数组：@map[key]
kprobe:func {
    @latency[comm] = hist(nsecs - @start[tid]);
}
```

### 2. 类型转换

```c
// 显式转换避免警告
printf("%d\n", (int32)arg0);
printf("%u\n", (uint32)arg0);
printf("%lld\n", (int64)arg0);
printf("%llu\n", (uint64)arg0);

// 字符串转换
printf("%s\n", str(arg0));
```

### 3. 安全的除法

```c
// 检查除数
if (@count > 0) {
    @avg = @total / @count;
}

// 或使用默认值
END {
    $avg = @count > 0 ? @total / @count : 0;
    printf("平均值: %d\n", $avg);
}
```

### 4. 内存管理

```c
// 定期清理 map
interval:s:60 {
    clear(@large_map);
}

// 限制 map 大小
END {
    print(@latency, 100);  // 只打印前 100 项
}

// 删除不需要的条目
kretprobe:func {
    delete(@start[tid]);  // 及时删除已用完的数据
}
```

### 5. 错误处理

```c
// 检查探针是否存在
BEGIN {
    printf("开始跟踪...\n");
}

// 处理缺失的数据
kretprobe:func /@start[tid]/ {  // 只处理有数据的情况
    $duration = nsecs - @start[tid];
    @hist = hist($duration);
    delete(@start[tid]);
}

// 提供有用的输出
END {
    if (@count == 0) {
        printf("警告: 未捕获任何事件\n");
    }
}
```

## 性能优化技巧

### 1. 减少 printf 调用

**❌ 低效：**
```c
kprobe:func {
    printf("事件发生\n");  // 每次都打印
}
```

**✅ 高效：**
```c
kprobe:func {
    @count++;  // 只计数
}

END {
    printf("总共 %d 个事件\n", @count);
}
```

### 2. 使用采样

```c
// 只跟踪 1% 的事件
kprobe:func /rand() % 100 == 0/ {
    @sampled++;
}

// 按时间间隔采样
kprobe:func {
    if (nsecs - @last_sample > 1000000000) {  // 1秒
        @last_sample = nsecs;
        @count++;
    }
}
```

### 3. 限制字符串长度

```c
// 截断长字符串
printf("文件: %.32s\n", str(arg0));  // 最多 32 字符
```

### 4. 使用直方图而非原始数据

**❌ 内存占用大：**
```c
kprobe:func {
    @latencies[tid] = nsecs - @start[tid];  // 每个 tid 一个值
}
```

**✅ 内存高效：**
```c
kprobe:func {
    @latency_hist = hist(nsecs - @start[tid]);  // 直方图统计
}
```

## 调试技巧

### 1. 打印中间值

```c
kprobe:func {
    $value = arg0;
    printf("DEBUG: arg0=%d\n", $value);

    $result = $value * 2;
    printf("DEBUG: result=%d\n", $result);
}
```

### 2. 检查探针是否触发

```c
BEGIN {
    printf("脚本已启动\n");
}

kprobe:func {
    printf("探针触发！\n");
    @triggered++;
}

END {
    printf("探针触发次数: %d\n", @triggered);
}
```

### 3. 验证过滤条件

```c
kprobe:func {
    printf("所有事件: pid=%d\n", pid);
}

kprobe:func /pid == 1234/ {
    printf("过滤后: pid=%d\n", pid);
}
```

## 完整示例

### 示例 1: 系统调用延迟

```c
#!/usr/bin/env bpftrace

BEGIN {
    printf("跟踪系统调用延迟...\n");
    @count = 0;
}

tracepoint:raw_syscalls:sys_enter {
    @start[tid] = nsecs;
}

tracepoint:raw_syscalls:sys_exit /@start[tid]/ {
    $duration = nsecs - @start[tid];
    $duration_us = (uint64)$duration / 1000;

    @latency = hist($duration_us);
    @total_us += $duration_us;
    @count++;

    delete(@start[tid]);
}

interval:s:5 {
    printf("\n[%d 秒] 统计: %d 次调用\n",
           (uint64)elapsed / 1000000000, @count);
}

END {
    clear(@start);

    printf("\n=== 最终统计 ===\n");
    printf("总调用次数: %d\n", @count);

    if (@count > 0) {
        $avg = (uint64)@total_us / (uint64)@count;
        printf("平均延迟: %d us\n", $avg);
    }

    printf("\n延迟分布:\n");
    print(@latency);
}
```

### 示例 2: 进程 I/O 统计

```c
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_read,
tracepoint:syscalls:sys_enter_write {
    @io_count[comm]++;
    @io_bytes[comm] += args->count;
}

END {
    printf("\n=== 进程 I/O 统计 ===\n");
    printf("\n按次数:\n");
    print(@io_count, 10);

    printf("\n按字节数:\n");
    print(@io_bytes, 10);
}
```

## 参考资料

- [bpftrace 官方文档](https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md)
- [bpftrace 教程](https://github.com/iovisor/bpftrace/blob/master/docs/tutorial_one_liners.md)
- [内置函数列表](https://github.com/iovisor/bpftrace/blob/master/docs/reference_guide.md#builtins)

---

更新日期：2026-04-18
