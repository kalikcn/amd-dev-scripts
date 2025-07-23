#!/bin/bash

# 交互式选择是否更新系统
read -p "是否更新系统和软件包？[Y/n]: " update_choice
update_choice=${update_choice:-Y}
if [[ "$update_choice" =~ ^[Yy]$ ]]; then
    sudo apt update && sudo apt upgrade -y
    echo "系统已更新。"
else
    echo "跳过系统更新。"
fi

# 交互式选择是否安装常用软件
read -p "是否安装常用软件包？[Y/n]: " install_choice
install_choice=${install_choice:-Y}
if [[ "$install_choice" =~ ^[Yy]$ ]]; then
    SOFTWARE_LIST="psmisc nc net-tools rsync vim lrzsz ntp libzstd1 openssl tree iotop git curl wget htop unzip zip tar build-essential"
    for pkg in $SOFTWARE_LIST; do
        if apt-cache show "$pkg" > /dev/null 2>&1; then
            echo "安装 $pkg ..."
            sudo apt install -y "$pkg"
        else
            echo "$pkg 不在软件源中，跳过。"
        fi
    done
    echo "常用软件包安装完成。"
else
    echo "跳过常用软件包安装。"
fi

# 3. 交互式用户管理脚本
user_manage_menu() {
    while true; do
        echo "\n===== 用户管理菜单 ====="
        echo "1. 创建新用户"
        echo "2. 修改用户密码"
        echo "3. 修改用户名"
        echo "4. 查看用户列表"
        echo "5. 查看用户登录情况"
        echo "6. 退出"
        read -p "请选择操作 [1-6]: " choice
        case $choice in
            1)
                read -p "请输入新用户名: " newuser
                read -s -p "请输入密码: " newpass; echo
                read -p "是否赋予sudo权限? [Y/n]: " issudo
                issudo=${issudo:-Y}
                sudo useradd -m "$newuser"
                echo "$newuser:$newpass" | sudo chpasswd
                if [[ "$issudo" =~ ^[Yy]$ ]]; then
                    sudo usermod -aG sudo "$newuser"
                    echo "已赋予sudo权限。"
                fi
                echo "用户 $newuser 创建完成。"
                ;;
            2)
                read -p "请输入要修改密码的用户名: " user
                read -s -p "请输入新密码: " pass; echo
                echo "$user:$pass" | sudo chpasswd
                echo "密码已修改。"
                ;;
            3)
                read -p "请输入当前用户名: " olduser
                read -p "请输入新用户名: " newuser
                sudo usermod -l "$newuser" "$olduser"
                sudo usermod -d "/home/$newuser" -m "$newuser"
                echo "用户名已修改。"
                ;;
            4)
                echo "系统用户列表："
                cut -d: -f1 /etc/passwd
                ;;
            5)
                echo "最近登录用户："
                last -a | head -n 20
                ;;
            6)
                break
                ;;
            *)
                echo "无效选择，请重新输入。"
                ;;
        esac
    done
}

user_manage_menu
