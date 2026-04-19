#!/bin/bash
# test_bcc.sh - BCC eBPF追踪工具综合测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/bcc_test_$(date +%Y%m%d_%H%M%S)"

# 参数
DURATION=10
TARGET_PID=""

# 使用说明
usage() {
    cat << EOF
用法: $0 [选项]

BCC eBPF追踪工具测试套件

选项:
  -d DURATION     测试时长（秒，默认10）
  -p PID          目标进程PID（可选）
  -h              显示此帮助信息

示例:
  # 系统范围测试
  sudo $0 -d 30

  # 特定进程测试
  sudo $0 -p 1234 -d 30

EOF
    exit 1
}

# 解析参数
while getopts "d:p:h" opt; do
    case $opt in
        d) DURATION="$OPTARG" ;;
        p) TARGET_PID="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

mkdir -p "$RESULTS_DIR"

echo "========================================"
echo "BCC eBPF 追踪工具测试"
echo "========================================"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo "✗ 错误: 此脚本需要root权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

# 检查内核版本
KERNEL_VERSION=$(uname -r | cut -d. -f1,2)
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)

echo "系统信息:"
echo "  内核版本: $(uname -r)"
echo "  测试时长: ${DURATION}秒"
if [[ -n "$TARGET_PID" ]]; then
    echo "  目标PID: $TARGET_PID"
fi
echo "  结果目录: $RESULTS_DIR"
echo ""

if [[ $KERNEL_MAJOR -lt 4 ]] || [[ $KERNEL_MAJOR -eq 4 && $KERNEL_MINOR -lt 1 ]]; then
    echo "⚠ 警告: 内核版本 < 4.1，eBPF功能可能受限"
fi

# 检查BCC安装
echo "步骤 1: 检查BCC工具安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

BCC_TOOLS=(
    execsnoop
    opensnoop
    biolatency
    tcpconnect
    tcplife
    ext4slower
    profile
)

INSTALLED_TOOLS=()
MISSING_TOOLS=()

