#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# cachestat - 页缓存统计工具（兼容版本）
# 解决 account_page_dirtied 内核函数在不同内核版本中的变化
#
# 内核函数变化:
#   - 旧内核 (< 5.16): account_page_dirtied
#   - 新内核 (>= 5.16): folio_account_dirtied
#

from __future__ import print_function
from bcc import BPF
import argparse
import time
import sys

# BPF 程序
bpf_text = """
#include <uapi/linux/ptrace.h>

struct key_t {
    u64 ip;
};

// 统计计数器
BPF_HASH(total, struct key_t, u64);
BPF_HASH(misses, struct key_t, u64);
BPF_HASH(hits, struct key_t, u64);
BPF_HASH(dirtied, struct key_t, u64);

// 页缓存添加 - miss
int do_count_add(struct pt_regs *ctx) {
    struct key_t key = {};
    u64 zero = 0, *val;

    key.ip = PT_REGS_IP(ctx);

    val = misses.lookup_or_init(&key, &zero);
    (*val)++;

    val = total.lookup_or_init(&key, &zero);
    (*val)++;

    return 0;
}

// 页缓存命中 - hit
int do_count_hit(struct pt_regs *ctx) {
    struct key_t key = {};
    u64 zero = 0, *val;

    key.ip = PT_REGS_IP(ctx);

    val = hits.lookup_or_init(&key, &zero);
    (*val)++;

    val = total.lookup_or_init(&key, &zero);
    (*val)++;

    return 0;
}

// 页面变脏
int do_count_dirty(struct pt_regs *ctx) {
    struct key_t key = {};
    u64 zero = 0, *val;

    key.ip = PT_REGS_IP(ctx);

    val = dirtied.lookup_or_init(&key, &zero);
    (*val)++;

    return 0;
}
"""

def check_kernel_function(func_name):
    """检查内核函数是否存在"""
    try:
        with open('/proc/kallsyms', 'r') as f:
            for line in f:
                if func_name in line:
                    return True
    except:
        pass
    return False

def get_dirty_function():
    """获取当前内核支持的 dirty 函数名"""
    # 新内核使用 folio_account_dirtied
    if check_kernel_function('folio_account_dirtied'):
        return 'folio_account_dirtied'
    # 旧内核使用 account_page_dirtied
    elif check_kernel_function('account_page_dirtied'):
        return 'account_page_dirtied'
    # 更老的内核可能使用 __set_page_dirty
    elif check_kernel_function('__set_page_dirty'):
        return '__set_page_dirty'
    else:
        return None

def main():
    parser = argparse.ArgumentParser(
        description="页缓存统计工具（内核兼容版本）",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("interval", nargs="?", default=1, type=int,
        help="输出间隔（秒），默认 1")
    parser.add_argument("count", nargs="?", default=99999999, type=int,
        help="输出次数，默认无限")
    parser.add_argument("-v", "--verbose", action="store_true",
        help="显示详细信息")
    args = parser.parse_args()

    # 检查 root 权限
    if sys.geteuid() != 0:
        print("错误: 需要 root 权限运行", file=sys.stderr)
        sys.exit(1)

    # 检测内核函数
    dirty_func = get_dirty_function()

    if args.verbose:
        print("内核函数检测:")
        print("  mark_page_accessed:",
              "存在" if check_kernel_function('mark_page_accessed') else "不存在")
        print("  mark_buffer_dirty:",
              "存在" if check_kernel_function('mark_buffer_dirty') else "不存在")
        print("  add_to_page_cache_lru:",
              "存在" if check_kernel_function('add_to_page_cache_lru') else "不存在")
        print("  dirty 函数:", dirty_func if dirty_func else "未找到")
        print()

    # 加载 BPF 程序
    b = BPF(text=bpf_text)

    # 附加 kprobes
    try:
        # 页缓存 miss
        b.attach_kprobe(event="add_to_page_cache_lru", fn_name="do_count_add")

        # 页缓存 hit (通过 mark_page_accessed)
        b.attach_kprobe(event="mark_page_accessed", fn_name="do_count_hit")

        # 页面变脏
        if dirty_func:
            b.attach_kprobe(event=dirty_func, fn_name="do_count_dirty")
            has_dirty = True
        else:
            has_dirty = False
            if args.verbose:
                print("警告: 未找到 dirty 跟踪函数，将不统计脏页数据")
                print()
    except Exception as e:
        print(f"错误: 无法附加 kprobe: {e}", file=sys.stderr)
        print("", file=sys.stderr)
        print("可能的原因:", file=sys.stderr)
        print("  1. 内核版本不支持这些函数", file=sys.stderr)
        print("  2. 缺少内核调试符号", file=sys.stderr)
        print("  3. BPF 功能未启用", file=sys.stderr)
        print("", file=sys.stderr)
        print("建议:", file=sys.stderr)
        print("  - 检查内核版本: uname -r", file=sys.stderr)
        print("  - 安装调试符号: debuginfo-install kernel", file=sys.stderr)
        sys.exit(1)

    # 打印表头
    print("%-8s " % "TIME", end="")
    print("%8s %8s %8s %8s %12s" %
          ("HITS", "MISSES", "DIRTIES", "BUFFERS", "HIT_RATE"))

    loop = 0
    exiting = False

    while loop < args.count and not exiting:
        try:
            time.sleep(args.interval)
        except KeyboardInterrupt:
            exiting = True
            break

        # 获取统计数据
        total_hits = 0
        total_misses = 0
        total_dirty = 0

        for k, v in b["hits"].items():
            total_hits += v.value

        for k, v in b["misses"].items():
            total_misses += v.value

        if has_dirty:
            for k, v in b["dirtied"].items():
                total_dirty += v.value

        # 计算命中率
        total_access = total_hits + total_misses
        if total_access > 0:
            hit_rate = (total_hits * 100.0) / total_access
        else:
            hit_rate = 0.0

        # 打印统计
        print("%-8s " % time.strftime("%H:%M:%S"), end="")
        print("%8d %8d %8d %8s %11.2f%%" %
              (total_hits, total_misses, total_dirty, "-", hit_rate))

        # 清空计数器
        b["hits"].clear()
        b["misses"].clear()
        if has_dirty:
            b["dirtied"].clear()
        b["total"].clear()

        loop += 1

    print()
    print("说明:")
    print("  HITS    - 页缓存命中次数")
    print("  MISSES  - 页缓存未命中次数（需要从磁盘读取）")
    print("  DIRTIES - 脏页数量（被修改但未写入磁盘）")
    print("  HIT_RATE - 缓存命中率（越高越好）")

if __name__ == "__main__":
    main()
