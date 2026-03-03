#!/bin/bash
# ============================================================
# 容器环境预棄检查脚本
# 适用于已配置好的容器环境（如 PyTorch 容器）
# 该脚本不安装任何软件，仅做环境预棄
# ============================================================

set -e

echo "========================================="
echo "  容器环境预棄检查"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check_pass() { echo -e "${GREEN}✓ $1${NC}"; PASS=$((PASS+1)); }
check_fail() { echo -e "${RED}✗ $1${NC}"; FAIL=$((FAIL+1)); }
check_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# ========== 1. NVIDIA GPU 可用性 ==========
echo -e "\n${YELLOW}[1/3] 检查 NVIDIA GPU...${NC}"
if nvidia-smi > /dev/null 2>&1; then
    check_pass "NVIDIA GPU 可用"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
    check_fail "nvidia-smi 不可用 — 请确认容器已挂载 GPU 设备 (--gpus all 或 --device)"
    echo -e "${YELLOW}提示: 启动容器时需加参数: docker run --gpus all ...${NC}"
fi

# ========== 2. Docker 可用性 ==========
echo -e "\n${YELLOW}[2/3] 检查 Docker 可用性（用于部署 Dify）...${NC}"
if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
    DOCKER_VER=$(docker --version)
    check_pass "Docker 可用: $DOCKER_VER"
    if docker compose version > /dev/null 2>&1; then
        check_pass "Docker Compose 插件可用"
    else
        check_warn "Docker Compose 插件不可用，尝试 docker-compose..."  
        if command -v docker-compose > /dev/null 2>&1; then
            check_pass "docker-compose (standalone) 可用"
        else
            check_fail "Docker Compose 不可用 — Dify 部署需要 Docker Compose"
            echo -e "${YELLOW}提示: 如果容器没有挂载 /var/run/docker.sock，请联系服务器管理员配置。${NC}"
        fi
    fi
elif [ -S /var/run/docker.sock ]; then
    check_warn "/var/run/docker.sock 已挂载，但 docker 命令不在 PATH 中。尝试安装客户端..."
    curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.0.3.tgz | \
        tar xz --strip=1 -C /usr/local/bin docker/docker 2>/dev/null && \
        check_pass "Docker 客户端安装成功" || \
        check_fail "Docker 客户端安装失败"
else
    check_fail "Docker 不可用，且 /var/run/docker.sock 未挂载"
    echo -e "${YELLOW}提示: Dify 部署需要现有容器挂载宏机的 Docker socket。"
    echo -e "启动容器时需加参数: -v /var/run/docker.sock:/var/run/docker.sock${NC}"
fi

# ========== 3. 其他依赖 ==========
echo -e "\n${YELLOW}[3/3] 检查其他依赖...${NC}"
for tool in curl git python3; do
    if command -v $tool > /dev/null 2>&1; then
        check_pass "$tool 可用"
    else
        check_fail "$tool 不可用 — 请安装: apt-get install -y $tool"
    fi
done

# ========== 结果 ==========
echo ""
echo -e "${YELLOW}========================================="
echo "  预棄结果: 通过 ${PASS} 项 / 失败 ${FAIL} 项"
echo -e "=========================================${NC}"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}存在失败项，请根据上述提示解决后再继续部署。${NC}"
    exit 1
fi
echo -e "${GREEN}环境预棄通过！${NC}"
