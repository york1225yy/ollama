#!/bin/bash
#================================================================
# 01_install_dependencies.sh
# 安装系统基础依赖（PostgreSQL, Redis, Python, Node.js 等）
# 适用于 Ubuntu 22.04 / 24.04
# 使用方法: sudo bash 01_install_dependencies.sh
#================================================================

set -e

echo "=========================================="
echo "  [Step 1/7] 更新系统包..."
echo "=========================================="
apt-get update && apt-get upgrade -y

echo "=========================================="
echo "  [Step 2/7] 安装基础工具..."
echo "=========================================="
apt-get install -y \
    curl wget git build-essential software-properties-common \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncurses5-dev libncursesw5-dev xz-utils \
    tk-dev libxml2-dev libxmlsec1-dev liblzma-dev \
    pkg-config libpq-dev gcc g++ make lsof net-tools \
    ca-certificates gnupg

echo "=========================================="
echo "  [Step 3/7] 安装 PostgreSQL 16..."
echo "=========================================="
# 添加 PostgreSQL 官方仓库
if ! command -v psql &> /dev/null; then
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt-get update
    apt-get install -y postgresql-16 postgresql-client-16 postgresql-server-dev-16
    # 安装 pgvector 扩展（Dify 需要）
    apt-get install -y postgresql-16-pgvector || {
        echo "从源码编译 pgvector..."
        cd /tmp
        git clone --branch v0.7.4 https://github.com/pgvector/pgvector.git
        cd pgvector
        make PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
        make install PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
        cd /
        rm -rf /tmp/pgvector
    }
    echo "PostgreSQL 16 安装完成"
else
    echo "PostgreSQL 已安装，跳过"
fi

echo "=========================================="
echo "  [Step 4/7] 安装 Redis..."
echo "=========================================="
if ! command -v redis-server &> /dev/null; then
    apt-get install -y redis-server
    echo "Redis 安装完成"
else
    echo "Redis 已安装，跳过"
fi

echo "=========================================="
echo "  [Step 5/7] 安装 Python 3.11..."
echo "=========================================="
# Dify 推荐 Python 3.11
if ! python3.11 --version &> /dev/null; then
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update
    apt-get install -y python3.11 python3.11-venv python3.11-dev python3.11-distutils
    # 安装 pip
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11
    echo "Python 3.11 安装完成"
else
    echo "Python 3.11 已安装，跳过"
fi

# 安装 poetry (Dify 使用 poetry 管理依赖)
if ! command -v poetry &> /dev/null; then
    curl -sSL https://install.python-poetry.org | python3.11 -
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "Poetry 安装完成"
else
    echo "Poetry 已安装，跳过"
fi

echo "=========================================="
echo "  [Step 6/7] 安装 Node.js 22.x..."
echo "=========================================="
if ! node --version 2>/dev/null | grep -q "v22"; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
    # 安装 pnpm 和 yarn（Dify 前端可能需要）
    npm install -g pnpm@9 yarn
    echo "Node.js 22.x 安装完成"
else
    echo "Node.js 22.x 已安装，跳过"
    npm install -g pnpm@9 yarn 2>/dev/null || true
fi

echo "=========================================="
echo "  [Step 7/7] 安装 NVIDIA CUDA Toolkit..."
echo "=========================================="
if ! command -v nvidia-smi &> /dev/null; then
    echo "警告: 未检测到 NVIDIA GPU 驱动。"
    echo "请确保宿主机已安装 NVIDIA 驱动，并在启动容器时使用 --gpus all 参数。"
    echo "如果是直接在物理机上运行，请先安装 NVIDIA 驱动:"
    echo "  sudo apt install nvidia-driver-535"
    echo "  sudo reboot"
else
    echo "NVIDIA GPU 驱动已检测到:"
    nvidia-smi
fi

echo ""
echo "=========================================="
echo "  所有基础依赖安装完成！"
echo "=========================================="
echo ""
echo "已安装组件:"
echo "  - PostgreSQL 16 + pgvector"
echo "  - Redis"
echo "  - Python 3.11 + Poetry"
echo "  - Node.js 20.x + pnpm"
echo "  - 系统构建工具"
echo ""
echo "下一步: 运行 02_install_ollama.sh"
