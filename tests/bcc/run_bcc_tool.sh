#!/bin/bash
# BCC 工具通用运行脚本
# 用法: run_bcc_tool.sh <tool_name> [args...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
fi

# 获取工具名
TOOL_NAME="$1"
shift

if [[ -z "$TOOL_NAME" ]]; then
    echo "用法: $0 <tool_name> [args...]"
    echo "示例: $0 execsnoop -t"
    exit 1
fi

# 查找工具
TOOL_PATH=$(find_bcc_tool "$TOOL_NAME")

if [[ -z "$TOOL_PATH" ]]; then
    echo "错误: 未找到 BCC 工具: $TOOL_NAME"
    echo ""
    echo "已搜索路径:"
    echo "  - PATH 中的命令"
    echo "  - /usr/share/bcc/tools"
    echo "  - /usr/local/share/bcc/tools"
    echo ""
    show_bcc_install_help
    exit 1
fi

# 运行工具
exec "$TOOL_PATH" "$@"
