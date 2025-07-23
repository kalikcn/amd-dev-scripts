# 🔧 AMD 开发者常用脚本集合（amd-dev-scripts）

本项目旨在为使用 **AMD 显卡**（如 RX 7900 / RX 9070 XT）进行 AI 开发、系统配置、工具安装的开发者，提供一套高效、实用、可复用的自动化脚本集合，适配 Ubuntu 系统和 ROCm 平台，帮助你快速完成环境搭建、模型部署和资源管理等任务。

---

## 📁 项目目录结构

```bash
amd-dev-scripts/
├── scripts/
│   ├── basic/           # 基础系统配置（如源更新、防火墙设置、常用工具安装）
│   │   └── ubuntu_basics.sh
│   ├── install/         # 软件安装脚本（如 Miniconda、ROCm、PyTorch）
│   │   └── install_miniconda.sh
│   ├── ai/              # AI 开发相关脚本（环境构建、微调、模型部署）
│   │   └── setup_llama_env.sh
│   ├── utils/           # 系统工具类脚本（日志清理、硬件检测、自动同步等）
│   │   └── sync_to_disk.sh
├── examples/            # 示例配置文件（如 conda 环境、训练参数模板等）
├── docs/                # 使用文档（如 AI 环境搭建指南）
├── LICENSE              # 开源许可证（MIT）
└── README.md            # 项目说明文件
```

## 🚀 快速开始

**1. 克隆项目**
git clone <https://github.com/kalikcn/amd-dev-scripts.git>
cd amd-dev-scripts

**2. 执行基础配置脚本**
bash scripts/basic/ubuntu_basics.sh

**3. 安装 Miniconda**
bash scripts/install/install_miniconda.sh

**4. 运行 AI 环境配置脚本**
bash scripts/ai/setup_llama_env.sh

**🔍 使用场景**
适配 AMD 显卡开发环境（ROCm 6.x、PyTorch、Transformers 等）
训练或微调 LLaMA / Qwen / DeepSeek 等大语言模型
部署如 GPT-SoVITS、ComfyUI 等 AI 项目
自动同步训练数据、环境备份、日志清理

🧠 系统要求
操作系统：Ubuntu 22.04 / 24.04

GPU：支持 ROCm 的 AMD 显卡（如 RX 7900 XT、RX 9070 XT）

🤝 贡献方式
欢迎提交脚本或优化建议！

📜 开源协议
本项目基于 MIT License 开源发布，您可以自由使用、修改和分发，但请保留原作者信息。

🙋 联系作者
GitHub: kalikcn
e-mail：kalikcn5569@proton.me

项目交流 / 问题反馈：欢迎通过 GitHub Issue 提出建议和需求！

本项目仍在持续完善中，欢迎 Star ⭐ 和贡献代码！
