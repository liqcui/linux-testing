#!/bin/bash
# cachestat 测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         cachestat - 页缓存统计测试                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此测试需要 root 权限"
    echo "请使用: sudo $0"
    exit 1
fi

# 检查 Python BCC 绑定
if ! python3 -c "import bcc" 2>/dev/null; then
    echo "错误: Python BCC 绑定未安装"
    echo ""
    echo "安装方法:"
    echo "  RHEL/Fedora: sudo dnf install python3-bcc"
    echo "  Ubuntu/Debian: sudo apt-get install python3-bpfcc"
    exit 1
fi

# 使用我们的兼容版本
CACHESTAT="$SCRIPT_DIR/cachestat_wrapper.py"

if [[ ! -f "$CACHESTAT" ]]; then
    echo "错误: cachestat_wrapper.py 不存在"
    exit 1
fi

chmod +x "$CACHESTAT"

echo "========================================="
echo "内核兼容性检查"
echo "========================================="
echo ""

echo "检测内核函数支持..."
KERNEL_VER=$(uname -r)
echo "内核版本: $KERNEL_VER"
echo ""

# 检查关键内核函数
check_func() {
    local func="$1"
    if grep -qw "$func" /proc/kallsyms 2>/dev/null; then
        echo "  ✓ $func"
        return 0
    else
        echo "  ✗ $func (不存在)"
        return 1
    fi
}

echo "检查页缓存相关函数:"
check_func "add_to_page_cache_lru"
check_func "mark_page_accessed"

echo ""
echo "检查脏页跟踪函数:"
HAS_DIRTY=0
if check_func "folio_account_dirtied"; then
    HAS_DIRTY=1
    DIRTY_FUNC="folio_account_dirtied"
elif check_func "account_page_dirtied"; then
    HAS_DIRTY=1
    DIRTY_FUNC="account_page_dirtied"
elif check_func "__set_page_dirty"; then
    HAS_DIRTY=1
    DIRTY_FUNC="__set_page_dirty"
else
    echo "  警告: 未找到脏页跟踪函数"
fi

echo ""

echo "========================================="
echo "1. 基本使用 - 页缓存统计"
echo "========================================="
echo ""

echo "说明: 实时显示页缓存的命中、未命中和脏页统计"
echo ""
echo "字段说明:"
echo "  HITS    - 页缓存命中（数据在内存中）"
echo "  MISSES  - 页缓存未命中（需要从磁盘读取）"
echo "  DIRTIES - 脏页数量（被修改未写入磁盘）"
echo "  HIT_RATE - 命中率百分比（越高越好）"
echo ""

echo "启动 cachestat（10秒）..."
echo ""

# 后台运行 cachestat
timeout 10 python3 "$CACHESTAT" 1 > /tmp/cachestat_basic.txt 2>&1 &
STAT_PID=$!

# 等待启动
sleep 2

# 生成页缓存活动
echo "生成测试数据..."
echo ""

# 场景1: 缓存命中 - 多次读取同一文件
echo "场景1: 读取同一文件（应该看到 HITS 增加）"
TEST_FILE="/tmp/cachestat_test_$(date +%s).dat"
dd if=/dev/zero of="$TEST_FILE" bs=1M count=10 2>/dev/null
for i in {1..3}; do
    cat "$TEST_FILE" > /dev/null
    sleep 0.5
done
echo ""

# 场景2: 缓存未命中 - 清除缓存后读取
echo "场景2: 清除缓存后读取（应该看到 MISSES 增加）"
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo "  (需要 root 权限清除缓存)"
cat "$TEST_FILE" > /dev/null
sleep 1
echo ""

# 场景3: 脏页 - 写入数据
echo "场景3: 写入数据（应该看到 DIRTIES 增加）"
dd if=/dev/zero of="$TEST_FILE" bs=1M count=5 conv=notrunc 2>/dev/null
sleep 1
echo ""