for tool in "${BCC_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        INSTALLED_TOOLS+=("$tool")
        echo "✓ $tool"
    else
        MISSING_TOOLS+=("$tool")
        echo "✗ $tool (未安装)"
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo ""
    echo "⚠ 部分BCC工具未安装"
    echo ""
    echo "安装方法:"
    echo ""
    echo "Ubuntu/Debian:"
    echo "  sudo apt-get install bpfcc-tools linux-headers-\$(uname -r)"
    echo ""
    echo "RHEL/CentOS 8+:"
    echo "  sudo dnf install bcc-tools kernel-devel-\$(uname -r)"
    echo ""
    echo "Fedora:"
    echo "  sudo dnf install bcc-tools kernel-devel"
    echo ""

    if [[ ${#INSTALLED_TOOLS[@]} -eq 0 ]]; then
        echo "✗ 未检测到任何BCC工具，无法继续测试"
        exit 1
    fi

    echo "将使用已安装的工具继续测试..."
fi

echo ""

# BCC工具原理说明
{
    echo "BCC eBPF追踪原理"
    echo "========================================"
    echo ""
    echo "BCC (BPF Compiler Collection) 是基于eBPF的追踪工具集"
    echo ""
    echo "核心优势:"
    echo "  • 零开销: 未启用时对系统无影响"
    echo "  • 安全性: 在内核中运行验证后的代码"
    echo "  • 低延迟: 内核态事件过滤和聚合"
    echo "  • 动态性: 无需重启或重新编译内核"
    echo ""
    echo "工作原理:"
    echo "  1. 用户空间编写eBPF程序（C语言）"
    echo "  2. BCC编译为字节码"
    echo "  3. 内核验证器检查安全性"
    echo "  4. JIT编译为机器码"
    echo "  5. 附加到内核探测点（kprobes/tracepoints/uprobes）"
    echo "  6. 事件触发时执行eBPF程序"
    echo "  7. 数据通过maps传回用户空间"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

echo ""

# 测试1: execsnoop - 进程执行监控
if command -v execsnoop &> /dev/null; then
    echo "步骤 2: execsnoop - 进程执行监控..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "execsnoop - 进程执行监控"
        echo "========================================"
        echo ""
        echo "功能:"
        echo "  实时监控系统中所有exec()系统调用"
        echo "  追踪新进程创建、命令执行"
        echo ""
        echo "应用场景:"
        echo "  • 安全审计: 发现可疑进程启动"
        echo "  • 性能分析: 找到频繁fork/exec的进程"
        echo "  • 容器监控: 追踪容器内进程"
        echo "  • 脚本调试: 查看shell脚本执行了哪些命令"
        echo ""
        echo "输出字段:"
        echo "  PCOMM:  父进程名称"
        echo "  PID:    进程ID"
        echo "  PPID:   父进程ID"
        echo "  RET:    返回值（0=成功）"
        echo "  ARGS:   完整命令行参数"
        echo ""
        echo "测试结果（${DURATION}秒）:"
        echo "----------------------------------------"
    } | tee "$RESULTS_DIR/execsnoop.txt"

    echo "正在监控进程执行（${DURATION}秒）..."
    echo "提示: 在另一个终端执行一些命令以产生数据"

    timeout ${DURATION}s execsnoop 2>&1 | head -100 | tee -a "$RESULTS_DIR/execsnoop.txt"

    echo ""
    echo "✓ 进程执行监控完成"
    echo ""
fi

# 测试2: opensnoop - 文件打开监控
if command -v opensnoop &> /dev/null; then
    echo "步骤 3: opensnoop - 文件打开监控..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "opensnoop - 文件打开监控"
        echo "========================================"
        echo ""
        echo "功能:"
        echo "  实时监控所有open()/openat()系统调用"
        echo "  追踪文件访问模式"
        echo ""
        echo "应用场景:"
        echo "  • 性能分析: 找到频繁打开的文件"
        echo "  • 配置审计: 查看程序读取哪些配置文件"
        echo "  • 故障排查: 定位文件未找到错误"
        echo "  • 安全监控: 检测敏感文件访问"
        echo ""
        echo "输出字段:"
        echo "  PID:   进程ID"
        echo "  COMM:  进程名称"
        echo "  FD:    文件描述符（-1表示失败）"
        echo "  ERR:   错误码"
        echo "  PATH:  文件路径"
        echo ""
        echo "测试结果（${DURATION}秒）:"
        echo "----------------------------------------"
    } | tee "$RESULTS_DIR/opensnoop.txt"

    echo "正在监控文件打开（${DURATION}秒）..."

    if [[ -n "$TARGET_PID" ]]; then
        timeout ${DURATION}s opensnoop -p "$TARGET_PID" 2>&1 | head -100 | tee -a "$RESULTS_DIR/opensnoop.txt"
    else
        timeout ${DURATION}s opensnoop 2>&1 | head -100 | tee -a "$RESULTS_DIR/opensnoop.txt"
    fi

    echo ""
    echo "✓ 文件打开监控完成"
    echo ""
fi

# 测试3: biolatency - 块I/O延迟分析
if command -v biolatency &> /dev/null; then
    echo "步骤 4: biolatency - 块I/O延迟直方图..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "biolatency - 块I/O延迟分析"
        echo "========================================"
        echo ""
        echo "功能:"
        echo "  统计块设备I/O请求的延迟分布"
        echo "  生成延迟直方图"
        echo ""
        echo "应用场景:"
        echo "  • 存储性能分析: 识别I/O延迟问题"
        echo "  • 磁盘健康检查: 发现慢盘"
        echo "  • 应用调优: 优化I/O模式"
        echo "  • SSD vs HDD对比"
        echo ""
        echo "输出说明:"
        echo "  直方图显示I/O延迟分布"
        echo "  横轴: 延迟范围（微秒、毫秒）"
        echo "  纵轴: 该范围内的I/O次数"
        echo ""
        echo "测试结果（${DURATION}秒）:"
        echo "----------------------------------------"
    } | tee "$RESULTS_DIR/biolatency.txt"

    echo "正在统计块I/O延迟（${DURATION}秒）..."

    timeout ${DURATION}s biolatency 1 2>&1 | tee -a "$RESULTS_DIR/biolatency.txt"

    echo ""
    echo "✓ 块I/O延迟分析完成"
    echo ""
fi

# 测试4: tcpconnect - TCP连接追踪
if command -v tcpconnect &> /dev/null; then
    echo "步骤 5: tcpconnect - TCP主动连接追踪..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "tcpconnect - TCP主动连接追踪"
        echo "========================================"
        echo ""
        echo "功能:"
        echo "  追踪所有TCP主动连接（connect()调用）"
        echo "  监控出站TCP连接"
        echo ""
        echo "应用场景:"
        echo "  • 网络审计: 查看程序连接的外部服务"
        echo "  • 故障排查: 定位连接失败问题"
        echo "  • 安全监控: 发现异常外连行为"
        echo "  • 微服务追踪: 监控服务间调用"
        echo ""
        echo "输出字段:"
        echo "  PID:   进程ID"
        echo "  COMM:  进程名称"
        echo "  IP:    IP版本（4或6）"
        echo "  SADDR: 源地址"
        echo "  DADDR: 目标地址"
        echo "  DPORT: 目标端口"
        echo ""
        echo "测试结果（${DURATION}秒）:"
        echo "----------------------------------------"
    } | tee "$RESULTS_DIR/tcpconnect.txt"

    echo "正在追踪TCP连接（${DURATION}秒）..."
    echo "提示: 访问网站或执行网络操作以产生数据"

    timeout ${DURATION}s tcpconnect 2>&1 | head -50 | tee -a "$RESULTS_DIR/tcpconnect.txt"

    echo ""
    echo "✓ TCP连接追踪完成"
    echo ""
