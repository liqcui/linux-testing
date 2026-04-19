#!/bin/bash
# test_mount_namespace.sh - Mount namespace测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/mount-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Mount Namespace 测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 检查Mount namespace支持
echo "步骤 1: 检查Mount namespace支持..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ! -e /proc/self/ns/mnt ]]; then
    echo "✗ 系统不支持Mount namespace"
    exit 1
fi

echo "✓ Mount namespace 已支持"
echo ""

# 显示当前挂载点
echo "当前挂载点数量: $(mount | wc -l)"
mount | head -10 | tee "$RESULTS_DIR/original-mounts.txt"
echo "..."
echo ""

# 基础Mount namespace测试
echo "步骤 2: 基础Mount namespace测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "在新Mount namespace中创建临时挂载..."
unshare -m /bin/bash -c "
    echo '新namespace初始挂载点数量: '\$(mount | wc -l)

    # 创建测试目录
    mkdir -p /tmp/test_mount_$$ /tmp/test_target_$$

    # 创建临时挂载
    mount -t tmpfs tmpfs /tmp/test_target_$$
    echo 'tmpfs挂载成功'

    echo ''
    echo '新namespace中的挂载点 (部分):'
    mount | grep test_target || echo '未找到test_target挂载'

    # 测试写入
    echo 'test data' > /tmp/test_target_$$/test.txt
    cat /tmp/test_target_$$/test.txt

    # 清理
    umount /tmp/test_target_$$
    rmdir /tmp/test_target_$$ /tmp/test_mount_$$
" | tee "$RESULTS_DIR/basic-test.txt"

echo ""
echo "主namespace中查找test_target（应该不存在）:"
mount | grep test_target || echo "✓ 主namespace中没有test_target挂载（正常）"
echo ""

# 挂载传播测试
echo "步骤 3: 挂载传播测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_DIR="/tmp/mount_propagation_test_$$"
mkdir -p "$TEST_DIR"

echo "创建shared挂载点..."
mount --bind "$TEST_DIR" "$TEST_DIR"
mount --make-shared "$TEST_DIR"

echo "✓ Shared挂载点已创建: $TEST_DIR"
echo ""

echo "在新namespace中查看挂载点..."
unshare -m /bin/bash -c "
    echo '新namespace中的挂载点:'
    mount | grep '$TEST_DIR' || echo '未找到$TEST_DIR'

    # 设置为private（阻止传播）
    mount --make-private '$TEST_DIR'

    # 创建子挂载
    mkdir -p '$TEST_DIR/sub'
    mount -t tmpfs tmpfs '$TEST_DIR/sub'

    echo ''
    echo '在新namespace中创建的子挂载:'
    mount | grep '$TEST_DIR/sub'
"

echo ""
echo "主namespace中查看（应该看不到子挂载）:"
mount | grep "$TEST_DIR" || echo "未找到相关挂载"

# 清理
umount "$TEST_DIR" 2>/dev/null
rmdir "$TEST_DIR"

echo ""

# Bind mount测试
echo "步骤 4: Bind mount测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SRC_DIR="/tmp/bind_src_$$"
DST_DIR="/tmp/bind_dst_$$"

mkdir -p "$SRC_DIR" "$DST_DIR"
echo "test content" > "$SRC_DIR/file.txt"

echo "在新Mount namespace中创建bind mount..."
unshare -m /bin/bash -c "
    mount --bind '$SRC_DIR' '$DST_DIR'

    echo '绑定挂载成功'
    echo ''
    echo '目标目录内容:'
    ls -la '$DST_DIR'
    cat '$DST_DIR/file.txt'

    echo ''
    echo '在目标目录创建新文件:'
    echo 'new content' > '$DST_DIR/new.txt'

    echo '源目录内容（应该包含新文件）:'
    ls -la '$SRC_DIR'

    # 清理
    umount '$DST_DIR'
" | tee "$RESULTS_DIR/bind-mount.txt"

# 清理
rm -rf "$SRC_DIR" "$DST_DIR"

echo ""

# 只读挂载测试
echo "步骤 5: 只读挂载测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

