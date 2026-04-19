# StressAppTest 内存稳定性测试

## 概述

StressAppTest (Stressful Application Test) 是Google开发的开源内存稳定性测试工具，专门用于检测内存硬件错误和系统稳定性问题。它通过大量并发内存读写操作，模拟极端负载场景，能够有效发现内存位翻转、数据损坏、温度相关故障等问题。

## 目录结构

```
stressapptest/
├── README.md                              # 本文件
├── INTERPRETATION_GUIDE.md                # 结果详细解读指南
├── scripts/
│   ├── test_stressapptest.sh              # 综合自动化测试（快速+标准+磁盘+热重启）
│   ├── stressapptest_long_duration.sh     # 长时间稳定性测试（24/72小时）
│   └── stressapptest_scenarios.sh         # 高级测试场景集合
└── results/                               # 测试结果目录
```

## StressAppTest测试原理

### 测试目的

StressAppTest用于：
- **内存硬件验证** - 检测内存条物理缺陷
- **系统稳定性测试** - 评估极端负载下的可靠性
- **超频配置验证** - 验证超频设置的稳定性
- **服务器验收测试** - 生产环境部署前的burn-in测试
- **故障诊断** - 隔离内存相关的系统问题

### 测试原理

#### 1. 内存填充测试
```
┌─────────────────────────────────────┐
│  分配大量内存（可达物理内存95%）      │
│  ↓                                   │
│  使用多种数据模式填充                 │
│  • 0xAAAAAAAAAAAAAAAA                │
│  • 0x5555555555555555                │
│  • 随机数据                          │
│  • 地址相关数据                      │
│  ↓                                   │
│  持续读写验证数据完整性               │
└─────────────────────────────────────┘
```

#### 2. 多线程并发压力
```
CPU核心1  ─┬─> 内存区域1 ────┐
CPU核心2  ─┼─> 内存区域2 ────┤
CPU核心3  ─┼─> 内存区域3 ────┼─> 内存总线竞争
CPU核心4  ─┼─> 内存区域4 ────┤
...       ─┴─> ...      ────┘

检测:
  • 内存总线竞争问题
  • 多核并发访问错误
  • 缓存一致性问题
```

#### 3. 数据完整性检查
```
写入阶段:
  for each block:
    pattern = generate_pattern(block_id)
    memory[block] = pattern

验证阶段:
  for each block:
    expected = generate_pattern(block_id)
    actual = memory[block]
    if actual != expected:
      ERROR: Data mismatch at block_id

检测:
  • 位翻转 (bit flip)
  • 数据损坏 (corruption)
  • 地址错位 (address error)
```

#### 4. 温度压力测试
```
高强度计算 → 产生大量热量 → 温度升高

检测:
  • 温度相关的内存错误
  • 散热系统有效性
  • 热稳定性问题

典型温度曲线:

温度(°C)
  90┤          ╭───────
  80┤      ╭───╯
  70┤  ╭───╯
  60┤──╯
    └──────────────────> 时间
       启动   稳定   结束
```

### 检测的错误类型

#### A. 位翻转（Bit Flip）
```
期望值: 0xDEADBEEF12345678
实际值: 0xDEADBEEF12345679
           ┗━━━━━━━━━━━━━┛
           最后1位翻转
```
**原因:**
- 内存单元物理损坏
- 宇宙射线（SEU - Single Event Upset）
- 电压不稳定
- 温度过高

#### B. 行锤攻击（Rowhammer Effect）
```
正常行:  [数据正常] [数据正常] [数据正常]
被攻击行:             ↓
                [数据损坏] ← 相邻行数据翻转
被攻击行:             ↓
正常行:  [数据正常] [数据正常] [数据正常]
```
**原因:**
- 内存芯片制程过小（<20nm）
- 高频访问某行导致邻行电荷泄漏
- DDR4及更新内存的物理特性