fi

# 测试5: tcplife - TCP连接生命周期
if command -v tcplife &> /dev/null; then
    echo "步骤 6: tcplife - TCP连接生命周期分析..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "tcplife - TCP连接生命周期"
        echo "========================================"
        echo ""
        echo "功能:"
        echo "  追踪TCP连接的完整生命周期"
        echo "  统计连接时长、传输字节数"
        echo ""
        echo "应用场景:"
        echo "  • 性能分析: 识别长连接和短连接"
        echo "  • 网络优化: 分析连接复用效率"
        echo "  • 容量规划: 统计连接数和流量"
        echo "  • 异常检测: 发现异常长或短的连接"
        echo ""
        echo "输出字段:"
        echo "  PID:   进程ID"
        echo "  COMM:  进程名称"
        echo "  LADDR: 本地地址:端口"
        echo "  RADDR: 远程地址:端口"
        echo "  TX_KB: 发送数据（KB）"
        echo "  RX_KB: 接收数据（KB）"
        echo "  MS:    连接持续时间（毫秒）"
        echo ""
        echo "测试结果（${DURATION}秒）:"
        echo "----------------------------------------"
    } | tee "$RESULTS_DIR/tcplife.txt"

    echo "正在分析TCP连接生命周期（${DURATION}秒）..."

    timeout ${DURATION}s tcplife 2>&1 | head -50 | tee -a "$RESULTS_DIR/tcplife.txt"

    echo ""
    echo "✓ TCP连接生命周期分析完成"
    echo ""
fi

