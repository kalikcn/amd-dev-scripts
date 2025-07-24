#!/bin/bash

LATEST_VERSION="6.1.1.50603"  # ⚠️ 请根据你的目标版本自行更新

function check_amd_gpu() {
    echo "🔍 正在检测 AMD 显卡..."
    if lspci | grep -i 'VGA' | grep -i 'AMD\|ATI' > /dev/null; then
        echo "✅ 检测到 AMD 显卡："
        lspci | grep -i 'VGA' | grep -i 'AMD\|ATI'
        return 0
    else
        echo "❌ 未检测到 AMD 显卡。"
        return 1
    fi
}

function get_installed_driver_version() {
    if dpkg -l | grep -i amdgpu > /dev/null; then
        version=$(dpkg -s amdgpu-dkms 2>/dev/null | grep Version | awk '{print $2}')
        [ -z "$version" ] && version=$(dpkg -l | grep amdgpu | head -n 1 | awk '{print $3}')
        echo "$version"
    else
        echo "未检测到驱动"
    fi
}

function install_amd_driver() {
    echo "⚙️ 安装 AMD 驱动..."
    sudo apt update
    sudo apt --fix-broken install -y
    sudo ./amdgpu-install --usecase=graphics,opencl,rocm,hip -y
    echo "✅ 安装完成。请重启系统。"
}

function uninstall_amd_driver() {
    echo "⚠️ 正在卸载 AMD 驱动..."
    sudo amdgpu-uninstall -y
    sudo apt purge amdgpu* -y
    sudo apt autoremove --purge -y
    echo "✅ 驱动已卸载。"
}

function update_amd_driver() {
    CURRENT_VERSION=$(get_installed_driver_version)
    echo "当前驱动版本: $CURRENT_VERSION"
    echo "目标最新版:   $LATEST_VERSION"

    if [[ "$CURRENT_VERSION" == "未检测到驱动" ]]; then
        echo "🔄 未安装驱动，执行安装流程..."
        install_amd_driver
    elif dpkg --compare-versions "$CURRENT_VERSION" "ge" "$LATEST_VERSION"; then
        echo "✅ 当前驱动已是最新版本。"
    else
        echo "⬆️ 检测到新版本，准备更新驱动..."
        uninstall_amd_driver
        install_amd_driver
    fi
}

function detect_status() {
    echo "🧪 显卡型号检测："
    lshw -c video | grep -E "product|driver"

    CURRENT_VERSION=$(get_installed_driver_version)
    echo "📋 当前驱动版本：$CURRENT_VERSION"
    echo "📌 最新版本：$LATEST_VERSION"
    echo
    if [[ "$CURRENT_VERSION" == "未检测到驱动" ]]; then
        echo "⚠️ 未安装驱动。"
    elif dpkg --compare-versions "$CURRENT_VERSION" "ge" "$LATEST_VERSION"; then
        echo "✅ 驱动为最新版。"
    else
        echo "⚠️ 驱动不是最新版本，建议更新。"
    fi
}

# 主菜单
function main_menu() {
    echo "==============================="
    echo "🖥️  AMD 显卡驱动管理脚本"
    echo "==============================="
    echo "1. 检测 AMD 显卡与驱动状态"
    echo "2. 安装 AMD 显卡驱动"
    echo "3. 卸载 AMD 显卡驱动"
    echo "4. 更新 AMD 显卡驱动"
    echo "0. 退出脚本"
    echo "==============================="

    read -p "请输入选项 [0-4]: " choice
    case "$choice" in
        1)
            check_amd_gpu && detect_status
            ;;
        2)
            check_amd_gpu && install_amd_driver
            ;;
        3)
            uninstall_amd_driver
            ;;
        4)
            check_amd_gpu && update_amd_driver
            ;;
        0)
            echo "👋感谢使用！ 再见！"
            exit 0
            ;;
        *)
            echo "❌ 无效选项，请重新选择。"
            ;;
    esac
}

# 脚本入口
while true; do
    main_menu
    echo
    read -p "按回车键继续..." _
done

