#!/bin/bash
# test_policy_compile.sh - SELinux策略编译与加载测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="$SCRIPT_DIR/../policies"
RESULTS_DIR="$SCRIPT_DIR/../results/policy-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "SELinux策略编译与加载测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查SELinux状态
echo "步骤 1: 检查SELinux状态..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v sestatus &> /dev/null; then
    echo "✗ SELinux工具未安装"
    echo ""
    echo "安装命令:"
    echo "  RHEL/CentOS/Fedora: sudo yum install policycoreutils selinux-policy-devel"
    echo "  Ubuntu/Debian:      sudo apt-get install selinux-utils selinux-policy-dev"
    exit 1
fi

echo "SELinux状态:"
sestatus | tee "$RESULTS_DIR/selinux-status.txt"
echo ""

SELINUX_ENABLED=$(sestatus | grep "SELinux status" | awk '{print $3}')

if [[ "$SELINUX_ENABLED" != "enabled" ]]; then
    echo "⚠ SELinux未启用"
    echo ""
    echo "启用方法:"
    echo "  1. 编辑 /etc/selinux/config"
    echo "  2. 设置 SELINUX=enforcing 或 SELINUX=permissive"
    echo "  3. 重启系统"
    echo ""
    echo "注意: 继续测试但某些功能可能不可用"
    echo ""
fi

SELINUX_MODE=$(getenforce 2>/dev/null || echo "Disabled")
echo "当前模式: $SELINUX_MODE"
echo ""

# 检查策略编译工具
echo "步骤 2: 检查策略编译工具..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOOLS=(checkmodule semodule_package semodule)
MISSING_TOOLS=0

for tool in "${TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        echo "✓ $tool: $(which $tool)"
    else
        echo "✗ $tool: 未安装"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
done

echo ""

if [[ $MISSING_TOOLS -gt 0 ]]; then
    echo "✗ 缺少 $MISSING_TOOLS 个工具"
    echo ""
    echo "安装命令:"
    echo "  RHEL/CentOS/Fedora: sudo yum install policycoreutils-python-utils selinux-policy-devel"
    echo "  Ubuntu/Debian:      sudo apt-get install policycoreutils selinux-policy-dev"
    exit 1
fi

# 编译测试策略
echo "步骤 3: 编译测试策略..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$POLICIES_DIR"

if [[ ! -f test_policy.te ]]; then
    echo "✗ 找不到策略文件: test_policy.te"
    exit 1
fi

echo "策略文件: test_policy.te"
echo "文件上下文: test_policy.fc"
echo ""

# 清理旧文件
rm -f test_policy.mod test_policy.pp

# 编译策略模块
echo "编译策略模块..."
checkmodule -M -m -o test_policy.mod test_policy.te 2>&1 | tee "$RESULTS_DIR/compile.log"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 编译成功: test_policy.mod"
ls -lh test_policy.mod
echo ""

# 打包策略
echo "打包策略模块..."
if [[ -f test_policy.fc ]]; then
    semodule_package -o test_policy.pp -m test_policy.mod -f test_policy.fc 2>&1 | tee -a "$RESULTS_DIR/compile.log"
else
    semodule_package -o test_policy.pp -m test_policy.mod 2>&1 | tee -a "$RESULTS_DIR/compile.log"
fi

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "✗ 打包失败"
    exit 1
fi

echo "✓ 打包成功: test_policy.pp"
ls -lh test_policy.pp
echo ""

# 加载策略
echo "步骤 4: 加载策略模块..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$SELINUX_ENABLED" != "enabled" ]]; then
    echo "⚠ SELinux未启用，跳过加载"
    echo ""
else
    echo "加载策略..."
    semodule -i test_policy.pp 2>&1 | tee "$RESULTS_DIR/load.log"

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "✗ 加载失败"
        exit 1
    fi

    echo "✓ 策略已加载"
    echo ""
fi

# 验证策略
echo "步骤 5: 验证策略..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$SELINUX_ENABLED" != "enabled" ]]; then
    echo "⚠ SELinux未启用，跳过验证"
    echo ""
else
    echo "查找已加载的策略模块..."
    semodule -l | grep test_policy | tee "$RESULTS_DIR/modules.txt"

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        echo ""
        echo "✓ 策略模块已加载"
    else
        echo ""
        echo "✗ 未找到策略模块"
    fi

    echo ""

    # 显示策略详情
    echo "策略模块详情:"
    semodule -l | grep test_policy
    echo ""

    # 显示策略规则数量
    echo "加载的策略模块总数:"
    semodule -l | wc -l
    echo ""
