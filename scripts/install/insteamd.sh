#!/bin/bash
set -e

# 日志文件
LOG_FILE="/tmp/amdgpu-install-$(date +%F-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1
echo "📜 日志记录到 $LOG_FILE"

# 检查依赖工具
function check_dependencies() {
    echo "🔍 检查必要工具..."
    for cmd in curl wget lspci lshw dpkg apt-get lsb_release; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "❌ 需要安装 $cmd，请先安装。"
            exit 1
        fi
    done
    echo "✅ 所有必要工具已安装。"
}

# 检查 sudo 权限
function check_sudo() {
    echo "🔍 检查 sudo 权限..."
    if ! sudo -n true 2>/dev/null; then
        echo "❌ 需要 sudo 权限，请以有管理员权限的用户运行脚本。"
        exit 1
    fi
    echo "✅ sudo 权限验证通过。"
}

# 检查系统兼容性
function check_system_compatibility() {
    echo "🔍 检查系统兼容性..."
    KERNEL=$(uname -r)
    if [[ ! "$KERNEL" =~ ^[5-6]\. ]]; then
        echo "⚠️ 内核版本 $KERNEL 可能不完全支持最新 AMDGPU 驱动，建议升级内核。"
    fi
    DISTRO=$(lsb_release -cs 2>/dev/null || echo "unknown")
    if [[ "$DISTRO" == "unknown" ]]; then
        echo "❌ 无法检测系统发行版，脚本仅支持 Ubuntu。"
        exit 1
    fi
    echo "✅ 系统发行版：$DISTRO，内核版本：$KERNEL"
    return 0
}

# 检查系统中是否存在 AMD 显卡
function check_amd_gpu() {
    echo "🔍 正在检测 AMD 显卡..."
    GPU_INFO=$(lspci | grep -i 'VGA\|Display' | grep -i amd || true)
    if [[ -z "$GPU_INFO" ]]; then
        echo "❌ 未检测到 AMD 显卡，脚本终止。"
        return 1
    fi

    echo "✅ 检测到 AMD 显卡："
    echo "$GPU_INFO"

    echo "🧪 显卡型号检测："
    sudo lshw -c video | grep -A12 '*-display' | grep -E 'product:|configuration:' | sed 's/^/       /'
    return 0
}

# 获取系统中已安装的驱动版本（如果有）
function get_installed_driver_version() {
    dpkg -l | grep amdgpu-install | awk '{print $3}' | sed 's/^1://' || echo "未安装"
}

