# 内存分析工具测试套件 (Valgrind & Pmap)

## 概述

本测试套件提供Valgrind和pmap两个强大的内存分析工具的测试案例和模拟程序，用于检测内存问题和分析内存布局。

## 目录结构

```
memory-analysis/
├── README.md                       # 本文件
├── programs/
│   ├── memory_leak.c               # 内存泄漏示例程序
│   ├── valgrind_tests.c            # Valgrind综合测试程序
│   └── memory_layout.c             # 内存布局演示程序
├── scripts/
│   ├── test_valgrind.sh            # Valgrind测试脚本
│   └── test_pmap.sh                # Pmap测试脚本
└── results/                        # 测试结果目录
```

## 工具介绍

### Valgrind - 内存调试工具

**功能：**
- 内存泄漏检测
- 无效内存访问检测
- 使用未初始化值检测
- 重复释放检测
- 使用已释放内存检测

**工作原理：**
- 在虚拟CPU上运行程序
- 拦截所有内存操作
- 跟踪每个字节的状态
- 检测非法访问

**性能影响：**
- 运行速度：原程序的1/20 - 1/30
- 内存占用：增加2-3倍

### Pmap - 内存映射分析工具

**功能：**
- 显示进程内存映射
- 分析内存布局
- 查看各区域大小
- 监控内存变化

**内存区域：**
- 代码段 (Text)
- 数据段 (Data/BSS)
- 堆 (Heap)
- 栈 (Stack)
- 共享库 (.so)
- 匿名映射 (mmap)

## 前置条件

### 安装Valgrind

```bash
# Ubuntu/Debian
sudo apt-get install valgrind

# RHEL/CentOS
sudo yum install valgrind

# Fedora
sudo dnf install valgrind

# 验证安装
valgrind --version
```

### 安装Pmap

Pmap通常包含在procps包中：

```bash
# Ubuntu/Debian
sudo apt-get install procps

# RHEL/CentOS
sudo yum install procps-ng
```

## 测试程序说明

### 1. memory_leak.c - 内存泄漏示例

演示12种内存问题：

1. **简单内存泄漏** - 忘记释放malloc分配的内存
2. **循环泄漏** - 循环中重复泄漏
3. **条件泄漏** - 某些分支忘记释放
4. **结构体泄漏** - 只释放外层，忘记内部指针
5. **重复释放** - 同一块内存释放两次
6. **使用已释放内存** - Use-after-free
7. **数组越界** - 访问数组边界外的内存
8. **未初始化读取** - 读取未初始化的内存
9. **内存池泄漏** - 部分释放导致泄漏
10. **正确使用** - 演示正确的内存管理
11. **递归分配泄漏** - 递归中忘记释放
12. **所有问题综合** - 完整演示

**编译运行：**
```bash
cd programs
gcc -g -o memory_leak memory_leak.c
./memory_leak
```

**Valgrind检测：**
```bash
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --track-origins=yes \
         ./memory_leak
```

### 2. valgrind_tests.c - Valgrind综合测试

演示15种Valgrind可检测的问题：

1. **内存泄漏**
2. **无效读取** - 数组越界读
3. **无效写入** - 数组越界写
4. **未初始化值**
5. **无效释放** - 释放栈变量
6. **重复释放**
7. **Use-after-free**
8. **重叠memcpy**
9. **条件跳转依赖未初始化值**
10. **malloc失败处理**
11. **realloc问题**
12. **字符串溢出**
13. **堆缓冲区溢出**
14. **栈缓冲区溢出**
15. **正确的内存管理**

### 3. memory_layout.c - 内存布局演示

展示各种内存区域：

- **小块堆分配** - malloc(< 128KB)
- **大块堆分配** - malloc(> 128KB)
- **直接mmap分配** - mmap()
- **栈内存** - 局部变量
- **全局变量** - BSS段和Data段
- **代码段** - 只读代码

**运行：**
```bash
./memory_layout        # 交互式查看内存映射
./memory_layout growth # 演示内存增长
```

## 运行测试

### Valgrind测试

**自动化测试：**
```bash
cd scripts
./test_valgrind.sh
```

**手动测试：**
```bash
# 基本检查
valgrind ./program

# 完整检查（推荐）
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --track-origins=yes \
         --verbose \
         --log-file=valgrind.log \
         ./program
```

### Pmap测试

**自动化测试：**
```bash
cd scripts
./test_pmap.sh
```

**手动测试：**
```bash
# 获取进程PID
ps aux | grep program

# 基本映射
pmap <pid>

# 扩展格式
pmap -x <pid>

# 详细格式
pmap -X <pid>

# 查看/proc文件
cat /proc/<pid>/maps
cat /proc/<pid>/smaps
```

## Valgrind使用指南

### 核心工具

**1. Memcheck（默认）**
```bash
valgrind --tool=memcheck ./program
```

检测：
- 内存泄漏
- 无效访问
- 未初始化值
- 重复释放

**2. Cachegrind - 缓存分析**
```bash
valgrind --tool=cachegrind ./program
cg_annotate cachegrind.out.<pid>
```

