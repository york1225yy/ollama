#!/bin/bash
#================================================================
# setup_firewall.sh - 防火墙配置脚本
# 开放必要的端口以允许远程访问
# 使用方法: sudo bash setup_firewall.sh
#================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/configs/env.conf" 2>/dev/null || true

DIFY_API_PORT="${DIFY_API_PORT:-5001}"
DIFY_WEB_PORT="${DIFY_WEB_PORT:-3000}"

echo "=========================================="
echo "  配置防火墙规则"
echo "=========================================="

# 检查是否安装了 ufw
if command -v ufw &> /dev/null; then
    echo "使用 UFW 配置防火墙..."
    
    # 允许 SSH
    ufw allow 22/tcp comment "SSH"
    
    # 允许 Dify Web (用户访问)
    ufw allow ${DIFY_WEB_PORT}/tcp comment "Dify Web UI"
    
    # 允许 Dify API
    ufw allow ${DIFY_API_PORT}/tcp comment "Dify API"
    
    # Ollama API (可选，如果需要外部直接调用)
    # ufw allow 11434/tcp comment "Ollama API"
    
    # 启用防火墙
    echo "y" | ufw enable 2>/dev/null || true
    
    ufw status
    
elif command -v iptables &> /dev/null; then
    echo "使用 iptables 配置防火墙..."
    
    # 允许 SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # 允许 Dify Web
    iptables -A INPUT -p tcp --dport ${DIFY_WEB_PORT} -j ACCEPT
    
    # 允许 Dify API
    iptables -A INPUT -p tcp --dport ${DIFY_API_PORT} -j ACCEPT
    
    echo "iptables 规则已添加"
    iptables -L -n | grep -E "(${DIFY_WEB_PORT}|${DIFY_API_PORT}|22)"
    
else
    echo "未检测到防火墙工具 (ufw/iptables)"
    echo "请确保以下端口可以从外部访问:"
fi

echo ""
echo "=========================================="
echo "  需要开放的端口:"
echo "=========================================="
echo ""
echo "  端口          用途              必要性"
echo "  ────────────────────────────────────────"
echo "  22/tcp        SSH远程管理       必须"
echo "  ${DIFY_WEB_PORT}/tcp       Dify Web界面     必须"
echo "  ${DIFY_API_PORT}/tcp       Dify API         必须"
echo "  11434/tcp     Ollama API       可选(仅内部)"
echo ""
echo "  如果使用云服务器，还需要在云平台安全组中开放以上端口"