# 测试6: ext4slower - 慢速文件系统操作
if command -v ext4slower &> /dev/null; then
    echo "步骤 7: ext4slower - 慢速ext4操作追踪..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "ext4slower - 慢速ext4操作"
        echo "========================================"
        echo ""
        echo "功能:"
        echo "  追踪超过阈值的ext4文件系统操作"
        echo "  识别慢速文件I/O"
        echo ""
        echo "应用场景:"
        echo "  • 性能诊断: 找到慢速文件操作"
        echo "  • 存储优化: 识别I/O瓶颈"
        echo "  • 应用调优: 优化文件访问模式"
        echo ""
        echo "输出字段:"
        echo "  TIME:   时间戳"
        echo "  COMM:   进程名称"
        echo "  PID:    进程ID"
        echo "  T:      操作类型（R=读, W=写, O=打开, S=同步）"
        echo "  BYTES:  字节数"
        echo "  OFF_KB: 文件偏移（KB）"
        echo "  LAT(ms):延迟（毫秒）"
        echo "  FILENAME: 文件名"
        echo ""
        echo "测试结果（${DURATION}秒，阈值10ms）:"
        echo "----------------------------------------"
    } | tee "$RESULTS_DIR/ext4slower.txt"

    echo "正在追踪慢速ext4操作（${DURATION}秒）..."

    timeout ${DURATION}s ext4slower 10 2>&1 | head -50 | tee -a "$RESULTS_DIR/ext4slower.txt"

    echo ""
    echo "✓ 慢速ext4操作追踪完成"
    echo ""
fi

# 测试7: profile - CPU采样分析
if command -v profile &> /dev/null; then
    echo "步骤 8: profile - CPU采样分析..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    {
        echo "profile - CPU采样分析"
        echo "========================================"
        echo ""
        echo "功能:"
        echo "  基于定时器的CPU采样"
        echo "  类似perf，但使用eBPF实现"
        echo ""
        echo "应用场景:"
        echo "  • CPU热点分析"
        echo "  • 性能剖析"
        echo "  • 调用栈追踪"
        echo ""
        echo "输出说明:"
        echo "  按采样次数排序的函数列表"
        echo "  可生成火焰图"
        echo ""
        echo "测试结果（${DURATION}秒）:"
        echo "----------------------------------------"
    } | tee "$RESULTS_DIR/profile.txt"

    echo "正在CPU采样（${DURATION}秒）..."

    if [[ -n "$TARGET_PID" ]]; then
        timeout ${DURATION}s profile -p "$TARGET_PID" 2>&1 | head -50 | tee -a "$RESULTS_DIR/profile.txt"
    else
        timeout ${DURATION}s profile 2>&1 | head -50 | tee -a "$RESULTS_DIR/profile.txt"
    fi

    echo ""
    echo "✓ CPU采样分析完成"
    echo ""
fi

