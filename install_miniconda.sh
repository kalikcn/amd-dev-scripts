#!/bin/bash

# 颜色输出
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# 检测是否为 WSL 环境
function is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}
if is_wsl; then
    echo -e "${YELLOW}检测到 WSL 环境，建议安装路径使用 /home/用户名/ 目录，避免 /mnt/c/ 等挂载盘。${RESET}"
fi

# 安全退出，兼容 source
function safe_exit() {
    (return 0 2>/dev/null) && return 0 || exit 0
}

# 动态检测 Miniconda 安装位置
function detect_conda_prefix() {
    local paths=(
        "$HOME/miniconda3"
        "/opt/miniconda/2"
        "/opt/miniconda"
    )
    if [ -f "$HOME/.miniconda_manager_path" ]; then
        local custom_path=$(cat "$HOME/.miniconda_manager_path")
        if [ -n "$custom_path" ] && [ -f "$custom_path/etc/profile.d/conda.sh" ]; then
            echo "$custom_path"
            return
        fi
    fi
    for p in "${paths[@]}"; do
        if [ -f "$p/etc/profile.d/conda.sh" ]; then
            echo "$p"
            return
        fi
    done
    if [ -n "$CONDA_CUSTOM_PREFIX" ] && [ -f "$CONDA_CUSTOM_PREFIX/etc/profile.d/conda.sh" ]; then
        echo "$CONDA_CUSTOM_PREFIX"
        return
    fi
    echo ""
}

# 全局设置 CONDA_PREFIX
CONDA_PREFIX=$(detect_conda_prefix)
if [ -n "$CONDA_PREFIX" ]; then
    source "$CONDA_PREFIX/etc/profile.d/conda.sh"
else
    echo -e "${RED}未检测到 Miniconda 安装目录，conda 相关功能将不可用。${RESET}"
fi

# 自动选择 wget/curl 下载
function download_miniconda() {
    local url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    local out="/tmp/miniconda.sh"
    if command -v wget >/dev/null 2>&1; then
        wget "$url" -O "$out"
    elif command -v curl >/dev/null 2>&1; then
        curl -L "$url" -o "$out"
    else
        echo -e "${RED}未检测到 wget 或 curl，请先安装其中之一。${RESET}"
        return 1
    fi
}

# 自动写入 bashrc/zshrc
function add_path_to_shell_rc() {
    local path="$1"
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi
    if ! grep -q "$path/bin" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$path/bin:\$PATH\"" >> "$shell_rc"
    fi
}

# 自动写入 bashrc/zshrc
function add_conda_init_to_shell_rc() {
    local conda_path="$1"
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi
    local init_code="\n# >>> conda initialize >>>\nif [ -f \"$conda_path/etc/profile.d/conda.sh\" ]; then\n    . \"$conda_path/etc/profile.d/conda.sh\"\nfi\n# <<< conda initialize <<<\n"
    # 如果没有 conda initialize 片段则追加
    if ! grep -q "$conda_path/etc/profile.d/conda.sh" "$shell_rc" 2>/dev/null; then
        echo -e "$init_code" >> "$shell_rc"
    fi
}

# 检查 Miniconda 是否已安装
function check_miniconda_installed() {
    if command -v conda >/dev/null 2>&1; then
        echo -e "${GREEN}Miniconda 已安装。${RESET}"
        return 0
    else
        if [ -n "$CONDA_PREFIX" ]; then
            source "$CONDA_PREFIX/etc/profile.d/conda.sh"
        fi
        if command -v conda >/dev/null 2>&1; then
            echo -e "${GREEN}Miniconda 已安装（已激活）。${RESET}"
            return 0
        else
            echo -e "${YELLOW}未检测到 Miniconda。${RESET}"
            local found_path=""
            local paths=("$HOME/miniconda3" "/opt/miniconda/2" "/opt/miniconda")
            for p in "${paths[@]}"; do
                if [ -f "$p/etc/profile.d/conda.sh" ]; then
                    found_path="$p"
                    break
                fi
            done
            if [ -n "$found_path" ]; then
                echo "$found_path" > "$HOME/.miniconda_manager_path"
                echo -e "${YELLOW}检测到新的 Miniconda 路径：$found_path，已写入配置。请重新运行脚本以生效。${RESET}"
                safe_exit
            fi
            return 1
        fi
    fi
}

