# 漏洞利用防护测试套件

## 概述

本测试套件提供了完整的Linux内核安全防护机制测试工具，包括KASLR、SMEP/SMAP、栈保护、CFI等现代安全特性的检测和评估。

## 目录结构

```
security/
├── README.md                       # 本文件
├── scripts/
│   ├── test_kaslr.sh               # KASLR测试
│   ├── test_smep_smap.sh           # SMEP/SMAP测试
│   └── test_stack_protection.sh    # 栈保护和CFI测试
├── programs/                       # 测试程序（未来扩展）
├── modules/                        # 测试内核模块（未来扩展）
└── results/                        # 测试结果目录
```

## 安全特性说明

### 内存保护特性对比表

| 特性 | 功能 | 攻击类型 | 内核版本 | CPU要求 |
|------|------|----------|----------|---------|
| KASLR | 内核地址随机化 | ROP, ret2usr | 3.14+ | 无 |
| SMEP | 禁止执行用户空间代码 | ret2usr | 3.0+ | Ivy Bridge+ |
| SMAP | 禁止访问用户空间数据 | 信息泄漏 | 3.7+ | Broadwell+ |
| Stack Protector | 栈canary保护 | 栈溢出 | 所有 | 无 |
| CFI | 控制流完整性 | ROP/JOP | 4.18+ | 无 |
| CET/IBT | 硬件控制流保护 | ROP/JOP | 5.18+ | Tiger Lake+ |
| NX/XD | 数据页不可执行 | 代码注入 | 2.6+ | 所有现代CPU |
| KPTI | 页表隔离 | Meltdown | 4.15+ | 无 |

## 测试1: KASLR (内核地址空间布局随机化)

### 功能特性

- 检查KASLR启用状态
- 查看内核符号地址
- 检查kptr_restrict设置
- 验证地址随机化效果
- KASLR熵值估算

### 运行测试

```bash
cd scripts
sudo ./test_kaslr.sh
```

### 手动操作

#### 检查KASLR状态

```bash
# 查看内核命令行
cat /proc/cmdline | grep kaslr

# 如果有nokaslr，则KASLR被禁用
# 无参数或有kaslr参数，则启用（取决于内核默认配置）
```

#### 查看内核符号地址

```bash
# 查看_text符号地址
sudo grep " _text$" /proc/kallsyms

# 如果显示0000000000000000，说明被kptr_restrict保护
# 如果显示实际地址（如ffffffff81000000），则可见
```

#### 设置kptr_restrict

```bash
# 查看当前值
cat /proc/sys/kernel/kptr_restrict

# 设置保护级别
# 0 = 禁用保护（所有用户可见）
# 1 = 部分保护（非特权用户看不到）
# 2 = 完全保护（所有用户看不到）

sudo sysctl kernel.kptr_restrict=2
```

#### 验证地址随机化

```bash
# 多次重启查看_text地址变化
for i in {1..5}; do
    echo "Reboot $i:"
    sudo grep " _text$" /proc/kallsyms | head -1
    # 等待重启...
done

# 地址应该每次不同
```

### KASLR原理

**工作机制：**
1. 内核在启动时选择随机偏移量
2. 所有内核符号地址加上该偏移量
3. 典型偏移量对齐到2MB边界

**熵值：**
- x86_64架构：9-10位熵（512-1024个可能位置）
- 地址空间：0xffffffff80000000 - 0xffffffffc0000000

**绕过方法：**
1. 信息泄漏（/proc/kallsyms, dmesg）
2. 侧信道攻击（缓存时序）
3. 物理内存访问
4. 内核模块地址泄漏

### 测试结果

- `cmdline.txt` - 内核命令行参数
- `dmesg-kaslr.txt` - dmesg KASLR信息
- `kernel-config.txt` - 内核配置
- `kernel-symbols.txt` - 内核符号地址
- `address-leak.txt` - 地址泄漏测试
- `protection-assessment.txt` - 防护评估
- `summary.txt` - 测试总结

## 测试2: SMEP/SMAP

### 功能特性

- 检查CPU SMEP/SMAP支持
- 验证内核启用状态
- 查看CR4寄存器配置
- 评估绕过缓解措施

### 运行测试

```bash
cd scripts
sudo ./test_smep_smap.sh
```

### 手动操作

#### 检查CPU支持

```bash
# 检查SMEP
grep " smep " /proc/cpuinfo

# 检查SMAP
grep " smap " /proc/cpuinfo

# 两者都存在说明CPU支持
```

#### 检查内核启用状态

```bash
# 查看内核命令行
cat /proc/cmdline

# 如果有nosmep或nosmap，说明被禁用

# 查看dmesg
dmesg | grep -i "smep\|smap"
```

#### 启用/禁用SMEP/SMAP

```bash
# 禁用SMEP（仅用于测试，不推荐）
# 编辑/etc/default/grub
GRUB_CMDLINE_LINUX="nosmep"
sudo update-grub
sudo reboot

# 启用（移除nosmep参数）
GRUB_CMDLINE_LINUX=""
sudo update-grub
sudo reboot
```

