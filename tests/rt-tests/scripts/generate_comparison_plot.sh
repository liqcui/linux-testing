#!/bin/bash
# generate_comparison_plot.sh - 多场景对比直方图

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

OUTPUT_SVG="${OUTPUT_DIR}/latency_comparison.svg"

# 检查必需的直方图文件
REQUIRED_FILES=(
    "$OUTPUT_DIR/scenario1_idle.hist"
    "$OUTPUT_DIR/scenario2_cpu_load.hist"
    "$OUTPUT_DIR/scenario3_io_load.hist"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "错误: 缺少文件: $f"
        echo "请先运行 cyclictest_three_scenarios.sh"
        exit 1
    fi
done

echo "生成多场景对比图表..."
echo ""

# 生成归一化数据（用于叠加对比）
for f in "$OUTPUT_DIR"/scenario*.hist; do
    if [ -f "$f" ]; then
        total=$(awk '{sum+=$2} END {print sum}' "$f")
        if [ "$total" -gt 0 ]; then
            awk -v total="$total" '{print $1, $2/total}' "$f" > "${f%.hist}_norm.txt"
        fi
    fi
done

# 生成gnuplot脚本
cat > /tmp/comparison_plot_$$.gp << 'EOF'
set terminal svg enhanced size 1400,900 font "Arial,12"
set output 'OUTPUT_SVG'

# 多图布局
set multiplot layout 2,2 title "Cyclictest Latency Comparison - Multiple Scenarios" font ",16"

# 通用设置
set xlabel "Latency (μs)"
set ylabel "Samples (log scale)"
set logscale y
set grid y
set style fill solid 0.6

# 颜色定义
IDLE_COLOR = "#2ecc71"      # 绿色
CPU_COLOR = "#3498db"       # 蓝色
IO_COLOR = "#e74c3c"        # 红色
COMBO_COLOR = "#9b59b6"     # 紫色

# ========== 子图1: 空载 ==========
set title "Scenario 1: System Idle (Baseline)"
set label 1 "Best-case Performance" at graph 0.5, 0.95 center font ",10"
plot 'SCENARIO1_HIST' using 1:2 with boxes lc rgb IDLE_COLOR title "Idle"
unset label 1

# ========== 子图2: CPU满载 ==========
set title "Scenario 2: CPU Full Load"
set label 2 "Impact of CPU Saturation" at graph 0.5, 0.95 center font ",10"
plot 'SCENARIO2_HIST' using 1:2 with boxes lc rgb CPU_COLOR title "CPU Load"
unset label 2

# ========== 子图3: I/O压力 ==========
set title "Scenario 3: I/O Pressure"
set label 3 "Impact of Disk I/O" at graph 0.5, 0.95 center font ",10"
plot 'SCENARIO3_HIST' using 1:2 with boxes lc rgb IO_COLOR title "I/O Load"
unset label 3

# ========== 子图4: 叠加对比 ==========
set title "Scenario 4: Overlay Comparison"
set ylabel "Normalized Frequency"
unset logscale y
set yrange [0:*]
set key top right

# 归一化处理后的数据叠加
plot 'SCENARIO1_NORM' using 1:2 with lines lc rgb IDLE_COLOR lw 2 title "Idle (Baseline)", \
     'SCENARIO2_NORM' using 1:2 with lines lc rgb CPU_COLOR lw 2 title "CPU Load", \
     'SCENARIO3_NORM' using 1:2 with lines lc rgb IO_COLOR lw 2 title "I/O Pressure"

# 添加图例说明
set label 4 "Lower is better" at graph 0.5, 0.05 center font ",10"

unset multiplot
EOF

# 替换路径
sed -i.bak "s|OUTPUT_SVG|$OUTPUT_SVG|g" /tmp/comparison_plot_$$.gp
sed -i.bak "s|SCENARIO1_HIST|$OUTPUT_DIR/scenario1_idle.hist|g" /tmp/comparison_plot_$$.gp
sed -i.bak "s|SCENARIO2_HIST|$OUTPUT_DIR/scenario2_cpu_load.hist|g" /tmp/comparison_plot_$$.gp
sed -i.bak "s|SCENARIO3_HIST|$OUTPUT_DIR/scenario3_io_load.hist|g" /tmp/comparison_plot_$$.gp
sed -i.bak "s|SCENARIO1_NORM|$OUTPUT_DIR/scenario1_idle_norm.txt|g" /tmp/comparison_plot_$$.gp
sed -i.bak "s|SCENARIO2_NORM|$OUTPUT_DIR/scenario2_cpu_load_norm.txt|g" /tmp/comparison_plot_$$.gp
sed -i.bak "s|SCENARIO3_NORM|$OUTPUT_DIR/scenario3_io_load_norm.txt|g" /tmp/comparison_plot_$$.gp

# 运行gnuplot
gnuplot /tmp/comparison_plot_$$.gp

# 清理临时文件
rm -f /tmp/comparison_plot_$$.gp /tmp/comparison_plot_$$.gp.bak

if [ -f "$OUTPUT_SVG" ]; then
    echo "✓ 对比图已生成: $OUTPUT_SVG"
    echo ""
    echo "图表包含:"
    echo "  • 子图1: 系统空载（基准）"
    echo "  • 子图2: CPU满载"
    echo "  • 子图3: I/O压力"
    echo "  • 子图4: 归一化叠加对比"
    echo ""
    echo "查看图表:"
    echo "  open $OUTPUT_SVG"
else
    echo "✗ 生成失败"
    exit 1
fi