# 安装 Miniconda
function install_miniconda() {
    echo -e "${YELLOW}请输入 Miniconda 安装路径（如 /home/$USER/miniconda3）：${RESET}"
    read install_path
    if [ -z "$install_path" ]; then
        echo -e "${RED}安装路径不能为空，退出。${RESET}"
        safe_exit
    fi
    parent_dir=$(dirname "$install_path")
    if [ ! -d "$parent_dir" ]; then
        echo -e "${YELLOW}父目录 $parent_dir 不存在，正在创建...${RESET}"
        mkdir -p "$parent_dir"
    fi
    if [ ! -w "$parent_dir" ]; then
        echo -e "${RED}你没有权限在 $parent_dir 下安装 Miniconda。${RESET}"
        echo -e "${YELLOW}请用 sudo 重新运行脚本，或选择你有权限的目录（如 /home/$USER/miniconda3）。${RESET}"
        return
    fi
    update_flag=""
    if [ -d "$install_path" ]; then
        echo -e "${YELLOW}安装目录已存在。请选择：1: 安装&更新、 2： 卸载&重装、 3： 取消； [1/2/3]：${RESET}"
        read op
        if [ "$op" = "1" ]; then
            update_flag="-u"
        elif [ "$op" = "2" ]; then
            if [ ! -w "$parent_dir" ]; then
                echo -e "${RED}你没有权限删除 $install_path。${RESET}"
                echo -e "${YELLOW}请用 sudo 重新运行脚本，或选择你有权限的目录。${RESET}"
                return
            fi
            rm -rf "$install_path"
            update_flag=""
        else
            echo -e "${RED}已取消安装。${RESET}"
            return
        fi
    fi
    echo -e "${YELLOW}正在下载 Miniconda 安装包...${RESET}"
    download_miniconda || { echo -e "${RED}下载失败。${RESET}"; return; }
    echo -e "${YELLOW}开始安装...${RESET}"
    bash /tmp/miniconda.sh -b $update_flag -p "$install_path"
    rm /tmp/miniconda.sh
    add_path_to_shell_rc "$install_path"
    add_conda_init_to_shell_rc "$install_path"
    if [ -f "$install_path/etc/profile.d/conda.sh" ]; then
        source "$install_path/etc/profile.d/conda.sh"
        CONDA_PREFIX="$install_path"
        echo "$install_path" > "$HOME/.miniconda_manager_path"
        echo -e "${GREEN}Miniconda 安装完成，路径已写入配置。请重新运行脚本以生效。${RESET}"
        safe_exit
    else
        echo -e "${RED}Miniconda 安装失败。${RESET}"
    fi
}

# 设置虚拟环境目录
function set_envs_dir() {
    echo -e "${YELLOW}请输入虚拟环境存放目录（如 ./Miniconda/envs，建议与 Miniconda 安装目录一致）：${RESET}"
    read envs_dir
    if [ -z "$envs_dir" ]; then
        echo -e "${RED}虚拟环境目录不能为空，退出。${RESET}"
        safe_exit
    fi
    conda config --add envs_dirs "$envs_dir"
    echo -e "${GREEN}虚拟环境目录已设置为：$envs_dir${RESET}"
}

# 查询虚拟环境
function list_envs() {
    echo -e "${YELLOW}当前 Miniconda 虚拟环境如下：${RESET}"
    conda env list
}