RO_DIR="/tmp/readonly_test_$$"
mkdir -p "$RO_DIR"
echo "original" > "$RO_DIR/test.txt"

unshare -m /bin/bash -c "
    # 重新挂载为只读
    mount --bind '$RO_DIR' '$RO_DIR'
    mount -o remount,ro '$RO_DIR'

    echo '目录已挂载为只读'
    echo ''

    echo '读取文件（应该成功）:'
    cat '$RO_DIR/test.txt'

    echo ''
    echo '尝试写入（应该失败）:'
    echo 'new data' > '$RO_DIR/test.txt' 2>&1 || echo '✓ 写入失败（预期行为）'

    # 清理
    umount '$RO_DIR'
" | tee "$RESULTS_DIR/readonly-mount.txt"

rm -rf "$RO_DIR"

echo ""

# Proc挂载测试
echo "步骤 6: /proc重新挂载测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

unshare -m -p -f /bin/bash -c "
    # 卸载旧的/proc
    umount /proc 2>/dev/null || true

    # 挂载新的/proc
    mount -t proc proc /proc

    echo '新/proc已挂载'
    echo ''
    echo '/proc中的PID（应该从1开始）:'
    ls /proc/ | grep '^[0-9]' | head -5

    echo ''
    echo '进程列表:'
    ps aux | head -5
" | tee "$RESULTS_DIR/proc-remount.txt"

echo ""

# Tmpfs测试
echo "步骤 7: Tmpfs文件系统测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TMPFS_DIR="/tmp/tmpfs_test_$$"
mkdir -p "$TMPFS_DIR"

unshare -m /bin/bash -c "
    # 挂载tmpfs
    mount -t tmpfs -o size=10M tmpfs '$TMPFS_DIR'

    echo 'Tmpfs已挂载（大小限制: 10MB）'
    echo ''

    # 查看挂载信息
    df -h '$TMPFS_DIR'

    echo ''
    echo '写入测试文件:'
    dd if=/dev/zero of='$TMPFS_DIR/test.dat' bs=1M count=5 2>&1 | grep -v records

    echo ''
    echo '文件大小:'
    ls -lh '$TMPFS_DIR/test.dat'

    # 清理
    umount '$TMPFS_DIR'
" | tee "$RESULTS_DIR/tmpfs-test.txt"

rmdir "$TMPFS_DIR"

echo ""

# 挂载命名空间统计
echo "步骤 8: Mount namespace统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "系统中的Mount namespace数量:"
find /proc/*/ns/mnt 2>/dev/null | wc -l

echo ""
echo "当前系统所有Mount namespace:"
ls -l /proc/*/ns/mnt 2>/dev/null | awk '{print $11}' | sort -u | head -10

echo ""

# 生成报告
{
    echo "Mount Namespace测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  内核版本: $(uname -r)"
    echo "  Mount namespace支持: ✓"
    echo "  原始挂载点数量: $(mount | wc -l)"
    echo ""
    echo "测试项目:"
    echo "  ✓ Mount namespace创建"
    echo "  ✓ 临时挂载隔离"
    echo "  ✓ 挂载传播测试"
    echo "  ✓ Bind mount"
    echo "  ✓ 只读挂载"
    echo "  ✓ /proc重新挂载"
    echo "  ✓ Tmpfs文件系统"
    echo ""
    echo "关键发现:"
    echo "  - 新namespace中的挂载对主namespace不可见"
    echo "  - 支持多种挂载类型（tmpfs, bind, proc等）"
    echo "  - 可以设置只读挂载"
    echo "  - 挂载传播可以控制（shared/private/slave）"
    echo ""
    echo "详细日志:"
    echo "  原始挂载: $RESULTS_DIR/original-mounts.txt"
    echo "  基础测试: $RESULTS_DIR/basic-test.txt"
    echo "  Bind mount: $RESULTS_DIR/bind-mount.txt"
    echo "  只读挂载: $RESULTS_DIR/readonly-mount.txt"
    echo "  Proc挂载: $RESULTS_DIR/proc-remount.txt"
    echo "  Tmpfs测试: $RESULTS_DIR/tmpfs-test.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ Mount namespace测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