# 等待 cachestat 完成
wait $STAT_PID 2>/dev/null

echo "========================================="
echo "结果分析"
echo "========================================="
echo ""

cat /tmp/cachestat_basic.txt
echo ""

echo "========================================="
echo "2. 详细模式"
echo "========================================="
echo ""

echo "使用 -v 选项查看内核函数检测详情"
echo ""

python3 "$CACHESTAT" -v 1 1 2>&1 | head -20
echo ""

echo "========================================="
echo "3. 实际应用场景"
echo "========================================="
echo ""

echo "场景1: 诊断 I/O 性能问题"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "命中率低 (<50%) 表示:"
echo "  - 应用程序的数据访问模式不友好"
echo "  - 内存不足，无法缓存足够数据"
echo "  - 需要增加系统内存或优化应用"
echo ""

echo "场景2: 监控文件系统性能"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "示例: 数据库性能调优"
echo "  sudo cachestat 5"
echo ""
echo "观察:"
echo "  - 高 HITS: 数据库工作集在内存中"
echo "  - 高 MISSES: 需要更多内存或优化查询"
echo "  - 高 DIRTIES: 写入密集，考虑调整刷盘策略"
echo ""

echo "场景3: 对比缓存策略"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "测试不同的应用配置对缓存的影响"
echo ""
echo "示例:"
echo "  # 运行 cachestat"
echo "  sudo cachestat 1 > baseline.txt &"
echo ""
echo "  # 运行应用测试"
echo "  ./run_application"
echo ""
echo "  # 分析缓存行为"
echo "  pkill cachestat"
echo "  cat baseline.txt"
echo ""

echo "场景4: 系统调优验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "调整内核参数后验证效果"
echo ""
echo "示例:"
echo "  # 调整 vm.vfs_cache_pressure"
echo "  sudo sysctl -w vm.vfs_cache_pressure=50"
echo ""
echo "  # 监控缓存行为变化"
echo "  sudo cachestat 1"
echo ""

echo "========================================="
echo "性能基准"
echo "========================================="
echo ""
echo "典型命中率参考:"
echo "  - 数据库服务器: 90-99%（工作集在内存）"
echo "  - 文件服务器: 70-90%（常用文件缓存）"
echo "  - 备份任务: 10-30%（顺序扫描大文件）"
echo "  - 编译任务: 50-70%（混合读写）"
echo ""

echo "========================================="
echo "故障排查"
echo "========================================="
echo ""

if [[ $HAS_DIRTY -eq 0 ]]; then
    echo "⚠ 脏页跟踪功能不可用"
    echo ""
    echo "原因:"
    echo "  - 内核版本可能不支持跟踪的函数"
    echo "  - 函数名在您的内核中已更改"
    echo ""
    echo "影响:"
    echo "  - DIRTIES 列将始终为 0"
    echo "  - HITS 和 MISSES 统计不受影响"
    echo ""
    echo "解决方法:"
    echo "  - 升级到较新内核（推荐 >= 4.9）"
    echo "  - 使用其他工具监控脏页: cat /proc/meminfo | grep Dirty"
else
    echo "✓ 所有功能正常"
    echo "  使用的脏页函数: $DIRTY_FUNC"
fi
echo ""

echo "========================================="
echo "总结"
echo "========================================="
echo ""
echo "✓ cachestat 提供实时页缓存统计"
echo "✓ 帮助诊断 I/O 性能问题"
echo "✓ 命中率是衡量缓存效率的关键指标"
echo "✓ 兼容版本支持多种内核版本"
echo ""

# 清理
rm -f "$TEST_FILE"
rm -f /tmp/cachestat_*.txt

echo "测试完成！"
echo ""
echo "更多信息:"
echo "  - 原始工具: /usr/share/bcc/tools/cachestat"
echo "  - 兼容版本: $CACHESTAT"
echo "  - BCC 文档: https://github.com/iovisor/bcc"
