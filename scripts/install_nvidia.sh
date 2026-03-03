#!/bin/bash
# ============================================================
# Docker & NVIDIA Container Toolkit 安装脚本
# 适用于 Ubuntu 22.04 / 24.04
# 注意：假设 NVIDIA 驱动已提前安装完毕
# ============================================================

set -e

echo "========================================="
echo "  Docker & NVIDIA Container Toolkit 安装"
echo "========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以 root 或使用 sudo 运行此脚本${NC}"
    exit 1
fi

# ========== 前置验证：确认 NVIDIA 驱动已就绪 ==========
echo -e "\n${YELLOW}[前置检查] 验证 NVIDIA 驱动...${NC}"
if nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}✓ NVIDIA 驱动已就绪${NC}"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
    echo -e "${RED}✗ nvidia-smi 执行失败，请确认 NVIDIA 驱动已正确安装后重试${NC}"
    exit 1
fi

# ========== 1. 安装 Docker ==========
echo -e "\n${YELLOW}[1/3] 检查/安装 Docker...${NC}"
if command -v docker > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker 已安装: $(docker --version)${NC}"
else
    echo "安装 Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker 安装完成${NC}"
fi

# ========== 2. 安装 NVIDIA Container Toolkit ==========
echo -e "\n${YELLOW}[2/3] 检查/安装 NVIDIA Container Toolkit...${NC}"
if dpkg -l | grep -q nvidia-container-toolkit; then
    echo -e "${GREEN}✓ NVIDIA Container Toolkit 已安装${NC}"
else
    echo "安装 NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    echo -e "${GREEN}✓ NVIDIA Container Toolkit 安装完成${NC}"
fi

# ========== 3. 验证 ==========
echo -e "\n${YELLOW}[3/3] 验证安装...${NC}"

echo "--- Docker GPU 支持 ---"
if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker GPU 支持正常${NC}"
else
    echo -e "${YELLOW}⚠ Docker GPU 测试未通过，可能需要重启 Docker 服务: sudo systemctl restart docker${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "  Docker & NVIDIA Container Toolkit 安装完成！"
echo "=========================================${NC}"
