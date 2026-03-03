#!/bin/bash
#================================================================
# deploy_all.sh - 一键部署脚本（按顺序执行所有步骤）
# 使用方法: sudo bash deploy_all.sh
#================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║   AI 面部健康分析系统 - 一键部署                 ║"
echo "║   Ollama + Qwen2.5-VL + Dify                    ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 sudo 运行此脚本"
    echo "用法: sudo bash deploy_all.sh"
    exit 1
fi

echo "即将开始部署，包含以下步骤:"
echo "  1. 安装系统依赖 (PostgreSQL, Redis, Python, Node.js)"
echo "  2. 安装 Ollama + 拉取 Qwen2.5-VL 模型"
echo "  3. 部署 Dify (API + Worker + Web)"
echo "  4. 配置说明"
echo ""
read -p "确认开始部署？(y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "部署已取消"
    exit 0
fi

echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 1: 安装系统依赖"
echo "══════════════════════════════════════════════════"
bash "$SCRIPT_DIR/scripts/01_install_dependencies.sh"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 2: 安装 Ollama + 模型"
echo "══════════════════════════════════════════════════"
bash "$SCRIPT_DIR/scripts/02_install_ollama.sh"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 3: 部署 Dify"
echo "══════════════════════════════════════════════════"
bash "$SCRIPT_DIR/scripts/03_deploy_dify.sh"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 4: 启动所有服务"
echo "══════════════════════════════════════════════════"
bash "$SCRIPT_DIR/scripts/start_services.sh"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Phase 5: 应用配置指南"
echo "══════════════════════════════════════════════════"
bash "$SCRIPT_DIR/scripts/04_configure_dify_app.sh"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║   🎉 部署完成！                                  ║"
echo "║                                                  ║"
echo "║   请在浏览器中访问:                              ║"
echo "║   http://<服务器IP>:3000                         ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
