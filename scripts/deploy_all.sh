#!/bin/bash
# ============================================================
# 一键完整部署脚本
# 按顺序执行所有安装步骤
# ============================================================

set -e

echo "╔═══════════════════════════════════════════════╗"
echo "║   面部健康分析 AI - 一键部署                    ║"
echo "║   Ollama + Qwen2.5-VL + Dify                  ║"
echo "╚═══════════════════════════════════════════════╝"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${BLUE}本脚本将依次执行以下步骤:${NC}"
echo "  1. 安装 NVIDIA 驱动 & Docker & NVIDIA Container Toolkit"
echo "  2. 安装 Ollama & 部署 Qwen2.5-VL:7b 模型"
echo "  3. 部署 Dify 平台"
echo ""

read -p "是否继续? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消"
    exit 0
fi

# ========== Step 1: NVIDIA + Docker ==========
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 1/3: NVIDIA 驱动 & Docker 环境${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/install_nvidia.sh"

# ========== Step 2: Ollama + Model ==========
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 2/3: Ollama & Qwen2.5-VL 模型${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/install_ollama.sh"

# ========== Step 3: Dify ==========
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 3/3: Dify 平台${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/setup_dify.sh"

# ========== 完成 ==========
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 部署完成！                       ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║  Dify 平台: http://${LOCAL_IP}              ${NC}"
echo -e "${GREEN}║  Ollama API: http://${LOCAL_IP}:11434       ${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║  下一步:                                      ║${NC}"
echo -e "${GREEN}║  1. 浏览器访问 Dify 创建管理员账户            ║${NC}"
echo -e "${GREEN}║  2. 在 Dify 中添加 Ollama 模型提供商          ║${NC}"
echo -e "${GREEN}║  3. 创建「面部健康分析」应用                   ║${NC}"
echo -e "${GREEN}║  详见 README.md                               ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
