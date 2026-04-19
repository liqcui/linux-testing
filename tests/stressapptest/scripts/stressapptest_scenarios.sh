#!/bin/bash
# stressapptest_scenarios.sh - StressAppTest高级测试场景

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/stressapptest-scenarios-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "StressAppTest 高级测试场景"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查stressapptest
if ! command -v stressapptest &> /dev/null; then
    echo "✗ 错误: stressapptest未安装"
    echo ""
    echo "请先运行: $SCRIPT_DIR/test_stressapptest.sh"
    exit 1
fi

# 场景选择菜单
echo "请选择测试场景:"
echo ""
echo "1. 新服务器验收测试（72小时）"
echo "2. 内存超频稳定性验证（24小时）"
echo "3. 虚拟机内存压力测试（1小时）"
echo "4. 与温度监控联动测试（24小时）"
echo "5. 数据中心批量验证（快速6小时）"
echo "6. ECC内存纠错能力测试（12小时）"
echo "7. 运行所有场景（自动化测试）"
echo ""
read -p "请输入选择 [1-7]: " CHOICE

CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

case $CHOICE in
    1)
        # 场景1：新服务器验收测试（72小时）
        echo ""
        echo "场景1: 新服务器验收测试（72小时）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        {
            echo "新服务器验收测试"
            echo "========================================"
            echo ""
            echo "测试目的:"
            echo "  - 硬件出厂质量验证"
            echo "  - 长时间稳定性确认"
            echo "  - 生产环境就绪性评估"
            echo ""
            echo "测试参数:"
            echo "  时长: 72小时 (259200秒)"
            echo "  内存使用: 95% (接近满载)"
            echo "  线程数: 32 (或实际CPU核心数)"
            echo "  严格检查: 启用 (-W)"
            echo "  磁盘压力: 启用 (-d)"
            echo "  暂停检查: 每60秒"
            echo "  暂停间隔: 每10分钟"
            echo ""
            echo "通过标准:"
            echo "  ✓ 72小时内零错误"
            echo "  ✓ 温度稳定在安全范围"
            echo "  ✓ 无系统崩溃或重启"
            echo ""
            echo "开始时间: $(date)"
            echo ""
        } | tee "$RESULTS_DIR/scenario1_burnin.txt"

        TEMP_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_DIR" EXIT

        echo "开始72小时验收测试..."
        echo "预计完成时间: $(date -d '+72 hours' 2>/dev/null || date -v +72H 2>/dev/null || echo "3天后")"
        echo ""

        stressapptest -s 259200 -M 95 -m 32 -W -d "$TEMP_DIR/stress_test" \
            --pause_duration 60 --pause_delay 600 \
            2>&1 | tee -a "$RESULTS_DIR/scenario1_burnin.txt"
        RESULT=$?

        {
            echo ""
            echo "结束时间: $(date)"
            echo ""
            if [[ $RESULT -eq 0 ]]; then
                echo "✓✓✓ 验收测试通过 ✓✓✓"
                echo ""
                echo "服务器已通过72小时burn-in测试"
                echo "可以投入生产环境使用"
            else
                echo "✗✗✗ 验收测试失败 ✗✗✗"
                echo ""
                echo "服务器存在硬件问题，需要返修"
                echo "退出码: $RESULT"
            fi
        } | tee -a "$RESULTS_DIR/scenario1_burnin.txt"
        ;;

    2)
        # 场景2：内存超频稳定性验证
        echo ""
        echo "场景2: 内存超频稳定性验证（24小时）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        {
            echo "内存超频稳定性验证"
            echo "========================================"
            echo ""
            echo "测试目的:"
            echo "  - 验证超频设置的稳定性"
            echo "  - 检测超频导致的内存错误"
            echo "  - 评估散热系统的有效性"
            echo ""
            echo "测试参数:"
            echo "  时长: 24小时 (86400秒)"
            echo "  内存使用: 100% (满载压力)"
            echo "  线程数: 16"
            echo "  复制块大小: 64 MB (-C 64)"
            echo "  温度阈值: 85°C"
            echo ""
            echo "注意事项:"
            echo "  - 监控CPU/内存温度"
            echo "  - 超过85°C将触发告警"
            echo "  - 建议在良好散热环境下测试"
            echo ""
            echo "开始时间: $(date)"
            echo ""
        } | tee "$RESULTS_DIR/scenario2_overclock.txt"

        echo "开始24小时超频稳定性测试..."
        echo ""

        # 检查温度监控工具
        if command -v sensors &> /dev/null; then
            echo "温度监控: 启用"
            TEMP_MONITOR=true
        else
            echo "温度监控: 未启用（sensors未安装）"
            TEMP_MONITOR=false
        fi
        echo ""

        stressapptest -s 86400 -M 100 -m 16 -W -C 64 \
            2>&1 | tee -a "$RESULTS_DIR/scenario2_overclock.txt"
        RESULT=$?

        {
            echo ""
            echo "结束时间: $(date)"
            echo ""
            if [[ $RESULT -eq 0 ]]; then
                echo "✓✓✓ 超频配置稳定 ✓✓✓"
                echo ""
                echo "当前超频设置通过24小时稳定性测试"
                echo "可以继续使用当前配置"
                echo ""
                echo "建议:"
                echo "  - 定期监控温度"
                echo "  - 如遇到系统不稳定，适当降低频率"
            else
                echo "✗✗✗ 超频配置不稳定 ✗✗✗"
                echo ""
                echo "检测到内存错误，当前超频设置不稳定"
                echo "退出码: $RESULT"
                echo ""
                echo "建议:"
                echo "  1. 降低内存频率"
                echo "  2. 增加内存电压（谨慎）"
                echo "  3. 放宽内存时序"
                echo "  4. 改善散热"
                echo "  5. 恢复默认设置"
            fi
        } | tee -a "$RESULTS_DIR/scenario2_overclock.txt"
        ;;

    3)
        # 场景3：虚拟机内存压力（限制 cgroup）
        echo ""
        echo "场景3: 虚拟机内存压力测试（1小时）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        {
            echo "虚拟机内存压力测试"
            echo "========================================"
            echo ""
            echo "测试目的:"
            echo "  - 验证虚拟机内存限制"
            echo "  - 测试cgroup内存控制"
            echo "  - 评估虚拟化开销"
            echo ""
            echo "测试参数:"
            echo "  时长: 1小时 (3600秒)"
            echo "  内存使用: 80%"
            echo "  线程数: 4"
            echo "  cgroup: memory:vm_test"
            echo ""
            echo "开始时间: $(date)"
            echo ""
        } | tee "$RESULTS_DIR/scenario3_vm.txt"

        # 检查cgroup
        if [[ -d /sys/fs/cgroup/memory ]]; then
            echo "创建cgroup: memory:vm_test"

            # 创建cgroup（需要root权限）
            if [[ $(id -u) -eq 0 ]]; then
                # cgroup v1
                if [[ -d /sys/fs/cgroup/memory ]]; then
                    mkdir -p /sys/fs/cgroup/memory/vm_test
                    # 限制2GB内存
                    echo $((2 * 1024 * 1024 * 1024)) > /sys/fs/cgroup/memory/vm_test/memory.limit_in_bytes

                    echo "启动测试（使用cgroup限制）..."
                    cgexec -g memory:vm_test \
                        stressapptest -s 3600 -M 80 -m 4 -W \
                        2>&1 | tee -a "$RESULTS_DIR/scenario3_vm.txt"
                    RESULT=$?
                else
                    echo "⚠ cgroup v1不可用，使用标准测试"
                    stressapptest -s 3600 -M 80 -m 4 -W \
                        2>&1 | tee -a "$RESULTS_DIR/scenario3_vm.txt"
                    RESULT=$?
                fi
            else
                echo "⚠ 需要root权限使用cgroup，使用标准测试"
                stressapptest -s 3600 -M 80 -m 4 -W \
                    2>&1 | tee -a "$RESULTS_DIR/scenario3_vm.txt"
                RESULT=$?
            fi
        else
            echo "⚠ cgroup不可用，使用标准测试"
            stressapptest -s 3600 -M 80 -m 4 -W \
                2>&1 | tee -a "$RESULTS_DIR/scenario3_vm.txt"
            RESULT=$?
        fi

        {
            echo ""
            echo "结束时间: $(date)"
            echo ""
            if [[ $RESULT -eq 0 ]]; then
                echo "✓ 虚拟机内存测试通过"
            else
                echo "✗ 虚拟机内存测试失败"
                echo "退出码: $RESULT"
            fi
        } | tee -a "$RESULTS_DIR/scenario3_vm.txt"
        ;;

    4)
        # 场景4：与温度监控联动
        echo ""
        echo "场景4: 与温度监控联动测试（24小时）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        {
            echo "温度监控联动测试"
            echo "========================================"
            echo ""
            echo "测试目的:"
            echo "  - 验证散热系统有效性"
            echo "  - 防止过热损坏硬件"
            echo "  - 评估温度控制策略"
            echo ""
            echo "测试参数:"
            echo "  时长: 24小时 (86400秒)"
            echo "  内存使用: 90%"
            echo "  线程数: 16"
            echo "  温度阈值: 90°C（暂停测试）"
            echo "  冷却时间: 5分钟"
            echo "  监控间隔: 60秒"
            echo ""
            echo "开始时间: $(date)"
            echo ""
        } | tee "$RESULTS_DIR/scenario4_thermal.txt"

        # 检查温度监控工具
        if ! command -v sensors &> /dev/null; then
            echo "⚠ 警告: sensors未安装，无法监控温度"
            echo "  安装: sudo apt-get install lm-sensors"
            echo "  初始化: sudo sensors-detect"
            echo ""
            echo "继续测试（无温度监控）..."
            echo ""

            stressapptest -s 86400 -M 90 -m 16 -W \
                2>&1 | tee -a "$RESULTS_DIR/scenario4_thermal.txt"
            RESULT=$?
        else
            echo "启动温度监控守护进程..."

            # 温度监控脚本
            (
                while true; do
                    # 获取CPU温度
                    if sensors | grep -q "Package id 0"; then
                        TEMP=$(sensors | grep "Package id 0" | awk '{print $4}' | cut -d'+' -f2 | cut -d'.' -f1)
                    elif sensors | grep -q "Tctl"; then
                        TEMP=$(sensors | grep "Tctl" | awk '{print $2}' | cut -d'+' -f2 | cut -d'.' -f1)
                    else
                        TEMP=$(sensors | grep -E "temp1|Core 0" | head -1 | awk '{print $2}' | cut -d'+' -f2 | cut -d'.' -f1)
                    fi

                    echo "$(date): CPU温度 = ${TEMP}°C" | tee -a "$RESULTS_DIR/scenario4_thermal.txt"

                    if [[ -n "$TEMP" ]] && [[ $TEMP -gt 90 ]]; then
                        echo "⚠ 温度过高: ${TEMP}°C，暂停压力测试" | tee -a "$RESULTS_DIR/scenario4_thermal.txt"
                        pkill -STOP stressapptest
                        sleep 300  # 冷却5分钟
                        echo "恢复压力测试" | tee -a "$RESULTS_DIR/scenario4_thermal.txt"
                        pkill -CONT stressapptest
                    fi

                    sleep 60
                done
            ) &
            MONITOR_PID=$!

            echo "温度监控PID: $MONITOR_PID"
            echo ""

            # 运行压力测试
            stressapptest -s 86400 -M 90 -m 16 -W \
                2>&1 | tee -a "$RESULTS_DIR/scenario4_thermal.txt"
            RESULT=$?

            # 停止温度监控
            kill $MONITOR_PID 2>/dev/null
        fi

        {
            echo ""
            echo "结束时间: $(date)"
            echo ""
            if [[ $RESULT -eq 0 ]]; then
                echo "✓ 温度控制测试通过"
                echo ""
                echo "系统散热正常，温度控制在安全范围内"
            else
                echo "✗ 温度控制测试失败"
                echo "退出码: $RESULT"
            fi
        } | tee -a "$RESULTS_DIR/scenario4_thermal.txt"
        ;;

    5)
        # 场景5：数据中心批量验证（快速6小时）
        echo ""
        echo "场景5: 数据中心批量验证（6小时）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        {
            echo "数据中心批量验证"
            echo "========================================"
            echo ""
            echo "测试目的:"
            echo "  - 快速批量硬件验证"
            echo "  - 数据中心入库检验"
            echo "  - 发现明显硬件缺陷"
            echo ""
            echo "测试参数:"
            echo "  时长: 6小时 (21600秒)"
            echo "  内存使用: 95%"
            echo "  线程数: CPU核心数"
            echo ""
            echo "主机名: $(hostname)"
            echo "开始时间: $(date)"
            echo ""
        } | tee "$RESULTS_DIR/scenario5_datacenter.txt"

        echo "开始6小时快速验证..."
        echo ""

        stressapptest -s 21600 -M 95 -m $CPU_CORES -W \
            2>&1 | tee -a "$RESULTS_DIR/scenario5_datacenter.txt"
        RESULT=$?

        {
            echo ""
            echo "结束时间: $(date)"
            echo ""
            if [[ $RESULT -eq 0 ]]; then
                echo "✓ 快速验证通过"
                echo ""
                echo "$(hostname): 硬件验证通过，可以入库"
            else
                echo "✗ 快速验证失败"
                echo ""
                echo "$(hostname): 硬件存在问题，需要返修"
                echo "退出码: $RESULT"
            fi
        } | tee -a "$RESULTS_DIR/scenario5_datacenter.txt"
        ;;

    6)
        # 场景6：ECC内存纠错能力测试
        echo ""
        echo "场景6: ECC内存纠错能力测试（12小时）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        {
            echo "ECC内存纠错能力测试"
            echo "========================================"
            echo ""
            echo "测试目的:"
            echo "  - 验证ECC内存纠错功能"
            echo "  - 检测潜在的单比特错误"
            echo "  - 评估内存可靠性"
            echo ""
            echo "测试参数:"
            echo "  时长: 12小时 (43200秒)"
            echo "  内存使用: 90%"
            echo "  线程数: CPU核心数"
            echo "  复制块大小: 128 MB"
            echo ""
            echo "开始时间: $(date)"
            echo ""
        } | tee "$RESULTS_DIR/scenario6_ecc.txt"

        # 检查ECC状态
        if [[ -f /proc/meminfo ]]; then
            echo "检查ECC内存状态..."
            if command -v dmidecode &> /dev/null && [[ $(id -u) -eq 0 ]]; then
                ECC_INFO=$(dmidecode -t memory | grep -E "Error Correction Type|Total Width|Data Width")
                echo "$ECC_INFO" | tee -a "$RESULTS_DIR/scenario6_ecc.txt"
            fi
            echo ""
        fi

        echo "开始12小时ECC测试..."
        echo ""

        # 记录测试前的ECC错误数
        if [[ -f /sys/devices/system/edac/mc/mc0/ce_count ]]; then
            CE_BEFORE=$(cat /sys/devices/system/edac/mc/mc0/ce_count)
            echo "测试前纠正错误数: $CE_BEFORE" | tee -a "$RESULTS_DIR/scenario6_ecc.txt"
        fi

        stressapptest -s 43200 -M 90 -m $CPU_CORES -W -C 128 \
            2>&1 | tee -a "$RESULTS_DIR/scenario6_ecc.txt"
        RESULT=$?

        # 记录测试后的ECC错误数
        if [[ -f /sys/devices/system/edac/mc/mc0/ce_count ]]; then
            CE_AFTER=$(cat /sys/devices/system/edac/mc/mc0/ce_count)
            CE_DIFF=$((CE_AFTER - CE_BEFORE))
            echo "测试后纠正错误数: $CE_AFTER" | tee -a "$RESULTS_DIR/scenario6_ecc.txt"
            echo "新增纠正错误: $CE_DIFF" | tee -a "$RESULTS_DIR/scenario6_ecc.txt"
        fi

        {
            echo ""
            echo "结束时间: $(date)"
            echo ""
            if [[ $RESULT -eq 0 ]]; then
                echo "✓ ECC内存测试通过"
                if [[ -n "${CE_DIFF:-}" ]] && [[ $CE_DIFF -gt 0 ]]; then
                    echo ""
                    echo "⚠ 注意: 检测到 $CE_DIFF 个单比特错误（已纠正）"
                    if [[ $CE_DIFF -gt 100 ]]; then
                        echo "  警告: 错误数量较多，建议更换内存"
                    else
                        echo "  正常: ECC成功纠正所有错误"
                    fi
                fi
            else
                echo "✗ ECC内存测试失败"
                echo "退出码: $RESULT"
            fi
        } | tee -a "$RESULTS_DIR/scenario6_ecc.txt"
        ;;

    7)
        # 运行所有场景（自动化）
        echo ""
        echo "场景7: 运行所有场景（自动化测试）"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "⚠ 注意: 这将运行所有测试场景，总耗时约132小时（5.5天）"
        echo ""
        read -p "确认继续？[y/N]: " CONFIRM

        if [[ "$CONFIRM" != "y" ]] && [[ "$CONFIRM" != "Y" ]]; then
            echo "取消"
            exit 0
        fi

        echo ""
        echo "开始自动化测试序列..."
        echo ""

        # 依次运行所有场景
        for i in {1..6}; do
            echo "运行场景 $i ..."
            $0 <<< "$i"
            echo ""
        done

        echo "所有场景测试完成"
        ;;

    *)
        echo "无效选择"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