#### C. 地址错误（Address Error）
```
写入地址: 0x1000
读取地址: 0x1000
实际地址: 0x2000  ← 地址解码错误
```
**原因:**
- 内存控制器故障
- 地址总线问题
- 主板缺陷

#### D. 整字节失效
```
期望值: 0xDEADBEEF12345678
实际值: 0xDEADBEEF00000000
           ┗━━━━━━━━━┛
           整个字节为0
```
**原因:**
- 内存芯片完全失效
- 焊接问题
- 严重物理损坏

## 前置条件

### 系统要求

- Linux/Unix操作系统
- gcc编译器（源码编译时需要）
- 足够的可用内存（建议至少50%空闲）
- root权限（某些场景需要）

### 安装StressAppTest

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install stressapptest
```

**RHEL/CentOS:**
```bash
sudo yum install epel-release
sudo yum install stressapptest
```

**Fedora:**
```bash
sudo dnf install stressapptest
```

**macOS:**
```bash
brew install stressapptest
```

**源码编译:**
```bash
git clone https://github.com/stressapptest/stressapptest.git
cd stressapptest
./configure
make
sudo make install
```

### 验证安装

```bash
stressapptest --version
# 输出类似: stressapptest 1.0.9
```

## 运行测试

### 快速开始（推荐）

```bash
cd scripts
./test_stressapptest.sh
```

脚本会自动运行4种测试：
1. 快速内存测试（5分钟）
2. 标准内存测试（1小时）
3. 磁盘+内存压力测试（10分钟）
4. 热重启压力测试（5次×3分钟）

### 长时间稳定性测试

**72小时验收测试（推荐用于新服务器）:**
```bash
./stressapptest_long_duration.sh 72
```

**24小时深度测试:**
```bash
./stressapptest_long_duration.sh 24
```

**自定义时长:**
```bash
./stressapptest_long_duration.sh [小时数] [内存使用百分比]
# 示例: 48小时，使用85%内存
./stressapptest_long_duration.sh 48 85
```

### 高级测试场景

```bash
./stressapptest_scenarios.sh
```

**可选场景:**
1. 新服务器验收测试（72小时）
2. 内存超频稳定性验证（24小时）
3. 虚拟机内存压力测试（1小时）
4. 与温度监控联动测试（24小时）
5. 数据中心批量验证（6小时）
6. ECC内存纠错能力测试（12小时）

### 手动运行示例

**基础测试（1小时，使用90%内存）:**
```bash
stressapptest -s 3600 -M 90 -m $(nproc) -W
```

**极限压力测试（使用100%内存）:**
```bash
stressapptest -s 7200 -M 100 -m $(($(nproc) * 2)) -W -C 64
```

**磁盘+内存联合测试:**
```bash
stressapptest -s 3600 -M 85 -m $(nproc) -W -d /tmp/stressapptest_disk
```

**带暂停检查的长时间测试:**
```bash
stressapptest -s 86400 -M 95 -m $(nproc) -W \
    --pause_duration 10 --pause_delay 300
```

## 关键参数说明

### 必需参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-s <秒>` | 测试时长 | `-s 3600` (1小时) |
| `-M <百分比>` | 内存使用百分比 | `-M 90` (90%内存) |

### 常用可选参数

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `-m <数量>` | 线程数 | `$(nproc)` (所有CPU核心) |
| `-W` | 启用更严格的内存检查 | 推荐总是使用 |
| `-C <MB>` | 内存复制块大小 | `64` 或 `128` |
| `-d <路径>` | 使用磁盘文件增加压力 | `/tmp/stress_disk` |
| `-l <文件>` | 输出详细日志 | `stress_test.log` |

### 高级参数

| 参数 | 说明 | 使用场景 |
|------|------|---------|
| `--pause_duration <秒>` | 暂停检查持续时间 | 防止过热 |
| `--pause_delay <秒>` | 暂停间隔 | 长时间测试 |
| `--stop_on_errors` | 发现错误立即停止 | 快速失败检测 |
| `--max_errors <数量>` | 最大错误数后停止 | 限制错误记录 |

