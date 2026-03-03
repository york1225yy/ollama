#!/bin/bash
# ============================================================
# Ollama 安装和 Qwen2.5-VL 模型部署脚本
# ============================================================

set -e

echo "========================================="
echo "  Ollama 安装 & Qwen2.5-VL 模型部署"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ========== 1. 安装 Ollama ==========
echo -e "\n${YELLOW}[1/4] 检查/安装 Ollama...${NC}"
if command -v ollama > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama 已安装: $(ollama --version)${NC}"
else
    echo "正在安装 Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo -e "${GREEN}✓ Ollama 安装完成${NC}"
fi

# ========== 2. 以后台进程方式启动 Ollama ==========
echo -e "\n${YELLOW}[2/4] 启动 Ollama 服务（容器环境，不使用 systemd）...${NC}"

# 检查是否已在运行
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama 已在运行${NC}"
else
    echo "以后台进程方式启动 Ollama..."
    export OLLAMA_HOST=0.0.0.0:11434
    export OLLAMA_ORIGINS='*'
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    OLLAMA_PID=$!
    echo "$OLLAMA_PID" > /tmp/ollama.pid
    echo "进程 PID: $OLLAMA_PID"

    # 等待启动
    echo "等待 Ollama API 就绪..."
    for i in $(seq 1 30); do
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Ollama 服务已就绪 (PID: $OLLAMA_PID)${NC}"
            break
        fi
        if [ "$i" -eq 30 ]; then
            echo -e "${RED}✗ Ollama 启动超时，请检查日志: tail -20 /tmp/ollama.log${NC}"
            exit 1
        fi
        sleep 2
    done
fi

# ========== 3. 拉取 Qwen2.5-VL 模型 ==========
echo -e "\n${YELLOW}[3/4] 拉取 Qwen2.5-VL:7b 模型...${NC}"
echo "模型大小约 4.7GB，下载时间取决于网络速度..."

if ollama list | grep -q "qwen2.5-vl:7b"; then
    echo -e "${GREEN}✓ Qwen2.5-VL:7b 模型已存在${NC}"
else
    echo "正在拉取模型（可能需要几分钟）..."
    ollama pull qwen2.5-vl:7b
    echo -e "${GREEN}✓ Qwen2.5-VL:7b 模型拉取完成${NC}"
fi

# ========== 4. 验证模型 ==========
echo -e "\n${YELLOW}[4/4] 验证模型部署...${NC}"

echo "已安装的模型列表:"
ollama list

# 简单测试
echo ""
echo "进行简单文本测试..."
RESPONSE=$(curl -s http://localhost:11434/api/generate -d '{
    "model": "qwen2.5-vl:7b",
    "prompt": "你好，请用一句话介绍你自己",
    "stream": false
}' 2>&1)

if echo "$RESPONSE" | grep -q "response"; then
    echo -e "${GREEN}✓ 模型响应正常${NC}"
    echo "模型回复: $(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','')[:100])" 2>/dev/null || echo "解析响应中...")"
else
    echo -e "${YELLOW}⚠ 模型测试响应异常，请检查 GPU 是否可用${NC}"
    echo "响应内容: $RESPONSE"
fi

echo ""
echo -e "${GREEN}========================================="
echo "  Ollama + Qwen2.5-VL 部署完成！"
echo "  API 地址: http://localhost:11434"
echo "  模型名称: qwen2.5-vl:7b"
echo "=========================================${NC}"
