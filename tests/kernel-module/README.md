# 内核模块（驱动程序）测试套件

## 概述

本测试套件提供了完整的内核模块开发和测试工具，包括简单的测试驱动程序和全面的测试脚本。

## 目录结构

```
kernel-module/
├── README.md                       # 本文件
├── driver/
│   ├── test_driver.c               # 测试驱动程序
│   ├── test_device.c               # 虚拟设备模拟器
│   └── Makefile                    # 内核模块 Makefile
├── scripts/
│   ├── test_load_unload.sh         # 加载/卸载循环测试
│   └── test_bind_unbind.sh         # 设备绑定/解绑测试
└── results/                        # 测试结果存储
```

## 测试驱动程序特性

### test_driver.c

**功能：**
- 字符设备接口（/dev/testdev）
- Platform 驱动框架
- 电源管理支持（suspend/resume）
- Runtime PM 支持
- 调试级别控制

**支持的操作：**
- 设备打开/关闭
- 读写操作
- 设备探测（probe）/移除（remove）
- 挂起（suspend）/恢复（resume）
- Runtime 电源管理

### test_device.c

**功能：**
- 创建虚拟 platform 设备
- 自动绑定到 test_driver
- 支持多设备

## 编译和安装

### 前置条件

```bash
# 安装内核头文件和编译工具
# Ubuntu/Debian
sudo apt-get install build-essential linux-headers-$(uname -r)

# RHEL/CentOS/Fedora
sudo yum install gcc make kernel-devel kernel-headers

# 检查内核头文件
ls /lib/modules/$(uname -r)/build
```

### 编译模块

```bash
cd driver
make

# 输出
# test_driver.ko - 主驱动模块
# test_device.ko - 设备模拟模块
```

### 手动加载/卸载

```bash
# 加载驱动
sudo insmod test_driver.ko

# 加载设备
sudo insmod test_device.ko

# 查看加载状态
lsmod | grep test_

# 查看设备节点
ls -l /dev/testdev

# 测试读取
cat /dev/testdev

# 卸载（按相反顺序）
sudo rmmod test_device
sudo rmmod test_driver

# 查看内核日志
dmesg | grep test_driver
```

### 调试级别

```bash
# 加载时设置调试级别（0-3）
sudo insmod test_driver.ko debug_level=2

# 运行时修改（如果已加载）
echo 3 | sudo tee /sys/module/test_driver/parameters/debug_level
```

## 测试脚本

### 1. 加载/卸载循环测试

**脚本：** `scripts/test_load_unload.sh`

**测试内容：**
- 单次加载/卸载验证
- 100 次循环加载/卸载
- 资源泄漏检测（SLAB、文件描述符）
- 内核日志收集

**运行：**
```bash
cd scripts
sudo ./test_load_unload.sh
```

**预期结果：**
- 所有 100 次循环成功
- 无 SLAB 内存泄漏
- 无文件描述符泄漏

**典型输出：**
```
========================================"
内核模块加载/卸载测试
========================================

步骤 1: 编译内核模块...
✓ 模块编译成功
  test_driver.ko: 15K
  test_device.ko: 12K

步骤 2: 基础加载/卸载测试...
✓ 加载成功
✓ 卸载成功

步骤 3: 循环加载/卸载测试...
执行 100 次循环...
  完成 10/100 次迭代...
  ...
  完成 100/100 次迭代...

循环测试完成!

步骤 4: 资源泄漏检查...
SLAB 内存检查:
  无 test_driver slab 对象（正常）

SLAB 内存变化:
  初始: 245632 kB
  最终: 245648 kB
  差异: 16 kB
  ✓ SLAB 内存正常

✓ 所有测试通过！
```

### 2. 设备绑定/解绑测试

**脚本：** `scripts/test_bind_unbind.sh`

**测试内容：**
- 设备自动探测验证
- 单次手动解绑/绑定
- 100 次循环绑定/解绑
- 多设备并发测试（如果有多个设备）

**运行：**
```bash
cd scripts
sudo ./test_bind_unbind.sh
```

**预期结果：**
- 设备自动绑定到驱动
- 手动绑定/解绑成功
- 所有循环测试通过

**典型输出：**
```
========================================
设备绑定/解绑测试
========================================

步骤 1: 加载驱动和设备...
✓ 驱动已加载
✓ 设备已加载

步骤 2: 查找 platform 设备...
找到 2 个设备:
  - test_driver.0
  - test_driver.1

步骤 3: 单次解绑/绑定测试...
✓ 解绑成功
✓ 绑定成功

步骤 4: 循环绑定/解绑测试...
执行 100 次循环...
  完成 10/100 次迭代...
  ...
  完成 100/100 次迭代...

✓ 所有测试通过！
```

## 高级测试场景

### 电源管理测试（手动）