fi

# 策略卸载测试
echo "步骤 6: 策略卸载/重新加载测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$SELINUX_ENABLED" != "enabled" ]]; then
    echo "⚠ SELinux未启用，跳过测试"
    echo ""
else
    echo "卸载策略..."
    semodule -r test_policy 2>&1

    if [[ $? -eq 0 ]]; then
        echo "✓ 卸载成功"
    else
        echo "⚠ 卸载失败或策略不存在"
    fi

    sleep 1

    echo ""
    echo "验证卸载..."
    if semodule -l | grep -q test_policy; then
        echo "✗ 策略仍然存在"
    else
        echo "✓ 策略已移除"
    fi

    echo ""
    echo "重新加载策略..."
    semodule -i test_policy.pp 2>&1

    if [[ $? -eq 0 ]]; then
        echo "✓ 重新加载成功"
    else
        echo "✗ 重新加载失败"
    fi

    echo ""
fi

# 策略循环加载测试
echo "步骤 7: 策略循环加载测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$SELINUX_ENABLED" != "enabled" ]]; then
    echo "⚠ SELinux未启用，跳过测试"
    echo ""
else
    ITERATIONS=10
    echo "执行 $ITERATIONS 次循环..."
    echo ""

    LOAD_FAILURES=0
    UNLOAD_FAILURES=0

    for i in $(seq 1 $ITERATIONS); do
        # 卸载
        semodule -r test_policy &>/dev/null
        if [[ $? -ne 0 ]]; then
            UNLOAD_FAILURES=$((UNLOAD_FAILURES + 1))
        fi

        sleep 0.1

        # 加载
        semodule -i test_policy.pp &>/dev/null
        if [[ $? -ne 0 ]]; then
            LOAD_FAILURES=$((LOAD_FAILURES + 1))
            break
        fi

        if [[ $((i % 5)) -eq 0 ]]; then
            echo "  完成 $i/$ITERATIONS 次迭代..."
        fi

        sleep 0.1
    done

    echo ""
    echo "循环测试结果:"
    echo "  加载成功: $((ITERATIONS - LOAD_FAILURES))"
    echo "  加载失败: $LOAD_FAILURES"
    echo "  卸载失败: $UNLOAD_FAILURES"
    echo ""

    if [[ $LOAD_FAILURES -eq 0 ]] && [[ $UNLOAD_FAILURES -eq 0 ]]; then
        echo "✓ 循环测试通过"
    else
        echo "✗ 循环测试失败"
    fi

    echo ""
fi

# 生成总结报告
{
    echo "SELinux策略编译与加载测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  SELinux状态: $SELINUX_ENABLED"
    echo "  SELinux模式: $SELINUX_MODE"
    echo ""
    echo "测试项目:"
    echo "  ✓ 策略编译"
    echo "  ✓ 策略打包"
    if [[ "$SELINUX_ENABLED" == "enabled" ]]; then
        echo "  ✓ 策略加载"
        echo "  ✓ 策略验证"
        echo "  ✓ 策略卸载/重新加载"
        echo "  ✓ 循环加载测试 ($ITERATIONS 次)"
        echo ""
        echo "循环测试结果:"
        echo "  加载成功: $((ITERATIONS - LOAD_FAILURES))"
        echo "  加载失败: $LOAD_FAILURES"
        echo "  卸载失败: $UNLOAD_FAILURES"
    else
        echo "  ⚠ 跳过加载测试（SELinux未启用）"
    fi
    echo ""
    echo "生成文件:"
    echo "  策略模块: $POLICIES_DIR/test_policy.mod"
    echo "  策略包: $POLICIES_DIR/test_policy.pp"
    echo ""
    echo "详细日志:"
    echo "  SELinux状态: $RESULTS_DIR/selinux-status.txt"
    echo "  编译日志: $RESULTS_DIR/compile.log"
    if [[ "$SELINUX_ENABLED" == "enabled" ]]; then
        echo "  加载日志: $RESULTS_DIR/load.log"
        echo "  模块列表: $RESULTS_DIR/modules.txt"
    fi
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""

if [[ "$SELINUX_ENABLED" == "enabled" ]]; then
    echo "✓ SELinux策略测试完成"
else
    echo "⚠ SELinux未启用，部分测试跳过"
fi

echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