### SMEP/SMAP原理

**SMEP (Supervisor Mode Execution Prevention):**
- CR4寄存器第20位控制
- 防止内核执行用户空间代码
- 违反时触发Page Fault (#PF)
- 缓解ret2usr攻击

**SMAP (Supervisor Mode Access Prevention):**
- CR4寄存器第21位控制
- 防止内核访问用户空间数据
- EFLAGS.AC=1时允许（STAC/CLAC指令）
- 防止用户空间数据利用

**绕过方法：**
1. ROP修改CR4寄存器
2. Ret2dir攻击
3. JOP (Jump-Oriented Programming)

### CPU要求

- **SMEP:** Intel Ivy Bridge+ (2012), AMD Zen+ (2018)
- **SMAP:** Intel Broadwell+ (2014), AMD Zen 2+ (2019)

### 测试结果

- `cpu-info.txt` - CPU信息
- `smep-cpuinfo.txt`, `smap-cpuinfo.txt` - CPU标志
- `kernel-config.txt` - 内核配置
- `dmesg-smep-smap.txt` - dmesg日志
- `smep-smap-principles.txt` - 原理说明
- `protection-assessment.txt` - 防护评估
- `bypass-mitigation.txt` - 绕过缓解
- `summary.txt` - 测试总结

## 测试3: 栈保护和CFI

### 功能特性

- 检查内核栈保护配置
- 验证CFI启用状态
- 检查Intel CET支持
- 评估VMAP栈和栈随机化
- 用户空间程序保护检查

### 运行测试

```bash
cd scripts
sudo ./test_stack_protection.sh
```

### 手动操作

#### 检查栈保护配置

```bash
# 查看内核配置
zcat /proc/config.gz | grep STACKPROTECTOR

# 或从boot目录
grep STACKPROTECTOR /boot/config-$(uname -r)

# 期望输出:
# CONFIG_STACKPROTECTOR=y
# CONFIG_STACKPROTECTOR_STRONG=y
```

#### 检查CFI配置

```bash
# 查看CFI配置
zcat /proc/config.gz | grep CONFIG_CFI

# Clang CFI
zcat /proc/config.gz | grep CONFIG_CFI_CLANG

# 影子栈
zcat /proc/config.gz | grep CONFIG_SHADOW_CALL_STACK
```

#### 检查Intel CET支持

```bash
# 查看CPU特性
grep -i "cet\|ibt\|shstk" /proc/cpuinfo

# cet: Control-flow Enforcement Technology
# ibt: Indirect Branch Tracking
# shstk: Shadow Stack
```

#### 检查用户程序保护

```bash
# 检查库文件的栈保护
readelf -s /lib/x86_64-linux-gnu/libc.so.6 | grep stack_chk

# 检查PIE (Position Independent Executable)
readelf -h /bin/ls | grep Type

# 检查RELRO (Relocation Read-Only)
readelf -l /bin/ls | grep GNU_RELRO
```

### 栈保护原理

**Stack Canary (栈金丝雀):**
```
高地址
+-----------------+
| 返回地址        |
+-----------------+
| Canary (随机值) |  <-- 保护返回地址
+-----------------+
| 局部变量        |
+-----------------+
| ...             |
低地址
```

**保护级别：**
1. `CONFIG_STACKPROTECTOR` - 基础保护
2. `CONFIG_STACKPROTECTOR_STRONG` - 强保护（推荐）
3. `CONFIG_STACKPROTECTOR_ALL` - 全保护（性能影响大）

**CFI (Control Flow Integrity):**
- 验证间接调用目标合法性
- 前向边CFI：检查函数指针调用
- 后向边CFI：检查返回地址（影子栈）

**Intel CET:**
- IBT (Indirect Branch Tracking)：ENDBR指令标记合法跳转目标
- Shadow Stack：硬件影子栈保护返回地址

### 绕过方法

**Canary绕过：**
1. 泄漏canary值（格式化字符串漏洞）
2. 爆破canary（逐字节）
3. 覆盖其他变量（跳过canary）

**CFI绕过：**
1. 代码重用（使用合法gadgets）
2. 数据导向编程（DOP）

### 测试结果

- `stack-config.txt` - 栈保护配置
- `cfi-config.txt` - CFI配置
- `principles.txt` - 原理说明
- `bypass-methods.txt` - 绕过方法
- `assessment.txt` - 保护评估
- `summary.txt` - 测试总结

## 其他安全特性

### NX/XD (No-Execute)

```bash
# 检查CPU支持
grep " nx " /proc/cpuinfo

# 检查用户程序
readelf -l /bin/ls | grep GNU_STACK
# 如果是RW（而非RWE），则栈不可执行
```

### KPTI (Kernel Page Table Isolation)

```bash
# 检查KPTI状态
dmesg | grep -i "page.*table.*isolation"

# 查看CPU漏洞缓解
cat /sys/devices/system/cpu/vulnerabilities/*
```

### UMIP (User Mode Instruction Prevention)

```bash
# 检查UMIP支持
grep " umip " /proc/cpuinfo

# UMIP防止用户空间执行SGDT, SIDT, SLDT, SMSW, STR指令
```

### 地址空间布局

```bash
# 用户空间ASLR
cat /proc/sys/kernel/randomize_va_space
# 0 = 禁用
# 1 = 部分随机化（栈、库、mmap）
# 2 = 完全随机化（包括堆）

# 设置完全随机化
sudo sysctl kernel.randomize_va_space=2
```

## 安全配置建议

### 最小安全基线

```bash
# 1. 启用KASLR
# 移除内核参数中的nokaslr

# 2. 保护内核指针
echo 2 | sudo tee /proc/sys/kernel/kptr_restrict

# 3. 限制dmesg访问
echo 1 | sudo tee /proc/sys/kernel/dmesg_restrict

# 4. 启用完全ASLR
echo 2 | sudo tee /proc/sys/kernel/randomize_va_space

# 5. 限制perf_event
echo 3 | sudo tee /proc/sys/kernel/perf_event_paranoid
```

### 内核编译选项

```bash
# 推荐的安全编译选项
CONFIG_RANDOMIZE_BASE=y
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_FORTIFY_SOURCE=y
CONFIG_VMAP_STACK=y
CONFIG_RANDOMIZE_KSTACK_OFFSET=y
CONFIG_CFI_CLANG=y  # 如果使用Clang
CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y
CONFIG_INIT_ON_FREE_DEFAULT_ON=y
CONFIG_PAGE_TABLE_ISOLATION=y
```

### 持久化配置

```bash
# /etc/sysctl.d/99-security.conf
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.randomize_va_space=2
kernel.perf_event_paranoid=3
kernel.yama.ptrace_scope=1
```

## 安全评估流程

### 1. 快速检查

```bash
# 一键检查所有安全特性
cd scripts
sudo ./test_kaslr.sh | grep "✓\|✗"
sudo ./test_smep_smap.sh | grep "✓\|✗"
sudo ./test_stack_protection.sh | grep "✓\|✗"
```

### 2. 详细审计

运行所有测试并查看详细报告：
```bash
for script in test_*.sh; do
    sudo ./$script
done
```

### 3. 漏洞扫描

```bash
# 检查已知漏洞缓解
cat /sys/devices/system/cpu/vulnerabilities/*

# 输出示例:
# Meltdown: Mitigation: PTI
# Spectre v1: Mitigation: usercopy/swapgs barriers
# Spectre v2: Mitigation: IBRS
```

## 常见问题排查

### KASLR未启用

**现象：** 内核符号地址固定

**原因：**
1. 内核参数有nokaslr
2. 内核未编译KASLR支持

**解决：**
```bash
# 检查并移除nokaslr
sudo vim /etc/default/grub
# 移除GRUB_CMDLINE_LINUX中的nokaslr
sudo update-grub
sudo reboot
```

### SMEP/SMAP不支持

**现象：** CPU flags中没有smep/smap

**原因：** CPU太旧

**解决：** 升级到：
- SMEP: Intel Ivy Bridge (2012+)
- SMAP: Intel Broadwell (2014+)

### 栈保护未启用

**现象：** 程序没有__stack_chk_fail符号

**原因：** 编译时未启用

**解决：**
```bash
# 编译时添加
gcc -fstack-protector-strong program.c

# 内核重新编译
CONFIG_STACKPROTECTOR_STRONG=y
```

## 攻击向量分析

### ROP (Return-Oriented Programming)

**防御层次：**
1. NX - 防止代码注入
2. ASLR/KASLR - 增加地址猜测难度
3. Stack Canary - 检测栈溢出
4. CFI/CET - 验证控制流
5. SMEP - 防止返回用户空间

### 信息泄漏

**防御措施：**
1. kptr_restrict - 隐藏内核指针
2. dmesg_restrict - 限制dmesg访问
3. KASLR - 随机化地址
4. SMAP - 防止内核读取用户数据

## 性能影响

| 特性 | 性能影响 | 说明 |
|------|---------|------|
| KASLR | <1% | 几乎无影响 |
| SMEP/SMAP | <1% | 硬件实现，开销极小 |
| Stack Canary | 1-3% | 增加函数序言/尾声 |
| CFI | 3-8% | 增加间接调用检查 |
| KPTI | 5-30% | 上下文切换开销（Meltdown缓解） |

## 参考资料

- [KASLR Documentation](https://lwn.net/Articles/569635/)
- [SMEP and SMAP](https://j00ru.vexillium.org/2011/06/smep-what-is-it-and-how-to-beat-it-on-linux/)
- [Stack Canaries](https://www.gnu.org/software/libc/manual/html_node/Cryptographic-Functions.html)
- [Intel CET](https://www.intel.com/content/www/us/en/developer/articles/technical/technical-look-control-flow-enforcement-technology.html)
- [Linux Kernel Self Protection](https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project)

---

**更新日期：** 2026-04-19
**版本：** 1.0