# 生成综合报告
echo "步骤 9: 生成综合分析报告..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "========================================"
    echo "BCC eBPF 追踪测试综合报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "内核版本: $(uname -r)"
    echo "测试时长: ${DURATION}秒"
    if [[ -n "$TARGET_PID" ]]; then
        echo "目标PID: $TARGET_PID"
    fi
    echo ""

    echo "一、已执行的测试"
    echo "----------------------------------------"
    echo ""

    if [[ -f "$RESULTS_DIR/execsnoop.txt" ]]; then
        echo "✓ execsnoop - 进程执行监控"
        EXEC_COUNT=$(grep -c "^[0-9]" "$RESULTS_DIR/execsnoop.txt" 2>/dev/null || echo "0")
        echo "  捕获进程: $EXEC_COUNT 个"
    fi

    if [[ -f "$RESULTS_DIR/opensnoop.txt" ]]; then
        echo "✓ opensnoop - 文件打开监控"
        OPEN_COUNT=$(grep -c "^[0-9]" "$RESULTS_DIR/opensnoop.txt" 2>/dev/null || echo "0")
        echo "  文件操作: $OPEN_COUNT 次"
    fi

    if [[ -f "$RESULTS_DIR/biolatency.txt" ]]; then
        echo "✓ biolatency - 块I/O延迟分析"
        echo "  延迟分布: 已生成直方图"
    fi

    if [[ -f "$RESULTS_DIR/tcpconnect.txt" ]]; then
        echo "✓ tcpconnect - TCP连接追踪"
        TCP_COUNT=$(grep -c "^[0-9]" "$RESULTS_DIR/tcpconnect.txt" 2>/dev/null || echo "0")
        echo "  TCP连接: $TCP_COUNT 个"
    fi

    if [[ -f "$RESULTS_DIR/tcplife.txt" ]]; then
        echo "✓ tcplife - TCP生命周期分析"
        TCPLIFE_COUNT=$(grep -c "^[0-9]" "$RESULTS_DIR/tcplife.txt" 2>/dev/null || echo "0")
        echo "  连接记录: $TCPLIFE_COUNT 条"
    fi

    if [[ -f "$RESULTS_DIR/ext4slower.txt" ]]; then
        echo "✓ ext4slower - 慢速文件操作"
        SLOW_COUNT=$(grep -c "^[0-9]" "$RESULTS_DIR/ext4slower.txt" 2>/dev/null || echo "0")
        echo "  慢操作: $SLOW_COUNT 次"
    fi

    if [[ -f "$RESULTS_DIR/profile.txt" ]]; then
        echo "✓ profile - CPU采样分析"
        echo "  热点函数: 已采样"
    fi

    echo ""

    echo "二、关键发现"
    echo "----------------------------------------"
    echo ""

    # 分析execsnoop结果
    if [[ -f "$RESULTS_DIR/execsnoop.txt" ]]; then
        FAILED_EXECS=$(grep -c "RET.*-[0-9]" "$RESULTS_DIR/execsnoop.txt" 2>/dev/null || echo "0")
        if [[ $FAILED_EXECS -gt 0 ]]; then
            echo "⚠ 进程执行失败: $FAILED_EXECS 次"
            echo "  建议: 检查execsnoop.txt中RET为负值的记录"
            echo ""
        fi
    fi

    # 分析opensnoop结果
    if [[ -f "$RESULTS_DIR/opensnoop.txt" ]]; then
        FAILED_OPENS=$(grep -c "FD.*-[0-9]" "$RESULTS_DIR/opensnoop.txt" 2>/dev/null || echo "0")
        if [[ $FAILED_OPENS -gt 0 ]]; then
            echo "⚠ 文件打开失败: $FAILED_OPENS 次"
            echo "  建议: 检查opensnoop.txt中FD为负值的记录"
            echo ""
        fi
    fi

    # 分析biolatency结果
    if [[ -f "$RESULTS_DIR/biolatency.txt" ]]; then
        if grep -q "msecs.*[1-9][0-9]\{2,\}" "$RESULTS_DIR/biolatency.txt" 2>/dev/null; then
            echo "⚠ 检测到高延迟I/O操作（>100ms）"
            echo "  建议: 检查磁盘健康状态和I/O调度器"
            echo ""
        fi
    fi

    echo "三、详细结果文件"
    echo "----------------------------------------"
    echo ""
    ls -lh "$RESULTS_DIR"/*.txt 2>/dev/null | awk '{printf "  • %s (%s)\n", $9, $5}'
    echo ""

    echo "四、后续分析建议"
    echo "----------------------------------------"
    echo ""
    echo "1. 深入分析特定问题:"
    echo "   • 查看各工具的详细输出文件"
    echo "   • 使用bpftrace编写自定义追踪脚本"
    echo ""
    echo "2. 性能优化:"
    echo "   • 根据热点函数优化代码"
    echo "   • 根据I/O延迟优化存储配置"
    echo "   • 根据网络连接优化应用架构"
    echo ""
    echo "3. 持续监控:"
    echo "   • 将关键BCC工具集成到监控系统"
    echo "   • 设置告警阈值"
    echo "   • 定期生成报告"
    echo ""

} | tee "$RESULTS_DIR/summary_report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "结果保存到: $RESULTS_DIR"
echo ""
echo "查看综合报告:"
echo "  cat $RESULTS_DIR/summary_report.txt"
echo ""
echo "查看详细结果:"
for file in "$RESULTS_DIR"/*.txt; do
    if [[ -f "$file" ]] && [[ "$(basename "$file")" != "summary_report.txt" ]] && [[ "$(basename "$file")" != "principles.txt" ]]; then
        echo "  cat $file"
    fi
done
echo ""
echo "下一步:"
echo "  使用bpftrace进行更灵活的追踪:"
echo "  $SCRIPT_DIR/test_bpftrace.sh"
echo ""