# 获取最新版本号
function fetch_latest_version() {
    VERSION=$(curl -s https://repo.radeon.com/amdgpu-install/ | grep -oP '\d+\.\d+(\.\d+)?' | sort -V | tail -n1)
    if [[ -z "$VERSION" ]]; then
        echo "❌ 无法获取最新版本，请检查网络或网站结构。"
        exit 1
    fi
    echo "$VERSION"
}

# 比较已安装版本与最新版本
function check_driver_version_status() {
    INSTALLED=$(get_installed_driver_version)
    LATEST=$(fetch_latest_version)

    echo "📋 当前驱动版本：$INSTALLED"
    echo "📌 最新版本：$LATEST"

    if [[ "$INSTALLED" == "$LATEST"* ]]; then
        echo "✅ 驱动为最新版。"
    else
        echo "⚠️ 驱动不是最新版，建议更新。"
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
    echo "🔎 检查依赖这些包的其他已安装包："
    for pkg in $AMDGPU_PKGS; do
        echo "  包: $pkg"
        RDEPENDS=$(apt-cache rdepends --installed "$pkg" | grep -v "^$pkg$" | grep -v "Reverse Depends:" | tr '\n' ' ')
        if [[ -z "$RDEPENDS" ]]; then
            echo "    无其他已安装包依赖此包"
        else
            echo "    以下包依赖此包，卸载时可能影响它们：$RDEPENDS"
        fi
    done

    echo ""
    if sudo lshw -c video | grep -iq 'driver=amdgpu'; then
        echo "⚠️ 当前正在使用 amdgpu 驱动，卸载可能导致图形界面不可用。"
        echo "建议确保已安装备用驱动（如 nouveau 或 vesa）。"
    fi

    echo ""
    read -p "⚠️ 确认要卸载以上所有 amdgpu 相关包？这可能影响系统图形和部分软件，输入 y 继续，其他键取消: " yn
    if [[ "$yn" != "y" && "$yn" != "Y" ]]; then
        echo "❌ 取消卸载。"
        return
    fi

    # 备份配置文件
    BACKUP_DIR="/tmp/amdgpu-backup-$(date +%F-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r /etc/ati /etc/X11/xorg.conf.d "$BACKUP_DIR" 2>/dev/null || true
    echo "📂 已备份配置文件到 $BACKUP_DIR"

    if command -v amdgpu-uninstall >/dev/null 2>&1; then
        echo "🛠️ 使用 amdgpu-uninstall 卸载..."
        sudo amdgpu-uninstall || echo "⚠️ amdgpu-uninstall 执行失败，尝试手动卸载..."
    fi

    echo "📦 手动卸载 amdgpu 包..."
    sudo apt-get purge -y $AMDGPU_PKGS
    sudo apt-get autoremove -y
    sudo apt --fix-broken install -y

    echo "🧹 清理残留文件..."
    sudo rm -rf /etc/ati /etc/X11/xorg.conf.d/20-amdgpu.conf /usr/share/ati /usr/lib/amd \
        /usr/lib64/amd /var/lib/amd /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/amd \
        /lib/modules/$(uname -r)/updates/dkms/amdgpu

    echo "✅ 卸载完成，建议重启系统以生效。"
}

function install_amdgpu() {
    echo "📡 正在获取 AMDGPU 安装器版本列表..."

    DISTRO=$(lsb_release -cs 2>/dev/null || echo "unknown")
    if [[ "$DISTRO" == "unknown" ]]; then
        echo "❌ 无法检测系统发行版，脚本仅支持 Ubuntu。"
        exit 1
    fi

    VERSION_LIST_RAW=$(curl -s https://repo.radeon.com/amdgpu-install/ | grep -oP '\d+\.\d+(\.\d+)?' | uniq)
    if [[ -z "$VERSION_LIST_RAW" ]]; then
        echo "❌ 未能获取版本列表，可能网络异常或目录结构已改变。"
        exit 1
    fi

    VERSION_LIST=$(echo "$VERSION_LIST_RAW" | sort -V)
    VERSIONS=()
    i=1
    echo ""
    echo "📋 可用版本列表:"
    while read -r version; do
        echo "  $i) $version"
        VERSIONS+=("$version")
        ((i++))
    done <<< "$VERSION_LIST"

    read -p "请输入你想安装的版本编号 (1-${#VERSIONS[@]}): " CHOICE
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#VERSIONS[@]} )); then
        echo "❌ 输入无效，请输入有效编号。"
        exit 1
    fi

    SELECTED_VERSION="${VERSIONS[$((CHOICE - 1))]}"
    echo "✅ 你选择的版本是: $SELECTED_VERSION"

    TARGET_URL="https://repo.radeon.com/amdgpu-install/$SELECTED_VERSION/ubuntu/$DISTRO/"
    echo "🌐 正在获取该版本下的 .deb 文件..."

    DEB_FILE=$(curl -s "$TARGET_URL" | grep -oP 'amdgpu-install_.*?\.deb' | head -n1)
    if [[ -z "$DEB_FILE" ]]; then
        echo "❌ 未找到 .deb 文件，请检查该版本是否支持 Ubuntu $DISTRO。"
        exit 1
    fi

    DOWNLOAD_URL="${TARGET_URL}${DEB_FILE}"
    echo "⬇️ 下载链接: $DOWNLOAD_URL"
    wget -c "$DOWNLOAD_URL" -O "$DEB_FILE"

    if [[ ! -s "$DEB_FILE" ]]; then
        echo "❌ 下载的 $DEB_FILE 文件为空或不存在。"
        exit 1
    fi

    echo "📦 安装驱动器包 $DEB_FILE ..."
    sudo dpkg -i "$DEB_FILE"
    sudo apt --fix-broken install -y

    echo "🚀 安装驱动核心功能: graphics, opencl, rocm, hip"
    sudo amdgpu-install --usecase=graphics,opencl,rocm,hip -y

    echo "🔍 验证驱动是否生效..."
    if sudo lshw -c video | grep -iq 'driver=amdgpu'; then
        echo "✅ 驱动安装成功并已加载。"
        if command -v clinfo >/dev/null 2>&1; then
            echo "🔎 检查 OpenCL 支持..."
            clinfo | grep -i "platform name" || echo "⚠️ 未检测到 OpenCL 支持，可能需要进一步配置。"
        fi
    else
        echo "❌ 驱动未正确加载。"
        echo "📂 可尝试恢复备份配置文件：$BACKUP_DIR"
    fi
}

function update_amdgpu() {
    CURRENT=$(get_installed_driver_version)
    LATEST=$(fetch_latest_version)
    if [[ "$CURRENT" == "$LATEST"* ]]; then
        echo "✅ 已是最新版本 ($CURRENT)。无需更新。"
    else
        echo "🔁 当前版本 $CURRENT 非最新，准备更新到 $LATEST ..."
        uninstall_amdgpu
        install_amdgpu
    fi
}

# 主程序
check_dependencies
check_sudo
check_system_compatibility

# 主菜单
while true; do
    echo ""
    echo "==============================="
    echo "🖥️  AMD 显卡驱动管理脚本"
    echo "==============================="
    echo "1. 检测 AMD 显卡与驱动状态"
    echo "2. 安装 AMD 显卡驱动"
    echo "3. 卸载 AMD 显卡驱动"
    echo "4. 更新 AMD 显卡驱动"
    echo "5. 检查系统兼容性"
    echo "0. 退出脚本"
    echo "==============================="
    read -p "请输入选项 [0-5]: " opt
    case "$opt" in
        1)
            if check_amd_gpu; then
                check_driver_version_status
            fi
            read -p "按回车键继续..."
            ;;
        2)
            install_amdgpu
            ;;
        3)
            uninstall_amdgpu
            ;;
        4)
            update_amdgpu
            ;;
        5)
            check_system_compatibility
            read -p "按回车键继续..."
            ;;
        0)
            echo "👋 再见！"
            exit 0
            ;;
        *)
            echo "❌ 无效选项，请输入 0-5。"
            ;;
    esac
done