**3. Callgrind - 调用图分析**
```bash
valgrind --tool=callgrind ./program
callgrind_annotate callgrind.out.<pid>
```

**4. Helgrind - 线程错误**
```bash
valgrind --tool=helgrind ./program
```

检测：
- 数据竞争
- 死锁
- 锁顺序问题

**5. Massif - 堆分析**
```bash
valgrind --tool=massif ./program
ms_print massif.out.<pid>
```

### 常用选项

```bash
# 泄漏检测级别
--leak-check=no|summary|yes|full

# 显示泄漏类型
--show-leak-kinds=definite,indirect,possible,reachable

# 跟踪未初始化值来源
--track-origins=yes

# 详细输出
--verbose

# 输出到文件
--log-file=<file>

# XML格式
--xml=yes --xml-file=<file>

# 生成抑制规则
--gen-suppressions=all
```

### 泄漏类型

**Definitely Lost（确定泄漏）**
- 没有任何指针指向这块内存
- 必须修复

**Indirectly Lost（间接泄漏）**
- 父结构泄漏导致的子泄漏
- 修复父泄漏即可

**Possibly Lost（可能泄漏）**
- 有内部指针但无起始指针
- 可能是误报，需要检查

**Still Reachable（仍可达）**
- 程序结束时未释放，但有指针指向
- 通常可以忽略（除非是服务器程序）

**Suppressed（被抑制）**
- 通过抑制文件忽略的泄漏
- 通常是已知的库问题

### 结果解读

**输出示例：**
```
HEAP SUMMARY:
    in use at exit: 17,500 bytes in 15 blocks
  total heap usage: 20 allocs, 5 frees, 20,000 bytes allocated

LEAK SUMMARY:
   definitely lost: 100 bytes in 1 blocks
   indirectly lost: 5,000 bytes in 5 blocks
     possibly lost: 200 bytes in 2 blocks
   still reachable: 12,200 bytes in 7 blocks
        suppressed: 0 bytes in 0 blocks
```

**关注重点：**
1. Definitely lost - 必须修复
2. Indirectly lost - 修复父泄漏
3. Invalid read/write - 严重错误，必须修复
4. Uninitialized value - 可能导致未定义行为

## Pmap使用指南

### 基本用法

```bash
# 基本映射
pmap <pid>

# 扩展格式（显示RSS、Dirty等）
pmap -x <pid>

# 详细格式
pmap -X <pid>

# 设备格式
pmap -d <pid>

# 显示完整路径
pmap -p <pid>
```

### 输出字段

**基本格式：**
```
Address           Kbytes  Mode  Mapping
00400000              8  r-x-- program
00601000              4  r---- program
00602000              4  rw--- program
01234000           1024  rw---   [ anon ]
7fff12345000        132  rw---   [ stack ]
```

**扩展格式（-x）：**
```
Address   Kbytes    RSS   Dirty Mode   Mapping
00400000       8      8       0 r-x--  program
00601000       4      4       4 r----  program
00602000       4      4       4 rw---  program
```

**字段说明：**
- **Address** - 虚拟地址
- **Kbytes** - 大小（KB）
- **RSS** - 实际物理内存（Resident Set Size）
- **Dirty** - 脏页（已修改）
- **Mode** - 权限（r/w/x/s/p）
- **Mapping** - 映射名称或文件

### 权限标志

```
r - Read（可读）
w - Write（可写）
x - Execute（可执行）
s - Shared（共享）
p - Private（私有）
```

**常见组合：**
- `r-xp` - 代码段（只读可执行）
- `rw-p` - 数据段（可读写）
- `r--p` - 只读数据
- `rw-s` - 共享内存

### 分析示例

**1. 查找内存泄漏**
```bash
# 监控堆增长
watch -n 1 'pmap -x <pid> | grep heap'

# 或使用循环
while true; do
    pmap -x <pid> | grep heap | awk '{print $2}'
    sleep 1
done
```

**2. 分析共享库占用**
```bash
pmap -x <pid> | grep '\.so'
```

**3. 查找大块分配**
```bash
pmap -x <pid> | awk '$2 > 10240 {print}'
# 显示>10MB的映射
```

**4. 对比进程内存**
```bash
diff <(pmap <pid1>) <(pmap <pid2>)
```

**5. 统计内存类型**
```bash
# 统计代码段总大小
pmap <pid> | grep 'r-x' | awk '{sum+=$2} END {print sum " KB"}'

# 统计匿名映射
pmap <pid> | grep 'anon' | awk '{sum+=$2} END {print sum " KB"}'
```

## /proc文件系统

### /proc/<pid>/maps

**格式：**
```
address           perms offset  dev   inode   pathname
00400000-00401000 r-xp  00000000 08:01 12345  /path/to/program
```

**字段：**
- address - 起始-结束地址
- perms - 权限（r/w/x/p/s）
- offset - 文件偏移
- dev - 设备号
- inode - inode号
- pathname - 映射文件路径

### /proc/<pid>/smaps

