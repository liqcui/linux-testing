#!/bin/bash
# generate_cdf_plot.sh - 生成CDF对比图（累积分布函数）

OUTPUT_DIR=$1

if [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <output_directory>"
    echo ""
    echo "示例:"
    echo "  $0 ../results/cyclictest_scenarios_20260419_143022"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "错误: 目录不存在: $OUTPUT_DIR"
    exit 1
fi

# 检查gnuplot
if ! command -v gnuplot &> /dev/null; then
    echo "错误: gnuplot 未安装"
    echo "安装: sudo apt-get install gnuplot"
    exit 1
fi

echo "生成累积分布函数(CDF)对比图..."
echo ""

# 生成CDF数据
for hist in "$OUTPUT_DIR"/scenario*.hist; do
    if [ -f "$hist" ]; then
        basename=$(basename "$hist" .hist)
        echo "处理: $basename"

        # 计算累积和
        awk '{sum+=$2; print $1, sum}' "$hist" > "${hist%.hist}_cdf.txt"

        # 转换为百分比
        total=$(tail -1 "${hist%.hist}_cdf.txt" | awk '{print $2}')
        if [ "$total" -gt 0 ]; then
            awk -v total="$total" '{print $1, $2/total * 100}' "${hist%.hist}_cdf.txt" > "${hist%.hist}_cdf_percent.txt"
        fi
    fi
done

echo ""

# gnuplot CDF脚本
cat > /tmp/cdf_plot_$$.gp << 'EOF'
set terminal svg enhanced size 1200,800 font "Arial,14"
set output 'OUTPUT_DIR/cdf_comparison.svg'

set title "Latency Cumulative Distribution Function (CDF)" font ",16"
set xlabel "Latency (μs)" font ",14"
set ylabel "Cumulative Probability (%)" font ",14"

set xrange [0:500]    # 关注0-500μs范围
set yrange [0:100]

set grid
set key top left

# 参考线
set arrow from 50,0 to 50,100 nohead lc rgb "gray" dt 2 lw 1
set arrow from 100,0 to 100,100 nohead lc rgb "gray" dt 2 lw 1
set label "50μs" at 50,5 center font ",10"
set label "100μs" at 100,5 center font ",10"

# 99%目标线
set arrow from 0,99 to 500,99 nohead lc rgb "black" dt 3 lw 1
set label "99% Target" at 510,99 left font ",10"

# 颜色定义
IDLE_COLOR = "#2ecc71"      # 绿色
CPU_COLOR = "#3498db"       # 蓝色
IO_COLOR = "#e74c3c"        # 红色
COMBO_COLOR = "#9b59b6"     # 紫色

# 绘制CDF曲线
plot 'OUTPUT_DIR/scenario1_idle_cdf_percent.txt' using 1:2 with lines lw 3 lc rgb IDLE_COLOR title "Idle (Baseline)", \
     'OUTPUT_DIR/scenario2_cpu_load_cdf_percent.txt' using 1:2 with lines lw 3 lc rgb CPU_COLOR title "CPU Load", \
     'OUTPUT_DIR/scenario3_io_load_cdf_percent.txt' using 1:2 with lines lw 3 lc rgb IO_COLOR title "I/O Pressure"

# 如果存在组合压力数据，也绘制
# 'OUTPUT_DIR/scenario4_combo_cdf_percent.txt' using 1:2 with lines lw 3 lc rgb COMBO_COLOR title "Combined Load"
EOF

sed -i.bak "s|OUTPUT_DIR|$OUTPUT_DIR|g" /tmp/cdf_plot_$$.gp

# 运行gnuplot
gnuplot /tmp/cdf_plot_$$.gp

# 清理临时文件
rm -f /tmp/cdf_plot_$$.gp /tmp/cdf_plot_$$.gp.bak

# 计算关键百分位数
echo "========================================="
echo "百分位数分析"
echo "========================================="
echo ""

printf "%-20s %10s %10s %10s %10s\n" "场景" "P50" "P90" "P99" "P99.9"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for f in "$OUTPUT_DIR"/scenario*_cdf_percent.txt; do
    if [ -f "$f" ]; then
        basename=$(basename "$f" _cdf_percent.txt)

        # 提取百分位数
        p50=$(awk '$2>=50 {print $1; exit}' "$f")
        p90=$(awk '$2>=90 {print $1; exit}' "$f")
        p99=$(awk '$2>=99 {print $1; exit}' "$f")
        p999=$(awk '$2>=99.9 {print $1; exit}' "$f")

        # 清理场景名称
        scenario_name=$(echo "$basename" | sed 's/scenario[0-9]_//' | sed 's/_/ /g')

        printf "%-20s %9sμs %9sμs %9sμs %9sμs\n" "$scenario_name" "$p50" "$p90" "$p99" "$p999"
    fi
done

echo ""

# 生成百分位数分析报告
{
    echo "百分位数分析报告"
    echo "========================================"
    echo ""
    echo "生成时间: $(date)"
    echo ""

    echo "关键指标说明:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  P50 (中位数):  50%的样本延迟低于此值"
    echo "  P90:           90%的样本延迟低于此值"
    echo "  P99:           99%的样本延迟低于此值（关键指标）"
    echo "  P99.9:         99.9%的样本延迟低于此值（极端情况）"
    echo ""

    echo "百分位数数据:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    for f in "$OUTPUT_DIR"/scenario*_cdf_percent.txt; do
        if [ -f "$f" ]; then
            basename=$(basename "$f" _cdf_percent.txt)
            scenario_name=$(echo "$basename" | sed 's/scenario[0-9]_//' | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1')

            p50=$(awk '$2>=50 {print $1; exit}' "$f")
            p90=$(awk '$2>=90 {print $1; exit}' "$f")
            p99=$(awk '$2>=99 {print $1; exit}' "$f")
            p999=$(awk '$2>=99.9 {print $1; exit}' "$f")

            echo "$scenario_name:"
            echo "  P50  = ${p50}μs"
            echo "  P90  = ${p90}μs"
            echo "  P99  = ${p99}μs"
            echo "  P99.9= ${p999}μs"
            echo ""
        fi
    done

    echo "性能评估（基于P99）:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 获取空载P99作为基准
    idle_p99=$(awk '$2>=99 {print $1; exit}' "$OUTPUT_DIR/scenario1_idle_cdf_percent.txt")

    echo "  基准（空载）P99: ${idle_p99}μs"
    echo ""

    for f in "$OUTPUT_DIR"/scenario*_cdf_percent.txt; do
        if [ -f "$f" ]; then
            basename=$(basename "$f" _cdf_percent.txt)

            # 跳过空载
            if [[ "$basename" == *"idle"* ]]; then
                continue
            fi

            scenario_name=$(echo "$basename" | sed 's/scenario[0-9]_//' | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1')
            p99=$(awk '$2>=99 {print $1; exit}' "$f")

            if [ -n "$idle_p99" ] && [ -n "$p99" ] && [ "$idle_p99" -gt 0 ]; then
                increase=$((p99 - idle_p99))
                ratio=$(echo "scale=2; $p99 / $idle_p99" | bc)
                percent=$(echo "scale=0; ($p99 - $idle_p99) * 100 / $idle_p99" | bc)

                echo "  $scenario_name:"
                echo "    P99: ${p99}μs"
                echo "    增加: +${increase}μs (+${percent}%)"
                echo "    倍数: ${ratio}x"

                # 评级
                if [ $p99 -lt 50 ]; then
                    echo "    评级: ★★★★★ 优秀"
                elif [ $p99 -lt 100 ]; then
                    echo "    评级: ★★★★☆ 良好"
                elif [ $p99 -lt 500 ]; then
                    echo "    评级: ★★★☆☆ 一般"
                else
                    echo "    评级: ★★☆☆☆ 需优化"
                fi
                echo ""
            fi
        fi
    done

    echo "建议:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "• CDF图左移（曲线更快上升）表示延迟更低"
    echo "• 关注P99和P99.9，它们代表最坏情况"
    echo "• 实时系统应确保P99 < 100μs"
    echo "• 如果某场景下P99明显恶化，针对该场景优化"
    echo ""

} | tee "$OUTPUT_DIR/percentile_analysis.txt"

if [ -f "$OUTPUT_DIR/cdf_comparison.svg" ]; then
    echo "✓ CDF对比图已生成: $OUTPUT_DIR/cdf_comparison.svg"
    echo "✓ 百分位数分析已保存: $OUTPUT_DIR/percentile_analysis.txt"
    echo ""
    echo "查看图表:"
    echo "  open $OUTPUT_DIR/cdf_comparison.svg"
    echo ""
    echo "查看分析:"
    echo "  cat $OUTPUT_DIR/percentile_analysis.txt"
else
    echo "✗ 生成失败"
    exit 1
fi
