#!/bin/bash

echo "备份当前 /etc/apt/sources.list ..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak_$(date +%F_%T)

echo "清空 /etc/apt/sources.list ..."
sudo bash -c '> /etc/apt/sources.list'

echo "更新软件源索引 ..."
sudo apt update

echo "完成。当前软件源配置仅使用 /etc/apt/sources.list.d/*.sources 文件。"

