#!/bin/bash
# generate_histogram.sh - 生成延迟分布直方图

HIST_FILE=$1  # cyclictest生成的.hist文件
OUTPUT_SVG=$2 # 输出SVG文件名

if [ -z "$HIST_FILE" ] || [ -z "$OUTPUT_SVG" ]; then
    echo "Usage: $0 <hist_file> <output.svg>"
    echo ""
    echo "示例:"
    echo "  $0 scenario1_idle.hist idle_histogram.svg"
    exit 1
fi

if [ ! -f "$HIST_FILE" ]; then
    echo "错误: 文件不存在: $HIST_FILE"
    exit 1
fi

# 检查gnuplot
if ! command -v gnuplot &> /dev/null; then
    echo "错误: gnuplot 未安装"
    echo "安装: sudo apt-get install gnuplot"
    exit 1
fi

# 计算统计信息
TOTAL_SAMPLES=$(awk '{sum+=$2} END {print sum}' "$HIST_FILE")
MAX_LATENCY=$(awk 'BEGIN{max=0} {if($1>max && $2>0) max=$1} END{print max}' "$HIST_FILE")
PERCENTILE_99=$(awk -v total=$TOTAL_SAMPLES 'BEGIN{sum=0; target=total*0.99} {sum+=$2; if(sum>=target && !found){print $1; found=1}}' "$HIST_FILE")

echo "直方图统计:"
echo "  总样本数: $TOTAL_SAMPLES"
echo "  最大延迟: ${MAX_LATENCY}μs"
echo "  99百分位: ${PERCENTILE_99}μs"
echo ""

# 生成gnuplot脚本
cat > /tmp/plot_histogram_$$.gp << EOF
set terminal svg enhanced size 1200,800 font "Arial,12"
set output '$OUTPUT_SVG'

# 标题和标签
set title "Cyclictest Latency Distribution Histogram" font ",16"
set xlabel "Latency (microseconds)" font ",14"
set ylabel "Number of Samples (log scale)" font ",14"

# 网格和样式
set grid y
set style fill solid 0.6 border -1
set boxwidth 0.8 relative

# 对数坐标（如果数据范围大）
set logscale y 10

# X轴范围（聚焦在有数据的区域）
set xrange [0:${MAX_LATENCY}*1.1]

# 颜色方案
set style line 1 lc rgb "#0060ad" lt 1 lw 2
set style line 2 lc rgb "#dd181f" lt 1 lw 2
set style line 3 lc rgb "gray" lt 2 lw 1

# 添加参考线（99百分位）
set arrow from ${PERCENTILE_99},graph 0 to ${PERCENTILE_99},graph 1 nohead ls 3 dt 2
set label "P99: ${PERCENTILE_99}μs" at ${PERCENTILE_99}*1.02,graph 0.9 font ",10"

# 绘制直方图
plot '$HIST_FILE' using 1:2 with boxes ls 1 title "Latency Samples", \\
     '$HIST_FILE' using 1:2 smooth bezier ls 2 title "Trend" with lines

# 添加统计信息
set label 1 sprintf("Total Samples: $TOTAL_SAMPLES") at graph 0.02, 0.95 font ",10"
set label 2 sprintf("Max Latency: ${MAX_LATENCY}μs") at graph 0.02, 0.90 font ",10"
set label 3 sprintf("99th Percentile: ${PERCENTILE_99}μs") at graph 0.02, 0.85 font ",10"

# 重新绘制以显示标签
replot
EOF

# 运行gnuplot
gnuplot /tmp/plot_histogram_$$.gp

# 清理临时文件
rm -f /tmp/plot_histogram_$$.gp

if [ -f "$OUTPUT_SVG" ]; then
    echo "✓ 直方图已生成: $OUTPUT_SVG"
    echo ""
    echo "查看图表:"
    echo "  open $OUTPUT_SVG"
    echo "  # 或使用浏览器打开"
else
    echo "✗ 生成失败"
    exit 1
fi