## 测试时长建议

### 快速验证（开发/测试环境）
```bash
# 5分钟快速检测
stressapptest -s 300 -M 80 -m $(nproc) -W
```
- 时长: 5分钟
- 检出率: ~40%
- 适用: 日常开发、快速验证

### 标准测试（日常检查）
```bash
# 1小时标准测试
stressapptest -s 3600 -M 90 -m $(nproc) -W
```
- 时长: 1小时
- 检出率: ~75%
- 适用: 系统维护、定期检查

### 深度测试（超频验证）
```bash
# 24小时深度测试
stressapptest -s 86400 -M 95 -m $(nproc) -W -C 64
```
- 时长: 24小时
- 检出率: ~95%
- 适用: 超频稳定性、疑难问题排查

### 验收测试（生产环境）
```bash
# 72小时burn-in测试
stressapptest -s 259200 -M 95 -m $(nproc) -W \
    --pause_duration 60 --pause_delay 600
```
- 时长: 72小时
- 检出率: ~99%
- 适用: 新服务器验收、关键系统

## 结果解读

### 成功的测试

```
Status: PASS - 3600/3600s
Stats: Found 0 hardware incidents
Stats: Found 0 data mismatches
Result: PASS
```

**结论:**
- ✓ 内存系统稳定
- ✓ 无硬件错误
- ✓ 可投入生产使用

### 失败的测试

```
Status: FAIL - 1297/3600s
Stats: Found 47 hardware incidents
Stats: Found 47 data mismatches
Result: FAIL
```

**结论:**
- ✗ 内存存在硬件问题
- ✗ 需要诊断和修复
- ✗ 不可用于生产环境

### 详细解读

查看完整的结果解读指南：
```bash
cat INTERPRETATION_GUIDE.md
```

或运行自动分析：
```bash
./scripts/test_stressapptest.sh
# 测试完成后会自动生成详细报告
```

## 典型测试场景

### 场景1: 新服务器验收（72小时Burn-in）

**目的:** 硬件出厂质量验证

**测试步骤:**
```bash
# 1. 运行72小时全面测试
./stressapptest_long_duration.sh 72 95

# 2. 同时监控温度
watch -n 60 sensors

# 3. 记录测试过程
# 检查CPU温度、风扇转速、系统日志
```

**通过标准:**
- ✓ 零错误
- ✓ 温度稳定在安全范围（<85°C）
- ✓ 无系统崩溃或重启
- ✓ 无异常噪音或气味

### 场景2: 内存超频稳定性验证

**目的:** 验证超频设置可靠性

**测试步骤:**
```bash
# 1. 记录超频配置
# 频率: _____ MHz
# 电压: _____ V
# 时序: CL___-___-___-___

# 2. 运行24小时压力测试
stressapptest -s 86400 -M 100 -m $(($(nproc) * 2)) -W -C 64

# 3. 监控温度（必须）
watch -n 10 'sensors | grep -E "Core|Package"'
```

**调优流程:**
```
初始配置 → 测试24h
    ↓
  失败? ────yes──→ 降频100MHz 或 加压0.05V
    ↓                    ↓
   no                   重新测试
    ↓                    ↓
  成功 ←──────────────pass
    ↓
最终验证72h
```

### 场景3: 数据中心批量验证

**目的:** 快速批量检测硬件缺陷

**测试步骤:**
```bash
# 创建批量测试脚本
cat > batch_test.sh <<'EOF'
#!/bin/bash
HOSTNAME=$(hostname)
LOG_DIR="/var/log/memtest"
mkdir -p $LOG_DIR

stressapptest -s 21600 -M 95 -m $(nproc) -W \
    -l "${LOG_DIR}/${HOSTNAME}_$(date +%Y%m%d).log"

RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "$HOSTNAME: PASS" >> /var/log/batch_results.txt
else
    echo "$HOSTNAME: FAIL" >> /var/log/batch_results.txt
    # 发送告警
    mail -s "Memory Test FAILED: $HOSTNAME" admin@example.com
fi
EOF

# 在多台服务器上并行运行
parallel-ssh -h servers.txt -i 'bash -s' < batch_test.sh
```

