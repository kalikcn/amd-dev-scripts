#!/bin/bash
set -e

function detect_gpu_and_driver() {
    echo "🔍 正在检测 AMD 显卡..."
    GPU_INFO=$(lspci -nnk | grep -A3 '\[AMD/ATI\]')
    if [[ -z "$GPU_INFO" ]]; then
        echo "❌ 未检测到 AMD 显卡。"
        return
    fi
    echo "✅ 检测到 AMD 显卡："
    echo "$GPU_INFO"

    echo "🧪 显卡型号检测："
    sudo lshw -c video | grep -A10 "AMD" | grep -E "product|configuration"

    echo "📋 当前驱动版本："
    dpkg -l | grep amdgpu-install || echo "未安装 amdgpu 驱动"

    # 获取最新版本示例（这里简单示例，你可替换为完整获取逻辑）
    LATEST_VERSION=$(curl -s https://repo.radeon.com/amdgpu-install/ | grep -oP '\d+\.\d+(\.\d+)?(?=/)' | sort -V | tail -n1)
    # echo "📌 最新驱动版本：${LATEST_VERSION:-未知}"

    # 判断当前驱动是否是最新版示例逻辑（需要根据实际版本格式调整）
    CURRENT_VERSION=$(dpkg -l | grep amdgpu-install | awk '{print $3}' | head -n1)
    if [[ -z "$CURRENT_VERSION" ]]; then
        echo "ℹ️ 当前系统未安装 AMDGPU 驱动。"
    else
        echo "ℹ️ 当前安装驱动版本：$CURRENT_VERSION"
        # if [[ "$CURRENT_VERSION" == *"$LATEST_VERSION"* ]]; then
        #     echo "✅ 当前驱动为最新版本。"
        # else
        #     echo "⚠️ 当前驱动不是最新版本。"
        # fi
    fi
}

function uninstall_amdgpu() {
    echo "🧹 开始检测已安装的 amdgpu 相关包..."

    AMDGPU_PKGS=$(dpkg -l | grep amdgpu | awk '{print $2}' || true)

    if [[ -z "$AMDGPU_PKGS" ]]; then
        echo "ℹ️ 未检测到已安装的 amdgpu 相关包，无需卸载。"
        return
    fi

    echo "📦 检测到以下 amdgpu 相关包："
    echo "$AMDGPU_PKGS"

    echo ""
    read -p "⚠️ 确认要卸载以上所有 amdgpu 相关包？这可能影响系统图形和部分软件，输入 y 继续，其他键取消: " yn
    if [[ "$yn" != "y" && "$yn" != "Y" ]]; then
        echo "取消卸载。"
        return
    fi

    # 先尝试官方卸载脚本
    if command -v amdgpu-uninstall >/dev/null 2>&1; then
        echo "🛠️ 运行 amdgpu-uninstall 进行卸载..."
        sudo amdgpu-uninstall || echo "⚠️ amdgpu-uninstall 执行失败，尝试手动卸载..."
    fi

    echo "📦 使用 apt-get 卸载 amdgpu 相关包..."
    sudo apt-get purge -y $AMDGPU_PKGS

    echo "🧹 自动移除无用依赖包..."
    sudo apt-get autoremove -y

    echo "🔧 修复依赖问题..."
    sudo apt --fix-broken install -y

    echo "🧹 清理残留文件和配置..."
    sudo rm -rf /etc/ati /etc/X11/xorg.conf.d/20-amdgpu.conf /usr/share/ati /usr/lib/amd \
        /usr/lib64/amd /var/lib/amd /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/amd \
        /lib/modules/$(uname -r)/updates/dkms/amdgpu

    echo ""
    echo "✅ 卸载完成。建议重启系统以确保所有改动生效。"
}

function install_amdgpu_interactive() {
    echo "📡 正在获取 AMDGPU 安装器版本列表..."
    VERSION_LIST_RAW=$(curl -s https://repo.radeon.com/amdgpu-install/ | grep -oP '\d+\.\d+(\.\d+)?(?=/)|latest' | uniq)
    if [[ -z "$VERSION_LIST_RAW" ]]; then
        echo "❌ 未能获取版本列表，可能网络异常或目录结构已改变。"
        return
    fi

    VERSIONS=()
    i=1
    echo ""
    echo "📋 可用版本列表:"
    while read -r version; do
        echo "  $i) $version"
        VERSIONS+=("$version")
        ((i++))
    done <<< "$VERSION_LIST_RAW"

    read -p "请输入你想安装的版本编号 (1-${#VERSIONS[@]}): " CHOICE
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#VERSIONS[@]} )); then
        echo "❌ 输入无效，请输入有效编号。"
        return
    fi

    SELECTED_VERSION="${VERSIONS[$((CHOICE - 1))]}"
    echo "✅ 你选择的版本是: $SELECTED_VERSION"

    TARGET_URL="https://repo.radeon.com/amdgpu-install/$SELECTED_VERSION/ubuntu/noble/"
    echo "🌐 正在获取该版本下的 .deb 文件..."

    DEB_FILE=$(curl -s "$TARGET_URL" | grep -oP 'amdgpu-install_.*?\.deb' | head -n1)
    if [[ -z "$DEB_FILE" ]]; then
        echo "❌ 未找到 .deb 文件，请检查该版本是否支持 Ubuntu noble。"
        return
    fi

    DOWNLOAD_URL="${TARGET_URL}${DEB_FILE}"
    echo "⬇️ 下载链接: $DOWNLOAD_URL"
    wget -c "$DOWNLOAD_URL" -O "$DEB_FILE"

    echo "📦 正在安装 $DEB_FILE ..."
    sudo dpkg -i "$DEB_FILE"

    echo "🔧 运行 apt 修复依赖..."
    sudo apt --fix-broken install -y

    echo "🚀 自动执行 amdgpu-install 安装驱动（graphics, opencl, rocm, hip）..."
    sudo amdgpu-install --usecase=graphics,opencl,rocm,hip -y

    echo "🔍 验证驱动是否安装成功..."
    if sudo lshw -c video | grep -iq 'driver=amdgpu'; then
        echo "✅ 驱动安装成功，检测到 amdgpu 驱动已加载。"
    else
        echo "❌ 驱动安装失败，未检测到 amdgpu 驱动。请检查日志。"
    fi
}

function uninstall_and_install() {
    uninstall_amdgpu
    install_amdgpu_interactive
}

# 主循环菜单
while true; do
    echo ""
    echo "==============================="
    echo "🖥️  AMD 显卡驱动管理脚本"
    echo "==============================="
    echo "1) 检测 AMD 显卡与驱动状态"
    echo "2) 安装 AMD 显卡驱动"
    echo "3) 卸载 AMD 显卡驱动"
    echo "4) 卸载并重装 AMD 显卡驱动"
    echo "0) 退出脚本"
    echo "==============================="
    read -p "请输入选项 [0-4]: " choice

    case $choice in
        1)
            detect_gpu_and_driver
            read -p "按回车键返回菜单..."
            ;;
        2)
            install_amdgpu_interactive
            read -p "按回车键返回菜单..."
            ;;
        3)
            uninstall_amdgpu
            read -p "按回车键返回菜单..."
            ;;
        4)
            uninstall_and_install
            read -p "按回车键返回菜单..."
            ;;
        0)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效输入，请重新选择。"
            ;;
    esac
done