详细内存映射信息：
```
00400000-00401000 r-xp 00000000 08:01 12345  /program
Size:                  4 kB
Rss:                   4 kB
Pss:                   4 kB
Shared_Clean:          0 kB
Shared_Dirty:          0 kB
Private_Clean:         4 kB
Private_Dirty:         0 kB
Referenced:            4 kB
Anonymous:             0 kB
AnonHugePages:         0 kB
Swap:                  0 kB
KernelPageSize:        4 kB
MMUPageSize:           4 kB
Locked:                0 kB
```

**关键字段：**
- **RSS** - 实际物理内存
- **PSS** - 按比例分摊的内存
- **Private_Dirty** - 私有脏页（真实内存占用）
- **Shared_Clean** - 共享干净页（如共享库代码）

### /proc/<pid>/status

内存统计信息：
```
VmPeak:    12345 kB  # 峰值虚拟内存
VmSize:    12000 kB  # 当前虚拟内存
VmLck:         0 kB  # 锁定内存
VmPin:         0 kB  # 固定内存
VmHWM:      2345 kB  # 峰值物理内存
VmRSS:      2000 kB  # 当前物理内存
VmData:     1000 kB  # 数据段
VmStk:       132 kB  # 栈
VmExe:         8 kB  # 代码段
VmLib:      5000 kB  # 共享库
VmPTE:        40 kB  # 页表
VmSwap:        0 kB  # 交换空间
```

## 常见问题

### Valgrind相关

**问题1: 程序运行太慢**

**原因：** Valgrind使程序慢20-30倍

**解决：**
```bash
# 使用小数据集
# 使用--leak-check=summary代替full
# 只测试关键代码路径
```

**问题2: 误报（False Positives）**

**原因：** 某些库有已知"泄漏"

**解决：**
```bash
# 使用抑制文件
valgrind --suppressions=mysupp.txt ./program

# 生成抑制规则
valgrind --gen-suppressions=all ./program 2>&1 | \
    grep -A 20 'insert a suppression'
```

**问题3: 无调试信息**

**解决：**
```bash
# 使用-g编译
gcc -g -O0 program.c  # -O0禁用优化
```

### Pmap相关

**问题1: Permission denied**

**解决：**
```bash
# 使用sudo
sudo pmap <pid>

# 或分析自己的进程
```

**问题2: 进程不存在**

**解决：**
```bash
# 确认PID正确
ps aux | grep program

# 或使用pgrep
pmap $(pgrep program)
```

## 最佳实践

### 开发阶段

```bash
# 1. 编译时使用-g
gcc -g -O0 program.c

# 2. 定期运行Valgrind
valgrind --leak-check=full ./program

# 3. 配合单元测试
valgrind ./run_tests

# 4. 监控内存增长
while true; do pmap -x <pid> | grep heap; sleep 1; done
```

### 调试流程

```bash
# 1. 初步检查
valgrind --leak-check=summary ./program

# 2. 详细分析
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --track-origins=yes \
         --log-file=val.log \
         ./program

# 3. 查看报告
cat val.log

# 4. 修复代码

# 5. 重新测试
valgrind --leak-check=full ./program

# 6. pmap验证
pmap -x <pid>
```

### CI/CD集成

```bash
#!/bin/bash
# 在CI中运行Valgrind

valgrind --leak-check=full \
         --error-exitcode=1 \
         --log-file=valgrind.log \
         ./program

if [ $? -ne 0 ]; then
    cat valgrind.log
    exit 1
fi
```

## 工具对比

| 工具 | 用途 | 优势 | 劣势 |
|------|------|------|------|
| **Valgrind** | 内存调试 | 全面检测 | 性能影响大 |
| **Pmap** | 内存布局 | 无性能影响 | 静态快照 |
| **gdb** | 调试 | 交互式 | 需要断点 |
| **AddressSanitizer** | 内存检测 | 快速（2-3x） | 需要重新编译 |
| **LeakSanitizer** | 泄漏检测 | 快速 | 仅泄漏检测 |

## 测试结果

运行测试脚本后生成：

**Valgrind测试：**
- `principles.txt` - 测试原理
- `*_valgrind.txt` - Valgrind详细报告
- `summary.txt` - 结果摘要
- `options_guide.txt` - 选项指南
- `troubleshooting.txt` - 故障排查
- `report.txt` - 测试报告

**Pmap测试：**
- `principles.txt` - 工具原理
- `system_processes.txt` - 系统进程分析
- `test_program_analysis.txt` - 测试程序分析
- `field_explanation.txt` - 字段解析
- `usage_examples.txt` - 使用示例
- `tool_comparison.txt` - 工具对比
- `report.txt` - 测试报告

## 参考资料

- [Valgrind官方文档](https://valgrind.org/docs/manual/manual.html)
- [Valgrind快速入门](https://valgrind.org/docs/manual/quick-start.html)
- [proc文件系统](https://man7.org/linux/man-pages/man5/proc.5.html)
- [内存管理最佳实践](https://en.wikipedia.org/wiki/Memory_management)

---

**更新日期:** 2026-04-19
**版本:** 1.0
