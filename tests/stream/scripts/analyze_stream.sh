#!/bin/bash
# analyze_stream.sh - STREAM结果详细解读

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${1:-$SCRIPT_DIR/../results}"

# 如果没有提供结果目录，查找最新的
if [[ ! -d "$RESULTS_DIR" ]] || [[ "$RESULTS_DIR" == "$SCRIPT_DIR/../results" ]]; then
    LATEST=$(ls -td $SCRIPT_DIR/../results/stream-advanced-* 2>/dev/null | head -1)
    if [[ -z "$LATEST" ]]; then
        LATEST=$(ls -td $SCRIPT_DIR/../results/stream-* 2>/dev/null | head -1)
    fi
    if [[ -n "$LATEST" ]]; then
        RESULTS_DIR="$LATEST"
    else
        echo "错误: 未找到测试结果目录"
        exit 1
    fi
fi

ANALYSIS_FILE="$RESULTS_DIR/detailed_analysis.txt"

echo "========================================"
echo "STREAM 结果详细解读"
echo "========================================"
echo ""
echo "分析目录: $RESULTS_DIR"
echo "生成文件: $ANALYSIS_FILE"
echo ""

{
    echo "STREAM测试结果详细解读"
    echo "========================================"
    echo ""
    echo "分析时间: $(date)"
    echo "结果目录: $RESULTS_DIR"
    echo ""

    # ========== 典型输出示例 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. STREAM典型输出示例及解读"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【典型输出格式】"
    echo "----------------------------------------"
    echo ""
    cat <<'EXAMPLE'
-------------------------------------------------------------
STREAM version $Revision: 5.10 $
-------------------------------------------------------------
This system uses 8 bytes per array element.
-------------------------------------------------------------
Array size = 200000000 (elements), Offset = 0 (elements)
Memory per array = 1525.9 MiB (= 1.5 GiB).
Total memory required = 4577.6 MiB (= 4.5 GiB).
Each kernel will be executed 10 times.
 The *best* time for each kernel (excluding the first iteration)
 will be used to compute the reported bandwidth.
-------------------------------------------------------------
Number of Threads requested = 16
Number of Threads counted = 16
-------------------------------------------------------------
Your clock granularity/precision appears to be 1 microseconds.
Each test below will take on the order of 52473 microseconds.
   (= 52473 clock ticks)
Increase the size of the arrays if this shows that
you are not getting at least 20 clock ticks per test.
-------------------------------------------------------------
WARNING -- The above is only a rough guideline.
For best results, please be sure you know the
precision of your system timer.
-------------------------------------------------------------
Function    Best Rate MB/s  Avg time     Min time     Max time
Copy:           42156.8     0.060789     0.060732     0.060845    ← 解读A
Scale:          35842.1     0.071534     0.071428     0.071698    ← 解读B
Add:            38945.7     0.098765     0.098654     0.098876    ← 解读C
Triad:          39128.5     0.098234     0.098123     0.098456    ← 解读D
-------------------------------------------------------------
Solution Validates: avg error less than 1.000000e-13 on all three arrays
-------------------------------------------------------------

解读A - Copy: 42156.8 MB/s
  操作: a[i] = b[i]
  内存访问: 1读 + 1写 = 2次/元素
  实际带宽: 42156.8 MB/s
  意义: 纯内存复制性能，无计算开销

解读B - Scale: 35842.1 MB/s
  操作: a[i] = q * b[i]
  内存访问: 1读 + 1写 = 2次/元素
  实际带宽: 35842.1 MB/s
  意义: 内存+简单浮点乘法
  注意: 低于Copy是因为FPU运算开销

解读C - Add: 38945.7 MB/s
  操作: a[i] = b[i] + c[i]
  内存访问: 2读 + 1写 = 3次/元素
  实际带宽: 38945.7 MB/s
  意义: 多数组读取性能
  注意: 带宽=数据传输量/时间，3个数组访问

解读D - Triad: 39128.5 MB/s  ← 最重要的指标
  操作: a[i] = b[i] + q * c[i]
  内存访问: 2读 + 1写 = 3次/元素
  实际带宽: 39128.5 MB/s
  意义: 综合性能，最接近实际应用
  重要性: ★★★★★ (通常用作主要参考指标)
EXAMPLE

    echo ""
    echo ""

    # ========== 性能等级划分 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "2. 性能等级划分 (Triad带宽)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【单通道DDR4内存】"
    echo "----------------------------------------"
    echo ""
    echo "内存类型          理论峰值      实际可达      性能等级"
    echo "------------      --------      --------      --------"
    echo "DDR4-2133         17.1 GB/s     10-14 GB/s    入门级"
    echo "DDR4-2400         19.2 GB/s     12-16 GB/s    入门级"
    echo "DDR4-2666         21.3 GB/s     13-17 GB/s    一般"
    echo "DDR4-3200         25.6 GB/s     15-20 GB/s    良好"
    echo "DDR4-3600         28.8 GB/s     17-23 GB/s    优秀"
    echo "DDR4-4000         32.0 GB/s     19-26 GB/s    卓越"
    echo ""
    echo "注: 实际可达 = 理论峰值 × 60-80%"
    echo ""

    echo "【双通道DDR4内存】"
    echo "----------------------------------------"
    echo ""
    echo "内存类型          理论峰值      实际可达      性能等级"
    echo "------------      --------      --------      --------"
    echo "DDR4-2133 双通道  34.2 GB/s     20-28 GB/s    一般"
    echo "DDR4-2400 双通道  38.4 GB/s     23-31 GB/s    良好"
    echo "DDR4-2666 双通道  42.6 GB/s     26-34 GB/s    良好"
    echo "DDR4-3200 双通道  51.2 GB/s     31-41 GB/s    优秀  ← 主流配置"
    echo "DDR4-3600 双通道  57.6 GB/s     35-46 GB/s    卓越"
    echo ""

    echo "【四通道/多通道服务器内存】"
    echo "----------------------------------------"
    echo ""
    echo "内存配置          理论峰值      实际可达      应用场景"
    echo "------------      --------      --------      --------"
    echo "DDR4-2666 四通道  85.2 GB/s     51-68 GB/s    主流服务器"
    echo "DDR4-3200 四通道  102.4 GB/s    61-82 GB/s    高性能服务器"
    echo "DDR4-2933 六通道  140.8 GB/s    85-113 GB/s   工作站/服务器"
    echo "DDR4-2933 八通道  187.7 GB/s    113-150 GB/s  高端服务器"
    echo ""

    echo "【DDR5内存 (新一代)】"
    echo "----------------------------------------"
    echo ""
    echo "内存类型          理论峰值      实际可达"
    echo "------------      --------      --------"
    echo "DDR5-4800 单通道  38.4 GB/s     23-31 GB/s"
    echo "DDR5-4800 双通道  76.8 GB/s     46-61 GB/s"
    echo "DDR5-5600 双通道  89.6 GB/s     54-72 GB/s"
    echo "DDR5-6400 双通道  102.4 GB/s    61-82 GB/s"
    echo ""

    echo "【性能评级标准 (双通道消费级)】"
    echo "----------------------------------------"
    echo ""
    echo "Triad带宽         评级          等级          典型配置"
    echo "---------         ----          ----          --------"
    echo "< 20 GB/s         ★☆☆☆☆        入门级        单通道或低频"
    echo "20-30 GB/s        ★★☆☆☆        一般          双通道DDR4-2400"
    echo "30-40 GB/s        ★★★☆☆        良好          双通道DDR4-3200"
    echo "40-50 GB/s        ★★★★☆        优秀          双通道DDR4-3600+"
    echo "> 50 GB/s         ★★★★★        卓越          四通道或DDR5"
    echo ""

    # ========== 实际测试结果分析 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "3. 实际测试结果分析"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 查找并分析结果
    if [[ -f "$RESULTS_DIR/stream_single_thread.txt" ]]; then
        echo "【单线程测试结果】"
        echo "----------------------------------------"
        echo ""

        copy=$(grep "^Copy:" "$RESULTS_DIR/stream_single_thread.txt" | awk '{print $2}')
        scale=$(grep "^Scale:" "$RESULTS_DIR/stream_single_thread.txt" | awk '{print $2}')
        add=$(grep "^Add:" "$RESULTS_DIR/stream_single_thread.txt" | awk '{print $2}')
        triad=$(grep "^Triad:" "$RESULTS_DIR/stream_single_thread.txt" | awk '{print $2}')

        echo "Copy:   $copy MB/s"
        echo "Scale:  $scale MB/s"
        echo "Add:    $add MB/s"
        echo "Triad:  $triad MB/s  ← 关键指标"
        echo ""

        # 性能评级
        if [[ -n "$triad" ]]; then
            triad_gb=$(echo "scale=1; $triad / 1024" | bc)
            echo "Triad带宽: ${triad_gb} GB/s"

            if (( $(echo "$triad > 50000" | bc -l) )); then
                echo "性能评级: ★★★★★ 卓越"
            elif (( $(echo "$triad > 40000" | bc -l) )); then
                echo "性能评级: ★★★★☆ 优秀"
            elif (( $(echo "$triad > 30000" | bc -l) )); then
                echo "性能评级: ★★★☆☆ 良好"
            elif (( $(echo "$triad > 20000" | bc -l) )); then
                echo "性能评级: ★★☆☆☆ 一般"
            else
                echo "性能评级: ★☆☆☆☆ 入门级"
            fi
            echo ""
        fi
    fi

    # 多线程结果分析
    if [[ -f "$RESULTS_DIR/multithread_results.txt" ]]; then
        echo "【多线程测试结果】"
        echo "----------------------------------------"
        echo ""
        cat "$RESULTS_DIR/multithread_results.txt"
        echo ""

        # 扩展性分析
        echo "扩展性分析:"
        echo ""

        # 读取1线程和最大线程的结果
        thread_1_file="$RESULTS_DIR/stream_1threads.txt"
        if [[ -f "$thread_1_file" ]]; then
            baseline=$(grep "^Triad:" "$thread_1_file" | awk '{print $2}')

            # 找最大线程数
            max_threads=0
            for f in "$RESULTS_DIR"/stream_*threads.txt; do
                if [[ -f "$f" ]]; then
                    n=$(basename "$f" | sed 's/stream_\([0-9]*\)threads.txt/\1/')
                    if [[ $n -gt $max_threads ]]; then
                        max_threads=$n
                    fi
                fi
            done

            if [[ $max_threads -gt 1 ]]; then
                max_file="$RESULTS_DIR/stream_${max_threads}threads.txt"
                max_triad=$(grep "^Triad:" "$max_file" | awk '{print $2}')

                speedup=$(echo "scale=2; $max_triad / $baseline" | bc)
                efficiency=$(echo "scale=1; ($speedup / $max_threads) * 100" | bc)

                echo "基准(1线程): $baseline MB/s"
                echo "最大($max_threads线程): $max_triad MB/s"
                echo "加速比: ${speedup}x"
                echo "并行效率: ${efficiency}%"
                echo ""

                if (( $(echo "$efficiency > 80" | bc -l) )); then
                    echo "✓ 优秀的并行扩展性"
                elif (( $(echo "$efficiency > 60" | bc -l) )); then
                    echo "✓ 良好的并行扩展性"
                elif (( $(echo "$efficiency > 40" | bc -l) )); then
                    echo "⚠ 一般的并行扩展性"
                else
                    echo "⚠ 较差的并行扩展性"
                fi
                echo ""
            fi
        fi
    fi

    # NUMA结果分析
    if [[ -f "$RESULTS_DIR/numa_results.txt" ]]; then
        echo "【NUMA测试结果】"
        echo "----------------------------------------"
        echo ""
        cat "$RESULTS_DIR/numa_results.txt"
        echo ""
    fi

    # ========== 四个操作详细对比 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "4. 四个操作详细对比分析"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【操作对比表】"
    echo "----------------------------------------"
    echo ""
    echo "操作    公式                数组数  内存访问  计算  典型比值"
    echo "----    ------------------  ------  --------  ----  --------"
    echo "Copy    a[i] = b[i]         2个     2次/元素  无    1.00"
    echo "Scale   a[i] = q * b[i]     2个     2次/元素  1乘   0.85-0.95"
    echo "Add     a[i] = b[i] + c[i]  3个     3次/元素  1加   0.90-1.00"
    echo "Triad   a[i] = b[i]+q*c[i]  3个     3次/元素  1乘1加 0.90-1.00"
    echo ""

    echo "【为什么Triad最重要？】"
    echo "----------------------------------------"
    echo ""
    echo "1. 最接近实际应用"
    echo "   - 同时涉及多个数组（真实程序常见）"
    echo "   - 包含计算和内存访问（而非纯内存复制）"
    echo "   - 测试内存-CPU协同性能"
    echo ""
    echo "2. 综合性指标"
    echo "   - 3个数组 = 测试多数据流处理能力"
    echo "   - 乘法+加法 = 测试FPU和内存并行"
    echo "   - 最能反映系统瓶颈"
    echo ""
    echo "3. 业界标准"
    echo "   - 论文和报告通常只引用Triad"
    echo "   - 硬件厂商也以Triad作为参考"
    echo ""

    echo "【性能比值分析】"
    echo "----------------------------------------"
    echo ""
    echo "如果测试结果:"
    echo "  Copy:  42.0 GB/s"
    echo "  Scale: 35.8 GB/s  (Scale/Copy = 0.85)"
    echo "  Add:   38.9 GB/s  (Add/Copy = 0.93)"
    echo "  Triad: 39.1 GB/s  (Triad/Copy = 0.93)"
    echo ""
    echo "分析:"
    echo "  ✓ Scale低于Copy是正常的"
    echo "    → FPU乘法运算有一定开销"
    echo ""
    echo "  ✓ Add和Triad接近Copy"
    echo "    → 3次内存访问vs2次，但总带宽相近"
    echo "    → 说明内存控制器可以并行处理多个数据流"
    echo ""
    echo "  ⚠️ 如果Triad < Copy × 0.7"
    echo "    → 可能存在瓶颈（内存通道不足、NUMA问题等）"
    echo ""

    # ========== 瓶颈识别 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "5. 性能瓶颈识别"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【症状1: 带宽远低于预期】"
    echo "----------------------------------------"
    echo ""
    echo "预期: DDR4-3200双通道应达到 30-40 GB/s"
    echo "实际: 仅 15 GB/s"
    echo ""
    echo "可能原因:"
    echo "  1. 单通道配置"
    echo "     诊断: dmidecode -t memory | grep -i channel"
    echo "     诊断: dmidecode -t memory | grep -i 'Number Of Devices'"
    echo ""
    echo "  2. 内存频率未达标"
    echo "     诊断: dmidecode -t memory | grep -i speed"
    echo "     诊断: 检查是否启用XMP/DOCP"
    echo ""
    echo "  3. CPU内存控制器限制"
    echo "     诊断: 检查CPU规格支持的内存频率"
    echo ""
    echo "  4. NUMA远程访问"
    echo "     诊断: numactl --hardware"
    echo "     诊断: 运行NUMA本地vs远程测试"
    echo ""

    echo "【症状2: 多线程扩展性差】"
    echo "----------------------------------------"
    echo ""
    echo "预期: 16线程应接近线性扩展"
    echo "实际: 仅2-3x加速"
    echo ""
    echo "可能原因:"
    echo "  1. 内存带宽饱和"
    echo "     → 内存带宽已达上限，增加线程无益"
    echo "     → 正常现象：STREAM受限于内存带宽"
    echo ""
    echo "  2. NUMA配置不当"
    echo "     → 线程跨NUMA节点运行"
    echo "     → 使用numactl绑定"
    echo ""
    echo "  3. 编译未启用OpenMP"
    echo "     → 检查编译选项是否包含-fopenmp"
    echo ""

    echo "【症状3: Copy > Scale, Add, Triad 差异过大】"
    echo "----------------------------------------"
    echo ""
    echo "预期比值: Scale/Copy ≈ 0.85-0.95"
    echo "实际: Scale/Copy < 0.7"
    echo ""
    echo "可能原因:"
    echo "  1. FPU性能较弱"
    echo "     → 老旧CPU架构"
    echo "     → FPU频率降低（节能模式）"
    echo ""
    echo "  2. 编译优化不足"
    echo "     → 未使用-O3优化"
    echo "     → 未使用-march=native"
    echo ""

    # ========== 优化建议 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "6. 性能优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【编译优化】"
    echo "----------------------------------------"
    echo ""
    echo "基础优化:"
    echo "  gcc -O3 -march=native -fopenmp stream.c -o stream"
    echo ""
    echo "高级优化:"
    echo "  # Intel编译器"
    echo "  icc -O3 -xHost -qopenmp -DSTREAM_ARRAY_SIZE=200000000 stream.c"
    echo ""
    echo "  # GCC with AVX512"
    echo "  gcc -O3 -march=skylake-avx512 -fopenmp stream.c"
    echo ""
    echo "  # 禁用某些优化避免循环被优化掉"
    echo "  gcc -O3 -march=native -fopenmp -fno-tree-vectorize stream.c"
    echo ""

    echo "【运行时优化】"
    echo "----------------------------------------"
    echo ""
    echo "1. 设置线程数"
    echo "   export OMP_NUM_THREADS=\$(nproc)"
    echo "   或"
    echo "   export OMP_NUM_THREADS=\$(lscpu | grep 'Core(s) per socket' | awk '{print \$4}')"
    echo ""
    echo "2. CPU性能模式"
    echo "   sudo cpupower frequency-set -g performance"
    echo ""
    echo "3. 禁用turbo boost（获得稳定结果）"
    echo "   echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo"
    echo ""
    echo "4. NUMA绑定"
    echo "   numactl --cpunodebind=0 --membind=0 ./stream"
    echo ""
    echo "5. Huge Pages"
    echo "   echo 1024 > /proc/sys/vm/nr_hugepages"
    echo "   # 需要重新编译支持huge pages"
    echo ""

    echo "【系统配置优化】"
    echo "----------------------------------------"
    echo ""
    echo "1. 启用内存XMP/DOCP配置"
    echo "   → BIOS中启用，让内存运行在额定频率"
    echo ""
    echo "2. 检查内存配置"
    echo "   → 确保双通道/四通道正确安装"
    echo "   → 查阅主板手册，插对插槽"
    echo ""
    echo "3. 关闭不必要的服务"
    echo "   → 测试时减少系统干扰"
    echo ""

    echo "【针对多路服务器】"
    echo "----------------------------------------"
    echo ""
    echo "1. NUMA优化"
    echo "   # 测试每个NUMA节点"
    echo "   for node in 0 1; do"
    echo "     echo \"Node \$node:\""
    echo "     numactl --cpunodebind=\$node --membind=\$node ./stream"
    echo "   done"
    echo ""
    echo "2. 内存交错模式"
    echo "   numactl --interleave=all ./stream"
    echo ""
    echo "3. 检查NUMA平衡"
    echo "   numastat"
    echo "   numastat -p \$(pgrep stream)"
    echo ""

    # ========== 结果验证 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "7. 结果验证与合理性检查"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【理论带宽计算】"
    echo "----------------------------------------"
    echo ""
    echo "公式: 理论带宽 = 内存频率 × 位宽 × 通道数 / 8"
    echo ""
    echo "示例1: DDR4-3200 双通道"
    echo "  = 3200 MHz × 64 bit × 2 / 8"
    echo "  = 51200 MB/s"
    echo "  = 51.2 GB/s"
    echo ""
    echo "示例2: DDR4-2666 四通道"
    echo "  = 2666 MHz × 64 bit × 4 / 8"
    echo "  = 85312 MB/s"
    echo "  = 85.3 GB/s"
    echo ""

    echo "【实际可达比例】"
    echo "----------------------------------------"
    echo ""
    echo "消费级平台: 60-80% 理论峰值"
    echo "服务器平台: 70-85% 理论峰值"
    echo ""
    echo "示例验证:"
    echo "  理论: DDR4-3200双通道 = 51.2 GB/s"
    echo "  实际Triad: 38 GB/s"
    echo "  比例: 38 / 51.2 = 74% ✓ 合理"
    echo ""

    echo "【异常结果识别】"
    echo "----------------------------------------"
    echo ""
    echo "❌ 异常1: 实际 > 理论峰值"
    echo "  → 不可能！测试有误"
    echo "  → 检查: 数组大小是否太小（被缓存）"
    echo "  → 检查: 计时是否准确"
    echo ""
    echo "❌ 异常2: 实际 < 理论峰值 × 40%"
    echo "  → 性能严重偏低"
    echo "  → 检查: 单通道配置？"
    echo "  → 检查: 内存频率是否降低？"
    echo "  → 检查: NUMA远程访问？"
    echo ""
    echo "✓ 正常: 实际 = 理论峰值 × 60-85%"
    echo "  → 符合预期"
    echo ""

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "分析完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

} | tee "$ANALYSIS_FILE"

echo ""
echo "✓ 详细分析完成"
echo ""
echo "查看完整分析: cat $ANALYSIS_FILE"
echo ""
