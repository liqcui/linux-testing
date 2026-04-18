#!/bin/bash
# mem_test 虚拟机环境测试脚本
# 在虚拟机中，perf mem 通常不可用，使用替代方案

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         虚拟机环境内存性能测试                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查是否已编译
if [ ! -f mem_test ]; then
    echo "编译 mem_test..."
    make
    echo ""
fi

echo "========================================="
echo "环境检测"
echo "========================================="
echo ""

echo "虚拟化检测:"
if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt
else
    cat /proc/cpuinfo | grep -i hypervisor && echo "检测到虚拟化" || echo "可能是物理机"
fi
echo ""

echo "检查 perf mem 支持:"
if perf mem record --help >/dev/null 2>&1; then
    echo "✓ perf mem 命令存在"
    if perf list | grep -i "mem-loads\|mem-stores" >/dev/null 2>&1; then
        echo "✓ 内存采样事件可用"
    else
        echo "✗ 内存采样事件不可用（需要硬件 PEBS/IBS）"
    fi
else
    echo "✗ perf mem 命令不支持"
fi
echo ""

echo "检查硬件缓存事件:"
if perf list | grep -q "cache-references"; then
    echo "✓ 硬件缓存事件可用"
    USE_HW_EVENTS=1
else
    echo "✗ 硬件缓存事件不可用（虚拟机限制）"
    USE_HW_EVENTS=0
fi
echo ""

echo "========================================="
echo "1. 基本性能测试（程序自身输出）"
echo "========================================="
echo ""

echo "这是虚拟机环境中最可靠的分析方法！"
echo ""

./mem_test

echo ""
echo "========================================="
echo "2. 性能对比分析"
echo "========================================="
echo ""

echo "对比不同访问模式的性能差异:"
echo ""

echo "测试1: 顺序读 vs 随机读"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SEQUENTIAL=$(./mem_test -t 1 -s 64 -n 5 2>&1 | grep "顺序读" | awk '{print $NF, $(NF-1)}')
RANDOM=$(./mem_test -t 3 -s 64 -n 5 2>&1 | grep "随机读" | awk '{print $NF, $(NF-1)}')
echo "顺序读: $SEQUENTIAL"
echo "随机读: $RANDOM"
echo "说明: 顺序读应该比随机读快 10-20 倍"
echo ""

echo "测试2: 顺序写 vs 随机写"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SEQ_WRITE=$(./mem_test -t 2 -s 64 -n 5 2>&1 | grep "顺序写" | awk '{print $NF, $(NF-1)}')
RAND_WRITE=$(./mem_test -t 4 -s 64 -n 5 2>&1 | grep "随机写" | awk '{print $NF, $(NF-1)}')
echo "顺序写: $SEQ_WRITE"
echo "随机写: $RAND_WRITE"
echo "说明: 顺序写应该比随机写快 5-15 倍"
echo ""

echo "测试3: 伪共享 vs 无伪共享"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
FALSE_SHARING=$(./mem_test -t 6 -p 8 2>&1 | grep "伪共享" | awk '{print $NF, $(NF-1)}')
NO_SHARING=$(./mem_test -t 7 -p 8 2>&1 | grep "无伪共享" | awk '{print $NF, $(NF-1)}')
echo "伪共享: $FALSE_SHARING"
echo "无伪共享: $NO_SHARING"
echo "说明: 无伪共享应该比伪共享快 2-10 倍"
echo ""

echo "========================================="
echo "3. 使用 perf stat 分析"
echo "========================================="
echo ""

if [ $USE_HW_EVENTS -eq 1 ]; then
    echo "使用硬件缓存事件:"
    echo ""

    echo "顺序读（缓存友好）:"
    perf stat -e cache-references,cache-misses,LLC-loads,LLC-load-misses \
        ./mem_test -t 1 -s 64 -n 5 2>&1 | grep -A 8 "Performance counter"
    echo ""

    echo "随机读（缓存不友好）:"
    perf stat -e cache-references,cache-misses,LLC-loads,LLC-load-misses \
        ./mem_test -t 3 -s 64 -n 5 2>&1 | grep -A 8 "Performance counter"
    echo ""

    echo "分析: 随机读的 cache-misses 应该远高于顺序读"
else
    echo "使用软件事件（硬件事件不可用）:"
    echo ""

    echo "顺序读:"
    perf stat -e cpu-clock,task-clock,page-faults,minor-faults,major-faults \
        ./mem_test -t 1 -s 64 -n 5 2>&1 | grep -A 8 "Performance counter"
    echo ""

    echo "随机读:"
    perf stat -e cpu-clock,task-clock,page-faults,minor-faults,major-faults \
        ./mem_test -t 3 -s 64 -n 5 2>&1 | grep -A 8 "Performance counter"
    echo ""
fi

echo "========================================="
echo "4. 测试不同缓冲区大小"
echo "========================================="
echo ""

echo "测试缓冲区大小对性能的影响:"
echo ""

for size in 1 8 64 256; do
    result=$(./mem_test -t 1 -s $size -n 3 2>&1 | grep "顺序读" | awk '{print $NF, $(NF-1)}')
    echo "${size} MB 缓冲区: $result"
done

echo ""
echo "说明:"
echo "- 小缓冲区（< 8 MB）: 可能完全在 L3 缓存中，速度最快"
echo "- 中缓冲区（8-64 MB）: 部分在缓存中，性能下降"
echo "- 大缓冲区（> 64 MB）: 主要访问主内存，速度较慢"
echo ""

echo "========================================="
echo "5. 使用 time 命令对比"
echo "========================================="
echo ""

echo "对比执行时间（简单但有效）:"
echo ""

echo "顺序读:"
time ./mem_test -t 1 -s 128 -n 5 2>&1 | grep "顺序读"
echo ""

echo "随机读:"
time ./mem_test -t 3 -s 128 -n 5 2>&1 | grep "随机读"
echo ""

echo "========================================="
echo "总结和建议"
echo "========================================="
echo ""

echo "虚拟机环境限制:"
echo "✗ perf mem 不可用（需要硬件 PEBS/IBS）"
echo "✗ 硬件缓存事件可能不可用"
echo "✗ 无法获取精确的缓存命中/未命中数据"
echo ""

echo "可用的分析方法:"
echo "✓ 程序自身的带宽测试（最可靠）"
echo "✓ 性能对比（顺序 vs 随机，伪共享 vs 无伪共享）"
echo "✓ perf stat 软件事件（CPU 时间、页错误等）"
echo "✓ time 命令对比执行时间"
echo ""

echo "关键发现（从程序输出）:"
echo "1. 顺序访问 vs 随机访问的速度差异"
echo "2. 伪共享的性能影响"
echo "3. 缓冲区大小对性能的影响"
echo ""

echo "这些数据足以说明内存访问模式的性能差异！"
echo ""

echo "========================================="
echo "完成！"
echo "========================================="
