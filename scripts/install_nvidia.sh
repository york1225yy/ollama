#!/bin/bash
# ============================================================
# NVIDIA 驱动和容器工具包安装脚本
# 适用于 Ubuntu 22.04 / 24.04
# ============================================================

set -e

echo "========================================="
echo "  NVIDIA 驱动 & Container Toolkit 安装"
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

# ========== 1. 检查 NVIDIA GPU ==========
echo -e "\n${YELLOW}[1/5] 检查 NVIDIA GPU...${NC}"
if lspci | grep -i nvidia > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 检测到 NVIDIA GPU${NC}"
    lspci | grep -i nvidia
else
    echo -e "${RED}✗ 未检测到 NVIDIA GPU，请确认硬件${NC}"
    exit 1
fi

# ========== 2. 安装 NVIDIA 驱动 ==========
echo -e "\n${YELLOW}[2/5] 检查/安装 NVIDIA 驱动...${NC}"
if nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}✓ NVIDIA 驱动已安装${NC}"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
    echo "安装 NVIDIA 驱动..."
    apt-get update
    apt-get install -y ubuntu-drivers-common
    ubuntu-drivers autoinstall
    echo -e "${YELLOW}⚠ NVIDIA 驱动安装完成，可能需要重启系统${NC}"
    echo "请重启后重新运行此脚本验证"
fi

# ========== 3. 安装 Docker ==========
echo -e "\n${YELLOW}[3/5] 检查/安装 Docker...${NC}"
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

# ========== 4. 安装 NVIDIA Container Toolkit ==========
echo -e "\n${YELLOW}[4/5] 检查/安装 NVIDIA Container Toolkit...${NC}"
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

# ========== 5. 验证 ==========
echo -e "\n${YELLOW}[5/5] 验证安装...${NC}"
echo "--- NVIDIA 驱动 ---"
if nvidia-smi > /dev/null 2>&1; then
    nvidia-smi
    echo -e "${GREEN}✓ NVIDIA 驱动正常${NC}"
else
    echo -e "${RED}✗ NVIDIA 驱动异常，请重启系统后重试${NC}"
fi

echo ""
echo "--- Docker GPU 支持 ---"
if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker GPU 支持正常${NC}"
else
    echo -e "${YELLOW}⚠ Docker GPU 测试未通过，可能需要重启 Docker 服务${NC}"
fi

echo ""
echo -e "${GREEN}========================================="
echo "  环境检查完成！"
echo "=========================================${NC}"
