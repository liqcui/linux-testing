#!/bin/bash
# analyze_unixbench.sh - UnixBench结果详细解读分析

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${1:-$SCRIPT_DIR/../results}"

# 如果没有提供结果目录，查找最新的
if [[ ! -d "$RESULTS_DIR" ]] || [[ "$RESULTS_DIR" == "$SCRIPT_DIR/../results" ]]; then
    LATEST=$(ls -td $SCRIPT_DIR/../results/unixbench-* 2>/dev/null | head -1)
    if [[ -n "$LATEST" ]]; then
        RESULTS_DIR="$LATEST"
    else
        echo "错误: 未找到测试结果目录"
        echo "请先运行: ./test_unixbench.sh"
        exit 1
    fi
fi

ANALYSIS_FILE="$RESULTS_DIR/detailed_analysis.txt"
RESULT_LOG="$RESULTS_DIR/result.log"

if [[ ! -f "$RESULT_LOG" ]]; then
    echo "错误: 未找到结果文件 $RESULT_LOG"
    exit 1
fi

echo "========================================"
echo "UnixBench 结果详细解读"
echo "========================================"
echo ""
echo "分析目录: $RESULTS_DIR"
echo "生成文件: $ANALYSIS_FILE"
echo ""

{
    echo "UnixBench测试结果详细解读"
    echo "========================================"
    echo ""
    echo "分析时间: $(date)"
    echo "结果目录: $RESULTS_DIR"
    echo ""

    # ========== 测试项目详细解读 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 测试项目详细解读"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【Dhrystone 2 using register variables】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - CPU整数运算性能基准测试"
    echo "  - 使用寄存器变量优化"
    echo "  - 模拟系统编程任务"
    echo ""
    echo "测试原理:"
    echo "  - 执行大量整数运算（加减乘除、比较、赋值）"
    echo "  - 字符串处理（复制、比较）"
    echo "  - 记录和枚举操作"
    echo "  - 测量每秒执行次数（lps - loops per second）"
    echo ""
    echo "性能指标:"
    echo "  单位: lps (每秒循环次数)"
    echo ""
    echo "典型值（参考）:"
    echo "  入门级CPU:      5,000,000 - 15,000,000 lps"
    echo "  主流CPU:       15,000,000 - 35,000,000 lps"
    echo "  高性能CPU:     35,000,000 - 60,000,000 lps"
    echo "  顶级CPU:       > 60,000,000 lps"
    echo ""
    echo "实际测试结果:"
    if grep -q "Dhrystone 2" "$RESULT_LOG"; then
        grep "Dhrystone 2" "$RESULT_LOG" | grep lps | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ CPU主频和架构"
    echo "  ✓ L1/L2缓存大小和速度"
    echo "  ✓ 编译器优化级别"
    echo "  ✓ CPU指令集（SSE、AVX）"
    echo ""
    echo "优化建议:"
    echo "  - 启用CPU性能模式: cpupower frequency-set -g performance"
    echo "  - 使用编译器优化: gcc -O3"
    echo "  - 禁用CPU节能特性"
    echo ""

    echo ""
    echo "【Double-Precision Whetstone】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - CPU浮点运算性能基准测试"
    echo "  - 双精度浮点运算"
    echo "  - 科学计算性能评估"
    echo ""
    echo "测试原理:"
    echo "  - 浮点加减乘除运算"
    echo "  - 数学函数（sin、cos、sqrt、log、exp）"
    echo "  - 数组操作"
    echo "  - 测量MWIPS（百万Whetstone指令每秒）"
    echo ""
    echo "性能指标:"
    echo "  单位: MWIPS (Million Whetstone Instructions Per Second)"
    echo ""
    echo "典型值（参考）:"
    echo "  入门级CPU:      2,000 - 5,000 MWIPS"
    echo "  主流CPU:        5,000 - 12,000 MWIPS"
    echo "  高性能CPU:     12,000 - 20,000 MWIPS"
    echo "  顶级CPU:       > 20,000 MWIPS"
    echo ""
    echo "实际测试结果:"
    if grep -q "Double-Precision Whetstone" "$RESULT_LOG"; then
        grep "Double-Precision Whetstone" "$RESULT_LOG" | grep MWIPS | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ FPU（浮点单元）性能"
    echo "  ✓ CPU支持的浮点指令集（SSE、AVX、FMA）"
    echo "  ✓ L1缓存速度"
    echo "  ✓ 编译器浮点优化"
    echo ""
    echo "应用场景:"
    echo "  - 科学计算"
    echo "  - 工程仿真"
    echo "  - 图形渲染"
    echo "  - 机器学习（部分）"
    echo ""

    echo ""
    echo "【Execl Throughput】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - 进程执行吞吐量"
    echo "  - 测试execl()系统调用性能"
    echo "  - 进程替换性能"
    echo ""
    echo "测试原理:"
    echo "  - 重复调用execl()执行/bin/ls"
    echo "  - 测量每秒执行次数"
    echo "  - 评估进程创建和程序加载开销"
    echo ""
    echo "性能指标:"
    echo "  单位: lps (loops per second)"
    echo ""
    echo "典型值（参考）:"
    echo "  物理机:        1,500 - 4,000 lps"
    echo "  虚拟机:        800 - 2,000 lps"
    echo "  容器:          1,200 - 3,500 lps"
    echo ""
    echo "实际测试结果:"
    if grep -q "Execl Throughput" "$RESULT_LOG"; then
        grep "Execl Throughput" "$RESULT_LOG" | grep lps | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ 文件系统性能（程序加载）"
    echo "  ✓ 内核进程调度器"
    echo "  ✓ 内存速度"
    echo "  ✓ 虚拟化开销"
    echo ""

    echo ""
    echo "【File Copy】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - 文件拷贝性能测试"
    echo "  - 三种不同块大小: 1024 bytes, 256 bytes, 4096 bytes"
    echo "  - 测试I/O和文件系统性能"
    echo ""
    echo "测试原理:"
    echo "  - 创建源文件并拷贝到目标文件"
    echo "  - 使用read()和write()系统调用"
    echo "  - 测量吞吐量（KB/s）"
    echo ""
    echo "性能指标:"
    echo "  单位: KBps (KB per second)"
    echo ""
    echo "典型值（参考）:"
    echo "  1024 bytes:"
    echo "    HDD:         50,000 - 200,000 KBps"
    echo "    SSD:        200,000 - 600,000 KBps"
    echo "    NVMe:       500,000 - 1,500,000 KBps"
    echo ""
    echo "  256 bytes (小块):"
    echo "    通常比大块慢 30-50%"
    echo ""
    echo "  4096 bytes (大块):"
    echo "    通常最快，接近磁盘顺序读写带宽"
    echo ""
    echo "实际测试结果:"
    if grep -q "File Copy" "$RESULT_LOG"; then
        grep "File Copy" "$RESULT_LOG" | grep KBps | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ 存储设备类型和速度"
    echo "  ✓ 文件系统类型（ext4、xfs、btrfs）"
    echo "  ✓ 页缓存大小"
    echo "  ✓ I/O调度器"
    echo ""
    echo "块大小分析:"
    echo "  - 256B: 小文件/随机I/O场景"
    echo "  - 1024B: 常规应用场景"
    echo "  - 4096B: 大文件/顺序I/O场景"
    echo ""

    echo ""
    echo "【Pipe Throughput】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - 管道通信吞吐量"
    echo "  - 进程间通信（IPC）性能"
    echo "  - 内核管道缓冲区性能"
    echo ""
    echo "测试原理:"
    echo "  - 创建管道"
    echo "  - 父子进程通过管道传输数据"
    echo "  - 测量数据传输速率"
    echo ""
    echo "性能指标:"
    echo "  单位: KBps (KB per second)"
    echo ""
    echo "典型值（参考）:"
    echo "  入门级:        500,000 - 1,500,000 KBps"
    echo "  主流:        1,500,000 - 3,500,000 KBps"
    echo "  高性能:      3,500,000 - 6,000,000 KBps"
    echo ""
    echo "实际测试结果:"
    if grep -q "Pipe Throughput" "$RESULT_LOG"; then
        grep "Pipe Throughput" "$RESULT_LOG" | grep KBps | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ 内核管道缓冲区大小"
    echo "  ✓ 上下文切换开销"
    echo "  ✓ 内存带宽"
    echo "  ✓ CPU缓存性能"
    echo ""
    echo "应用场景:"
    echo "  - Shell管道（如 cat file | grep pattern）"
    echo "  - 进程间数据传输"
    echo "  - 并发处理流水线"
    echo ""

    echo ""
    echo "【Pipe-based Context Switching】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - 基于管道的上下文切换"
    echo "  - 进程同步和切换性能"
    echo ""
    echo "测试原理:"
    echo "  - 创建两个进程通过管道互相通信"
    echo "  - 一个进程写入，另一个读取，循环往复"
    echo "  - 每次读写触发上下文切换"
    echo "  - 测量每秒切换次数"
    echo ""
    echo "性能指标:"
    echo "  单位: lps (loops per second)"
    echo ""
    echo "典型值（参考）:"
    echo "  物理机:        80,000 - 200,000 lps"
    echo "  虚拟机:        40,000 - 120,000 lps"
    echo "  容器:          60,000 - 180,000 lps"
    echo ""
    echo "实际测试结果:"
    if grep -q "Pipe-based Context Switching" "$RESULT_LOG"; then
        grep "Pipe-based Context Switching" "$RESULT_LOG" | grep lps | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ CPU调度器效率"
    echo "  ✓ 上下文切换开销"
    echo "  ✓ 系统负载"
    echo "  ✓ 虚拟化开销"
    echo ""
    echo "与LMbench lat_ctx对比:"
    echo "  - UnixBench: 测量吞吐量（次/秒）"
    echo "  - LMbench: 测量延迟（微秒/次）"
    echo "  - 两者互补，一个看速度，一个看时间"
    echo ""

    echo ""
    echo "【Process Creation】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - 进程创建性能"
    echo "  - fork()系统调用性能"
    echo ""
    echo "测试原理:"
    echo "  - 重复调用fork()创建子进程"
    echo "  - 子进程立即退出"
    echo "  - 测量每秒创建进程数"
    echo ""
    echo "性能指标:"
    echo "  单位: lps (loops per second)"
    echo ""
    echo "典型值（参考）:"
    echo "  物理机:        5,000 - 15,000 lps"
    echo "  虚拟机:        2,000 - 8,000 lps"
    echo "  容器:          4,000 - 12,000 lps"
    echo ""
    echo "实际测试结果:"
    if grep -q "Process Creation" "$RESULT_LOG"; then
        grep "Process Creation" "$RESULT_LOG" | grep lps | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ 内核进程管理效率"
    echo "  ✓ 内存分配速度"
    echo "  ✓ COW（写时复制）实现"
    echo "  ✓ 页表复制开销"
    echo ""
    echo "应用场景:"
    echo "  - Shell脚本执行"
    echo "  - CGI程序"
    echo "  - 多进程服务器"
    echo ""

    echo ""
    echo "【Shell Scripts】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - Shell脚本执行性能"
    echo "  - 测试多个并发shell脚本执行"
    echo ""
    echo "测试原理:"
    echo "  - 执行包含多个命令的shell脚本"
    echo "  - 涉及进程创建、文件操作、管道"
    echo "  - 测量每分钟完成次数"
    echo ""
    echo "性能指标:"
    echo "  单位: lpm (loops per minute)"
    echo ""
    echo "典型值（参考）:"
    echo "  1并发:         800 - 2,000 lpm"
    echo "  8并发:       3,000 - 8,000 lpm"
    echo "  16并发:      4,000 - 12,000 lpm"
    echo ""
    echo "实际测试结果:"
    if grep -q "Shell Scripts" "$RESULT_LOG"; then
        grep "Shell Scripts" "$RESULT_LOG" | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ 进程创建速度"
    echo "  ✓ 文件系统性能"
    echo "  ✓ Shell解释器效率（bash/sh）"
    echo "  ✓ CPU和内存性能"
    echo ""
    echo "实际应用:"
    echo "  - 系统脚本（启动脚本、定时任务）"
    echo "  - 自动化部署"
    echo "  - 数据处理流水线"
    echo ""

    echo ""
    echo "【System Call Overhead】"
    echo "----------------------------------------"
    echo ""
    echo "测试内容:"
    echo "  - 系统调用开销"
    echo "  - 用户态/内核态切换成本"
    echo ""
    echo "测试原理:"
    echo "  - 重复调用getpid()系统调用"
    echo "  - getpid()是最简单的系统调用"
    echo "  - 测量每秒调用次数"
    echo ""
    echo "性能指标:"
    echo "  单位: lps (loops per second)"
    echo ""
    echo "典型值（参考）:"
    echo "  无KPTI:        5,000,000 - 15,000,000 lps"
    echo "  启用KPTI:      2,000,000 - 8,000,000 lps"
    echo "  虚拟机:        1,500,000 - 6,000,000 lps"
    echo ""
    echo "实际测试结果:"
    if grep -q "System Call Overhead" "$RESULT_LOG"; then
        grep "System Call Overhead" "$RESULT_LOG" | grep lps | sed 's/^/  /'
    else
        echo "  未找到测试结果"
    fi
    echo ""
    echo "影响因素:"
    echo "  ✓ KPTI（页表隔离）开销"
    echo "  ✓ Spectre/Meltdown缓解措施"
    echo "  ✓ 虚拟化开销"
    echo "  ✓ CPU性能"
    echo ""
    echo "KPTI影响分析:"
    echo "  启用KPTI通常降低性能 40-60%"
    echo "  检查: cat /sys/devices/system/cpu/vulnerabilities/meltdown"
    echo ""

    # ========== 性能指数解读 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "2. 性能指数 (Index Score) 详细解读"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【性能指数说明】"
    echo "----------------------------------------"
    echo ""
    echo "基准系统:"
    echo "  - SPARCstation 20-61 (1995年)"
    echo "  - 双 SuperSPARC 60MHz处理器"
    echo "  - 256MB RAM"
    echo "  - Solaris 2.3操作系统"
    echo "  - 定义为基准值 10.0"
    echo ""
    echo "性能指数计算:"
    echo "  Index = (测试得分 / 基准得分) × 10.0"
    echo ""
    echo "  示例:"
    echo "    如果Dhrystone测试得到 30,000,000 lps"
    echo "    而基准系统得到 116,700 lps"
    echo "    则 Index = (30,000,000 / 116,700) × 10 = 2,570"
    echo ""
    echo "总体性能指数:"
    echo "  - 几何平均数（不是算术平均）"
    echo "  - 权衡所有测试项目"
    echo "  - 单一数值评估整体性能"
    echo ""

    echo "【性能指数等级划分】"
    echo "----------------------------------------"
    echo ""
    echo "                分数范围        性能等级        典型系统"
    echo "                --------        --------        --------"
    echo "  入门级:       < 1,500         ★☆☆☆☆          入门级CPU/虚拟化"
    echo "  一般:       1,500 - 2,500     ★★☆☆☆          普通工作站"
    echo "  良好:       2,500 - 4,000     ★★★☆☆          主流服务器"
    echo "  优秀:       4,000 - 6,000     ★★★★☆          高性能服务器"
    echo "  卓越:       > 6,000           ★★★★★          顶级服务器"
    echo ""

    echo "【实际测试指数】"
    echo "----------------------------------------"
    echo ""
    if grep -q "System Benchmarks Index Score" "$RESULT_LOG"; then
        # 提取单核和多核指数
        SINGLE_CORE=$(grep "System Benchmarks Index Score" "$RESULT_LOG" | head -1 | awk '{print $NF}')
        MULTI_CORE=$(grep "System Benchmarks Index Score" "$RESULT_LOG" | tail -1 | awk '{print $NF}')

        if [[ -n "$SINGLE_CORE" ]]; then
            echo "单核性能指数: $SINGLE_CORE"

            # 性能评级
            if (( $(echo "$SINGLE_CORE > 6000" | bc -l) )); then
                RATING="卓越 ★★★★★"
            elif (( $(echo "$SINGLE_CORE > 4000" | bc -l) )); then
                RATING="优秀 ★★★★☆"
            elif (( $(echo "$SINGLE_CORE > 2500" | bc -l) )); then
                RATING="良好 ★★★☆☆"
            elif (( $(echo "$SINGLE_CORE > 1500" | bc -l) )); then
                RATING="一般 ★★☆☆☆"
            else
                RATING="入门 ★☆☆☆☆"
            fi

            echo "  评级: $RATING"
            echo ""
        fi

        if [[ -n "$MULTI_CORE" ]] && [[ "$MULTI_CORE" != "$SINGLE_CORE" ]]; then
            echo "多核性能指数: $MULTI_CORE"

            if (( $(echo "$MULTI_CORE > 6000" | bc -l) )); then
                RATING="卓越 ★★★★★"
            elif (( $(echo "$MULTI_CORE > 4000" | bc -l) )); then
                RATING="优秀 ★★★★☆"
            elif (( $(echo "$MULTI_CORE > 2500" | bc -l) )); then
                RATING="良好 ★★★☆☆"
            elif (( $(echo "$MULTI_CORE > 1500" | bc -l) )); then
                RATING="一般 ★★☆☆☆"
            else
                RATING="入门 ★☆☆☆☆"
            fi

            echo "  评级: $RATING"
            echo ""

            # 多核加速比
            if [[ -n "$SINGLE_CORE" ]]; then
                SPEEDUP=$(echo "scale=2; $MULTI_CORE / $SINGLE_CORE" | bc)
                echo "多核加速比: ${SPEEDUP}x"

                # 获取CPU核心数
                CPU_CORES=$(grep -c processor /proc/cpuinfo 2>/dev/null || echo "N/A")
                if [[ "$CPU_CORES" != "N/A" ]]; then
                    EFFICIENCY=$(echo "scale=1; ($SPEEDUP / $CPU_CORES) * 100" | bc)
                    echo "  (相对${CPU}核，并行效率: ${EFFICIENCY}%)"
                fi
                echo ""
            fi
        fi
    else
        echo "未找到性能指数"
    fi

    # ========== 性能分析和建议 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "3. 性能分析和优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【性能瓶颈识别】"
    echo "----------------------------------------"
    echo ""
    echo "根据测试结果分析性能瓶颈:"
    echo ""

    # 分析CPU性能
    if grep -q "Dhrystone" "$RESULT_LOG"; then
        DHRY=$(grep "Dhrystone 2" "$RESULT_LOG" | grep lps | awk '{print $(NF-1)}')
        if [[ -n "$DHRY" ]]; then
            if (( $(echo "$DHRY < 15000000" | bc -l) )); then
                echo "⚠️  CPU整数性能偏低 (Dhrystone < 15M lps)"
                echo "    可能原因:"
                echo "      - CPU频率被限制（省电模式）"
                echo "      - 老旧CPU架构"
                echo "      - 虚拟化开销"
                echo "    建议:"
                echo "      cpupower frequency-set -g performance"
                echo ""
            else
                echo "✓  CPU整数性能良好 (Dhrystone: $DHRY lps)"
                echo ""
            fi
        fi
    fi

    # 分析浮点性能
    if grep -q "Whetstone" "$RESULT_LOG"; then
        WHET=$(grep "Double-Precision Whetstone" "$RESULT_LOG" | grep MWIPS | awk '{print $(NF-1)}')
        if [[ -n "$WHET" ]]; then
            if (( $(echo "$WHET < 5000" | bc -l) )); then
                echo "⚠️  CPU浮点性能偏低 (Whetstone < 5000 MWIPS)"
                echo "    可能原因:"
                echo "      - 缺少高级浮点指令集（AVX、FMA）"
                echo "      - FPU性能较弱"
                echo "    影响:"
                echo "      - 科学计算、图形渲染性能受限"
                echo ""
            else
                echo "✓  CPU浮点性能良好 (Whetstone: $WHET MWIPS)"
                echo ""
            fi
        fi
    fi

    # 分析文件系统性能
    if grep -q "File Copy 4096" "$RESULT_LOG"; then
        FCOPY=$(grep "File Copy 4096" "$RESULT_LOG" | grep KBps | awk '{print $(NF-1)}')
        if [[ -n "$FCOPY" ]]; then
            if (( $(echo "$FCOPY < 200000" | bc -l) )); then
                echo "⚠️  文件系统性能偏低 (File Copy 4K < 200MB/s)"
                echo "    可能原因:"
                echo "      - 使用HDD而非SSD"
                echo "      - 文件系统配置不当"
                echo "      - I/O调度器不合适"
                echo "    建议:"
                echo "      - 升级到SSD/NVMe"
                echo "      - 调整I/O调度器"
                echo "      - 检查mount选项（noatime等）"
                echo ""
            else
                echo "✓  文件系统性能良好 (File Copy 4K: $FCOPY KBps)"
                echo ""
            fi
        fi
    fi

    # 分析系统调用性能
    if grep -q "System Call Overhead" "$RESULT_LOG"; then
        SYSCALL=$(grep "System Call Overhead" "$RESULT_LOG" | grep lps | awk '{print $(NF-1)}')
        if [[ -n "$SYSCALL" ]]; then
            if (( $(echo "$SYSCALL < 3000000" | bc -l) )); then
                echo "⚠️  系统调用开销较高 (< 3M lps)"
                echo "    可能原因:"
                echo "      - KPTI开销"
                echo "      - Spectre/Meltdown缓解"
                echo "      - 虚拟化开销"
                echo "    检查:"
                echo "      cat /sys/devices/system/cpu/vulnerabilities/*"
                echo ""
            else
                echo "✓  系统调用性能良好 (System Call: $SYSCALL lps)"
                echo ""
            fi
        fi
    fi

    echo "【优化建议清单】"
    echo "----------------------------------------"
    echo ""
    echo "通用优化:"
    echo "  1. CPU性能模式"
    echo "     sudo cpupower frequency-set -g performance"
    echo ""
    echo "  2. 禁用透明大页（某些场景）"
    echo "     echo never > /sys/kernel/mm/transparent_hugepage/enabled"
    echo ""
    echo "  3. 调整I/O调度器"
    echo "     # SSD/NVMe使用none或mq-deadline"
    echo "     echo none > /sys/block/nvme0n1/queue/scheduler"
    echo ""
    echo "  4. 关闭不必要的服务"
    echo "     systemctl list-unit-files --state=enabled"
    echo ""
    echo "  5. 绑定CPU核心（多核测试）"
    echo "     taskset -c 0-7 ./Run"
    echo ""

    echo "针对性优化:"
    echo ""
    echo "  如果Dhrystone分数低:"
    echo "    - 检查CPU频率: cpupower frequency-info"
    echo "    - 检查turbo boost: cat /sys/devices/system/cpu/intel_pstate/no_turbo"
    echo "    - 禁用节能: systemctl disable power-profiles-daemon"
    echo ""
    echo "  如果File Copy分数低:"
    echo "    - 检查存储类型: lsblk -d -o name,rota"
    echo "    - 优化mount选项: mount -o remount,noatime /"
    echo "    - 增加readahead: blockdev --setra 8192 /dev/sda"
    echo ""
    echo "  如果System Call Overhead低:"
    echo "    - 检查KPTI: cat /proc/cmdline | grep pti"
    echo "    - 考虑禁用KPTI（风险评估）: 内核参数 nopti"
    echo "    - 检查虚拟化: systemd-detect-virt"
    echo ""

    # ========== 对比分析 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "4. 性能对比参考"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【典型系统性能参考】"
    echo "----------------------------------------"
    echo ""
    echo "入门级台式机 (Intel i3-10100):"
    echo "  单核: ~1,800"
    echo "  多核: ~5,500"
    echo ""
    echo "主流台式机 (Intel i5-12400):"
    echo "  单核: ~2,500"
    echo "  多核: ~8,500"
    echo ""
    echo "高性能台式机 (AMD Ryzen 9 5950X):"
    echo "  单核: ~3,200"
    echo "  多核: ~18,000"
    echo ""
    echo "主流服务器 (Intel Xeon Silver 4214):"
    echo "  单核: ~2,200"
    echo "  多核: ~12,000"
    echo ""
    echo "高性能服务器 (Intel Xeon Platinum 8280):"
    echo "  单核: ~2,800"
    echo "  多核: ~25,000"
    echo ""
    echo "ARM服务器 (AWS Graviton3):"
    echo "  单核: ~2,000"
    echo "  多核: ~16,000"
    echo ""

    echo "【虚拟化性能对比】"
    echo "----------------------------------------"
    echo ""
    echo "物理机 vs 虚拟机 (典型性能比):"
    echo "  CPU整数运算: 95-98% (轻微损失)"
    echo "  CPU浮点运算: 95-98%"
    echo "  系统调用: 70-85% (KPTI影响)"
    echo "  进程创建: 60-80% (虚拟化开销)"
    echo "  文件I/O: 50-90% (取决于存储配置)"
    echo "  管道通信: 80-95%"
    echo ""
    echo "容器 vs 物理机:"
    echo "  CPU性能: 98-100% (几乎无损失)"
    echo "  系统调用: 95-100%"
    echo "  I/O性能: 90-100% (取决于存储驱动)"
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