### 场景4: 虚拟机内存测试（带cgroup限制）

**目的:** 测试虚拟机内存稳定性

**测试步骤:**
```bash
# 1. 创建cgroup限制（如果可用）
if [ $(id -u) -eq 0 ] && [ -d /sys/fs/cgroup/memory ]; then
    # 限制2GB内存
    mkdir -p /sys/fs/cgroup/memory/vm_test
    echo $((2 * 1024 * 1024 * 1024)) > \
        /sys/fs/cgroup/memory/vm_test/memory.limit_in_bytes

    # 运行测试
    cgexec -g memory:vm_test \
        stressapptest -s 3600 -M 80 -m 4 -W
else
    # 无cgroup，标准测试
    stressapptest -s 3600 -M 80 -m 4 -W
fi
```

### 场景5: ECC内存纠错能力测试

**目的:** 评估ECC内存纠错效果

**测试步骤:**
```bash
# 1. 记录测试前ECC计数
if [ -f /sys/devices/system/edac/mc/mc0/ce_count ]; then
    CE_BEFORE=$(cat /sys/devices/system/edac/mc/mc0/ce_count)
    UE_BEFORE=$(cat /sys/devices/system/edac/mc/mc0/ue_count)
    echo "测试前: CE=$CE_BEFORE, UE=$UE_BEFORE"
fi

# 2. 运行12小时测试
stressapptest -s 43200 -M 90 -m $(nproc) -W -C 128

# 3. 记录测试后ECC计数
if [ -f /sys/devices/system/edac/mc/mc0/ce_count ]; then
    CE_AFTER=$(cat /sys/devices/system/edac/mc/mc0/ce_count)
    UE_AFTER=$(cat /sys/devices/system/edac/mc/mc0/ue_count)

    CE_DIFF=$((CE_AFTER - CE_BEFORE))
    UE_DIFF=$((UE_AFTER - UE_BEFORE))

    echo "测试后: CE=$CE_AFTER, UE=$UE_AFTER"
    echo "新增纠正错误: $CE_DIFF"
    echo "新增未纠正错误: $UE_DIFF"

    # 评估
    if [ $UE_DIFF -gt 0 ]; then
        echo "✗ 警告: 检测到未纠正错误，内存有严重问题"
    elif [ $CE_DIFF -gt 100 ]; then
        echo "⚠ 注意: 纠正错误较多，建议更换内存"
    elif [ $CE_DIFF -gt 0 ]; then
        echo "✓ 良好: ECC成功纠正少量错误"
    else
        echo "✓ 完美: 无错误检测"
    fi
fi
```

## 故障诊断

### 诊断流程

```
测试失败
    ↓
┌─────────────────┐
│ 1. 重新测试验证  │
└────────┬────────┘
         ↓
    再次失败?
         ↓ yes
┌─────────────────┐
│ 2. 逐条测试内存  │ ← 隔离故障内存条
└────────┬────────┘
         ↓
    找到故障条?
         ↓ yes
┌─────────────────┐
│ 3. 检查系统配置  │
│ • BIOS设置      │
│ • 内存频率/电压  │
│ • 温度          │
└────────┬────────┘
         ↓
┌─────────────────┐
│ 4. 交叉验证      │
│ • Memtest86+    │
│ • memtester     │
└────────┬────────┘
         ↓
┌─────────────────┐
│ 5. 更换/RMA     │
└─────────────────┘
```

### 隔离故障内存条

