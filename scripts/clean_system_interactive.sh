#!/bin/bash

# 交互式清理系统垃圾的脚本，适配自定义缓存路径
# 提供菜单让用户选择清理模式，包含安全检查和空间统计

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 计算指定目录或文件的占用空间
get_size() {
    local path=$1
    if [ -e "$path" ]; then
        du -sh "$path" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

# 清理目录函数
clean_directory() {
    local dir=$1
    local desc=$2
    if [ -d "$dir" ]; then
        echo "正在清理 $desc..."
        rm -rf "$dir"/* 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$desc 清理完成。"
        else
            echo "清理 $desc 时发生错误。"
        fi
    else
        echo "$desc 不存在，跳过清理。"
    fi
}

# 清理回收站
clean_trash() {
    local trash_dir="$HOME/.local/share/Trash"
    if [ -d "$trash_dir" ]; then
        echo "正在清理回收站..."
        rm -rf "$trash_dir/files/*" 2>/dev/null
        rm -rf "$trash_dir/info/*" 2>/dev/null
        echo "回收站清理完成。"
    else
        echo "回收站目录不存在，跳过清理。"
    fi
}

# 清理系统日志（需要 root 权限）
clean_system_logs() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "需要 root 权限清理系统日志，跳过。"
        return
    fi
    local log_dir="/var/log"
    echo "正在清理系统日志 ($log_dir)..."
    find "$log_dir" -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
    find "$log_dir" -type f -name "*.log.*" -delete 2>/dev/null
    echo "系统日志清理完成。"
}

# 清理旧内核（需要 root 权限，适用于 Ubuntu/Debian）
clean_old_kernels() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "需要 root 权限清理旧内核，跳过。"
        return
    fi
    if command_exists apt-get; then
        echo "正在清理旧内核..."
        apt-get autoremove --purge -y 2>/dev/null
        apt-get autoclean 2>/dev/null
        echo "旧内核清理完成。"
    else
        echo "未检测到 apt-get，跳过旧内核清理。"
    fi
}

# 定义清理目标
USER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
USER_LOCAL="$HOME/.local/share"
TEMP_DIR="/tmp"
SYSTEM_LOG="/var/log"
TRASH_DIR="$HOME/.local/share/Trash"
TORCH_CACHE="${TORCH_HOME:-$USER_CACHE/torch}"
UV_CACHE="${UV_CACHE_DIR:-$USER_CACHE/uv}"

# 显示清理前空间占用
show_space_usage() {
    echo "当前空间占用："
    echo "1. 用户缓存目录 ($USER_CACHE): $(get_size "$USER_CACHE")"
    echo "2. 用户数据目录 ($USER_LOCAL): $(get_size "$USER_LOCAL")"
    echo "3. 临时目录 ($TEMP_DIR): $(get_size "$TEMP_DIR")"
    echo "4. 系统日志 ($SYSTEM_LOG): $(get_size "$SYSTEM_LOG")"
    echo "5. 回收站 ($TRASH_DIR): $(get_size "$TRASH_DIR")"
    echo "6. PyTorch 缓存 ($TORCH_CACHE): $(get_size "$TORCH_CACHE")"
    echo "7. uv 缓存 ($UV_CACHE): $(get_size "$UV_CACHE")"
    echo
}

# 交互式菜单
show_menu() {
    echo "请选择清理模式（输入编号，多个用空格分隔，输入 0 退出）："
    echo "1. 清理用户缓存目录 ($USER_CACHE)"
    echo "2. 清理用户数据目录 ($USER_LOCAL)"
    echo "3. 清理系统临时目录 ($TEMP_DIR)"
    echo "4. 清理系统日志 ($SYSTEM_LOG) [需要 root 权限]"
    echo "5. 清理回收站 ($TRASH_DIR)"
    echo "6. 清理 PyTorch 缓存 ($TORCH_CACHE)"
    echo "7. 清理 uv 缓存 ($UV_CACHE)"
    echo "8. 清理旧内核 [需要 root 权限，适用于 Ubuntu/Debian]"
    echo "9. 清理全部"
    echo "0. 退出"
    echo
}

# 主逻辑
echo "=== 系统垃圾清理工具 ==="
echo "当前时间: $(date)"
echo

# 检查是否以 root 运行
if [ "$(id -u)" -eq 0 ]; then
    echo "警告：以 root 权限运行，可能清理系统级文件，请谨慎操作！"
else
    echo "以普通用户运行，部分清理选项（如系统日志和旧内核）需要 root 权限。"
fi
echo

# 显示初始空间占用
show_space_usage

while true; do
    show_menu
    read -p "请输入选项 (0-9): " choices
    echo

    # 处理退出
    if [ "$choices" = "0" ]; then
        echo "已退出清理工具。"
        exit 0
    fi

    # 验证输入
    valid_choice=true
    for choice in $choices; do
        if ! echo "$choice" | grep -qE '^[0-9]$'; then
            valid_choice=false
            break
        fi
    done

    if [ "$valid_choice" = false ]; then
        echo "无效输入，请输入 0-9 的编号！"
        continue
    fi

    # 确认清理
    read -p "确认执行选中的清理操作？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消清理操作。"
        continue
    fi

    # 执行清理
    for choice in $choices; do
        case $choice in
            1) clean_directory "$USER_CACHE" "用户缓存目录" ;;
            2) clean_directory "$USER_LOCAL" "用户数据目录" ;;
            3) clean_directory "$TEMP_DIR" "系统临时目录" ;;
            4) clean_system_logs ;;
            5) clean_trash ;;
            6) clean_directory "$TORCH_CACHE" "PyTorch 缓存" ;;
            7) clean_directory "$UV_CACHE" "uv 缓存" ;;
            8) clean_old_kernels ;;
            9)
                clean_directory "$USER_CACHE" "用户缓存目录"
                clean_directory "$USER_LOCAL" "用户数据目录"
                clean_directory "$TEMP_DIR" "系统临时目录"
                clean_system_logs
                clean_trash
                clean_directory "$TORCH_CACHE" "PyTorch 缓存"
                clean_directory "$UV_CACHE" "uv 缓存"
                clean_old_kernels
                ;;
        esac
    done

    # 显示清理后空间占用
    echo
    show_space_usage
    echo "清理完成！"
    echo "请检查系统是否正常运行，必要时可重新生成缓存。"
    echo

    # 询问是否继续
    read -p "是否继续选择其他清理模式？(y/N): " continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
        echo "清理任务结束，建议重启系统以确保效果。"
        exit 0
    fi
done
