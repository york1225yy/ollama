#!/bin/bash
#================================================================
# 02_install_ollama.sh
# 安装 Ollama 并拉取 Qwen2.5-VL 多模态模型
# 使用方法: sudo bash 02_install_ollama.sh
#================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/configs/env.conf" 2>/dev/null || true

OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5vl:7b}"

echo "=========================================="
echo "  [Step 1/3] 安装 Ollama..."
echo "=========================================="

if ! command -v ollama &> /dev/null; then
    echo "正在下载并安装 Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo "Ollama 安装完成"
else
    echo "Ollama 已安装: $(ollama --version)"
fi

echo "=========================================="
echo "  [Step 2/3] 启动 Ollama 服务..."
echo "=========================================="

# 设置环境变量，允许所有地址访问（服务器部署需要）
export OLLAMA_HOST=0.0.0.0:11434

# 检查 Ollama 是否已在运行
if pgrep -x "ollama" > /dev/null 2>&1; then
    echo "Ollama 服务已在运行"
else
    echo "启动 Ollama 服务..."
    nohup ollama serve > /var/log/ollama.log 2>&1 &
    sleep 5
    
    # 验证服务启动
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "Ollama 服务启动成功"
    else
        echo "等待 Ollama 服务启动..."
        sleep 10
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo "Ollama 服务启动成功"
        else
            echo "错误: Ollama 服务启动失败，请检查日志: /var/log/ollama.log"
            exit 1
        fi
    fi
fi

echo "=========================================="
echo "  [Step 3/3] 拉取模型: ${OLLAMA_MODEL}..."
echo "=========================================="
echo ""
echo "模型说明:"
echo "  - 模型: Qwen2.5-VL 7B (多模态视觉语言模型)"
echo "  - 功能: 支持图片理解 + 文本生成"
echo "  - 显存: 约需 8-12GB (适合 24GB GPU)"
echo "  - 用途: 面部照片分析 + 健康建议"
echo ""
echo "注意: 首次拉取模型约需下载 4-5GB，请确保网络稳定..."
echo ""

ollama pull ${OLLAMA_MODEL}

echo ""
echo "=========================================="
echo "  验证模型..."
echo "=========================================="

# 验证模型是否可用
ollama list | grep -i "qwen" && echo "模型拉取成功！" || {
    echo "错误: 模型拉取失败"
    exit 1
}

# 简单测试模型
echo "进行简单模型测试..."
RESPONSE=$(curl -s http://localhost:11434/api/generate -d '{
  "model": "'${OLLAMA_MODEL}'",
  "prompt": "你好，请简单回复确认你已就绪。",
  "stream": false
}' | head -c 500)

if echo "$RESPONSE" | grep -q "response"; then
    echo "模型测试通过！"
else
    echo "警告: 模型响应异常，请手动验证"
    echo "响应: $RESPONSE"
fi

echo ""
echo "=========================================="
echo "  Ollama + Qwen2.5-VL 部署完成！"
echo "=========================================="
echo ""
echo "  服务地址: http://localhost:11434"
echo "  已加载模型: ${OLLAMA_MODEL}"
echo "  日志文件: /var/log/ollama.log"
echo ""
echo "  可用 API 端点:"
echo "    GET  /api/tags     - 列出模型"
echo "    POST /api/generate - 文本生成"
echo "    POST /api/chat     - 对话（支持图片）"
echo ""
echo "  图片+文本测试命令:"
echo '    curl http://localhost:11434/api/chat -d '"'"'{'
echo '      "model": "'${OLLAMA_MODEL}'",'
echo '      "messages": [{'
echo '        "role": "user",'
echo '        "content": "描述这张图片",'
echo '        "images": ["base64编码的图片"]'
echo '      }]'
echo '    }'"'"''
echo ""
echo "下一步: 运行 03_deploy_dify.sh"