```bash
# 多内存条系统的测试脚本
#!/bin/bash

echo "开始逐条内存测试"
echo "请按提示移除/插入内存条"
echo ""

for slot in {1..4}; do
    read -p "请插入第${slot}条内存，按Enter继续..."

    echo "测试第${slot}条内存（30分钟）..."
    stressapptest -s 1800 -M 90 -m $(nproc) -W \
        -l "memtest_slot${slot}.log"

    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "✓ 第${slot}条内存: PASS"
    else
        echo "✗ 第${slot}条内存: FAIL - 故障内存"
        echo "故障内存位于插槽${slot}"
    fi
    echo ""
done
```

### 检查清单

**硬件检查:**
```
□ 内存条是否插紧
□ 金手指是否清洁
□ 插槽是否有灰尘
□ 主板是否有明显损坏
□ CPU散热器是否正常工作
□ 机箱通风是否良好
```

**BIOS设置检查:**
```
□ 内存频率是否正确: _____ MHz (规格: _____ MHz)
□ 内存电压是否正确: _____ V (规格: _____ V)
□ XMP/DOCP: □ 启用 □ 禁用
□ ECC功能: □ 启用 □ 禁用 (如果支持)
□ 内存时序: CL___-___-___-___
```

**系统检查:**
```bash
# 检查系统日志
sudo dmesg | grep -i "memory\|ecc\|edac"
sudo journalctl -b | grep -i "memory\|ecc"

# 检查温度
sensors

# 检查ECC状态
sudo dmidecode -t memory | grep -E "Error Correction|Total Width"

# 检查内存信息
sudo dmidecode -t memory
```

## 性能优化建议

### 测试环境优化

**1. 关闭不必要的服务**
```bash
# 停止不必要的服务以减少内存竞争
systemctl stop docker
systemctl stop mysql
# ...其他服务
```

**2. 禁用swap（可选）**
```bash
# 测试物理内存，避免swap干扰
sudo swapoff -a
# 测试完成后恢复
sudo swapon -a
```

**3. 设置CPU性能模式**
```bash
# 防止CPU降频影响测试
sudo cpupower frequency-set -g performance
```

### 内存配置优化

**检查内存配置:**
```bash
# 检查内存通道配置
sudo dmidecode -t memory | grep -E "Number Of Devices|Locator"

# 最佳配置:
# 双通道: 2条或4条对称安装
# 四通道: 4条或8条对称安装
```

**优化建议:**
- 使用相同品牌、型号、容量的内存条
- 对称安装在相应插槽
- 避免混用不同频率的内存

## 常见问题

### Q1: 测试会损坏硬件吗？

**A:** 不会。StressAppTest只是读写内存，不会对硬件造成永久性损坏。但会产生大量热量，需要确保散热良好。

### Q2: 测试可以中断吗？

**A:** 可以。按Ctrl+C中断测试。但已完成的测试无法提供完整的稳定性评估。

### Q3: 虚拟机中测试准确吗？

**A:** 相对准确，但可能遗漏物理硬件特有的问题。推荐在物理机上运行完整测试。

### Q4: 多久应该测试一次？

**A:**
- 新硬件: 72小时验收测试
- 生产系统: 每季度6小时测试
- 超频系统: 每月24小时测试
- 故障排查: 随时按需测试

### Q5: 测试失败一定是内存问题吗？

**A:** 不一定。可能原因：
- 内存条故障（最常见）
- 主板插槽问题
- 内存控制器故障
- 电源供电不稳
- 温度过高
- 超频设置不当

## 参考资料

- [StressAppTest GitHub仓库](https://github.com/stressapptest/stressapptest)
- [Google开源项目页面](https://code.google.com/archive/p/stressapptest/)
- [ECC内存错误检测](https://www.kernel.org/doc/html/latest/admin-guide/ras.html)
- [内存测试最佳实践](https://www.memtest.org/)

---

**更新日期:** 2026-04-19
**版本:** 1.0