```bash
# 1. 加载模块
sudo insmod driver/test_driver.ko debug_level=2
sudo insmod driver/test_device.ko

# 2. 查找设备路径
DEVICE=$(ls /sys/bus/platform/devices/ | grep test_driver | head -1)
DEVICE_PATH="/sys/bus/platform/devices/$DEVICE"

# 3. 检查电源管理支持
cat $DEVICE_PATH/power/control
# 输出: auto 或 on

# 4. 测试 Runtime PM
echo auto > $DEVICE_PATH/power/control
cat $DEVICE_PATH/power/runtime_status
# 可能输出: suspended, active, etc.

# 5. 强制挂起（如果支持）
echo mem > /sys/power/state
# 唤醒后检查驱动是否恢复

# 6. 查看电源管理统计
cat $DEVICE_PATH/power/runtime_active_time
cat $DEVICE_PATH/power/runtime_suspended_time

# 7. 卸载
sudo rmmod test_device test_driver
```

### 并发压力测试

```bash
#!/bin/bash
# 多进程并发加载/卸载

for i in {1..10}; do
    (
        for j in {1..20}; do
            sudo insmod driver/test_driver.ko 2>/dev/null
            sleep 0.01
            sudo rmmod test_driver 2>/dev/null
            sleep 0.01
        done
    ) &
done

wait
echo "并发测试完成"
```

### 资源监控

```bash
# 实时监控 SLAB 内存
watch -n 1 'grep -i slab /proc/meminfo'

# 监控模块内存使用
watch -n 1 'cat /proc/modules | grep test_'

# 监控系统调用
strace -c cat /dev/testdev

# 监控内核事件
sudo perf record -e 'syscalls:*' -a sleep 5
sudo perf report
```

## 故障排查

### 编译错误

**问题：** `No such file or directory: /lib/modules/.../build`

**解决：**
```bash
# 安装内核头文件
sudo apt-get install linux-headers-$(uname -r)  # Ubuntu/Debian
sudo yum install kernel-devel-$(uname -r)       # RHEL/CentOS
```

**问题：** `modversions: Symbol version dump ... is missing`

**解决：**
```bash
# 清理并重新编译
cd driver
make clean
make
```

### 加载错误

**问题：** `insmod: ERROR: could not insert module`

**解决：**
```bash
# 查看详细错误
dmesg | tail -20

# 检查依赖
modinfo driver/test_driver.ko

# 检查是否已加载
lsmod | grep test_driver

# 强制卸载
sudo rmmod -f test_driver
```

**问题：** `Device or resource busy`

**解决：**
```bash
# 检查设备占用
lsof | grep testdev

# 检查引用计数
cat /proc/modules | grep test_driver

# 关闭占用进程后重试
```

### 测试失败

**问题：** 循环测试中途失败

**解决：**
```bash
# 检查内核日志
dmesg | grep -i error

# 检查内存不足
free -h

# 降低迭代次数
# 编辑脚本，修改 ITERATIONS=100 为更小值
```

## 开发和调试

### 添加新功能

1. 修改 `test_driver.c`
2. 重新编译：`make clean && make`
3. 测试新功能
4. 运行完整测试套件验证

### 调试技巧

```bash
# 1. 使用 printk 调试
# 在代码中添加：
pr_info("Debug: value = %d\n", value);

# 2. 动态调试
echo 'module test_driver +p' > /sys/kernel/debug/dynamic_debug/control

# 3. ftrace 跟踪
echo function > /sys/kernel/debug/tracing/current_tracer
echo test_* > /sys/kernel/debug/tracing/set_ftrace_filter
cat /sys/kernel/debug/tracing/trace

# 4. kprobe 动态探测
echo 'p:myprobe test_probe' > /sys/kernel/debug/tracing/kprobe_events
echo 1 > /sys/kernel/debug/tracing/events/kprobes/myprobe/enable
cat /sys/kernel/debug/tracing/trace
```

### 性能分析

```bash
# 使用 perf 分析
sudo perf record -e probe:test_* -a
# 运行测试
sudo perf report

# 测量延迟
time sudo insmod driver/test_driver.ko
time sudo rmmod test_driver
```

## 最佳实践

1. **始终清理资源**
   - 在 exit 函数中释放所有分配的资源
   - 使用 `devm_*` 系列函数自动管理资源

2. **错误处理**
   - 检查所有返回值
   - 提供有意义的错误消息
   - 正确的错误路径清理

3. **并发安全**
   - 使用适当的锁（mutex, spinlock）
   - 避免竞态条件
   - 注意中断上下文限制

4. **测试覆盖**
   - 测试所有代码路径
   - 包括错误情况
   - 长时间压力测试

5. **文档**
   - 注释复杂逻辑
   - 更新 README
   - 记录已知问题

## 参考资源

- [Linux Device Drivers, 3rd Edition](https://lwn.net/Kernel/LDD3/)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [Platform Devices](https://www.kernel.org/doc/html/latest/driver-api/driver-model/platform.html)
- [Power Management](https://www.kernel.org/doc/html/latest/driver-api/pm/devices.html)

---

**更新日期：** 2026-04-19
**版本：** 1.0