# 进入虚拟环境
function activate_env() {
    list_envs
    echo -e "${YELLOW}请输入要进入的虚拟环境名称：${RESET}"
    read env_name
    if [ -z "$env_name" ]; then
        echo -e "${RED}环境名称不能为空。${RESET}"
        return
    fi
    if [[ ! "$env_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}环境名称只能包含字母、数字、下划线和短横线。${RESET}"
        return
    fi
    if [ -n "$CONDA_PREFIX" ]; then
        source "$CONDA_PREFIX/etc/profile.d/conda.sh"
    fi
    conda activate "$env_name"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}已进入环境：$env_name${RESET}"
    else
        echo -e "${RED}进入环境失败，请检查环境名称。${RESET}"
    fi
}

# 退出虚拟环境
function deactivate_env() {
    if [ -n "$CONDA_PREFIX" ]; then
        source "$CONDA_PREFIX/etc/profile.d/conda.sh"
    fi
    conda deactivate
    echo -e "${GREEN}已退出当前虚拟环境。${RESET}"
}

# 创建虚拟环境
function create_env() {
    echo -e "${YELLOW}请输入要创建的虚拟环境名称：${RESET}"
    read env_name
    if [ -z "$env_name" ]; then
        echo -e "${RED}环境名称不能为空。${RESET}"
        return
    fi
    if [[ ! "$env_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}环境名称只能包含字母、数字、下划线和短横线。${RESET}"
        return
    fi
    echo -e "${YELLOW}请输入Python版本（如 3.10，留空则默认）：${RESET}"
    read py_ver
    echo -e "${YELLOW}请输入要预装的包（如 numpy pandas，留空则不安装）：${RESET}"
    read pkgs
    if [ -n "$CONDA_PREFIX" ]; then
        source "$CONDA_PREFIX/etc/profile.d/conda.sh"
    fi
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main >/dev/null 2>&1
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r >/dev/null 2>&1
    cmd="conda create -y -n \"$env_name\""
    if [ -n "$py_ver" ]; then
        cmd+=" python=$py_ver"
    fi
    if [ -n "$pkgs" ]; then
        cmd+=" $pkgs"
    fi
    echo -e "${YELLOW}即将执行：$cmd${RESET}"
    eval $cmd
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}虚拟环境 $env_name 创建成功。${RESET}"
    else
        echo -e "${RED}虚拟环境创建失败。${RESET}"
    fi
}

# 修复conda环境设置
function fix_conda_env() {
    if [ -n "$CONDA_PREFIX" ]; then
        "$CONDA_PREFIX/bin/conda" init
        # 禁用 base 环境自动激活
        "$CONDA_PREFIX/bin/conda" config --set auto_activate_base false
        # 设置提示符只显示环境名称
        "$CONDA_PREFIX/bin/conda" config --set env_prompt '({name}) '
        echo -e "${GREEN}已执行 conda init，禁用 base 环境自动激活，并设置提示符只显示环境名称，请重启终端或执行 source ~/.bashrc 使设置生效。${RESET}"
    else
        echo -e "${RED}未检测到 Miniconda 安装目录，无法修复。${RESET}"
    fi
}

# 主菜单
function main_menu() {
    while true; do
        echo -e "\n${YELLOW}请选择操作：${RESET}"
        echo "1. 检查 Miniconda 是否安装"
        echo "2. 安装 Miniconda"
        echo "3. 设置虚拟环境目录"
        echo "4. 查询虚拟环境 (conda env list)"
        # echo "5. 进入虚拟环境"
        echo "6. 退出虚拟环境"
        echo "7. 创建虚拟环境"
        echo "8. 退出脚本"
        echo "9. 修复conda环境设置 (自动执行conda init)"
        read -p "请输入选项 [1-9]: " choice
        case $choice in
            1) check_miniconda_installed ;;
            2) install_miniconda ;;
            3) set_envs_dir ;;
            4) list_envs ;;
            5) activate_env ;;
            6) deactivate_env ;;
            7) create_env ;;
            8) echo -e "${GREEN}再见！${RESET}"; exit 0 ;;
            9) fix_conda_env ;;
            *) echo -e "${RED}无效选项，请重新输入。${RESET}" ;;
        esac
    done
}

# 启动主菜单
main_menu 