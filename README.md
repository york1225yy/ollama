# AI 面部健康分析系统

> 基于 Ollama + Qwen2.5-VL + Dify 的多模态大模型应用  
> 上传面部照片 → AI 分析健康状况 → 输出文字建议

---

## 📌 项目概述

本项目实现了一个 **AI 面部健康分析助手**，用户通过网页上传一张面部照片并输入文字需求（例如："请根据我的面部照片判断我的健康情况"），系统会调用多模态大模型分析照片并返回健康评估和生活建议。

**核心特点：**
- 使用 **Qwen2.5-VL 7B** 多模态模型，支持图文理解
- 通过 **Ollama** 进行模型部署和推理
- 通过 **Dify** 源码部署提供可视化 Web 界面和上下文记忆
- 支持远程网络访问（无需显示器的服务器环境）

### 技术架构

```
用户浏览器(远程网络访问)
    │
    ▼
┌──────────────────┐
│   Nginx(可选)    │  ← 反向代理 (端口 80)
└────────┬─────────┘
         │
┌────────▼─────────┐
│   Dify Web UI    │  ← Next.js 前端 (端口 3000)
│   (可视化界面)    │     上下文记忆 / 对话管理
└────────┬─────────┘
         │
┌────────▼─────────┐
│   Dify API       │  ← Flask 后端 (端口 5001)
│   + Celery Worker│     应用编排 / 提示词管理
└────────┬─────────┘
         │
┌────────▼─────────┐
│   Ollama         │  ← 模型推理服务 (端口 11434)
│   Qwen2.5-VL 7B │     多模态视觉语言模型
└────────┬─────────┘
         │
    ┌────▼────┐
    │ GPU 24G │
    └─────────┘
```

### 模型选择说明

| 模型 | 参数量 | 显存占用 | 说明 |
|------|--------|----------|------|
| **qwen2.5-vl:7b** ✅ | 7B | ~8-12GB | **推荐**，24G 显存充裕，推理速度快 |
| qwen2.5-vl:32b | 32B | ~20-24GB | 效果更好但显存紧张，推理较慢 |
| qwen2.5-vl:3b | 3B | ~4-6GB | 轻量但分析能力有限 |

选择 **Qwen2.5-VL 7B** 的理由：
- ✅ 支持图文多模态理解（Vision-Language），可以分析上传的面部照片
- ✅ 7B 参数量在 24G 显存下运行流畅，响应速度快
- ✅ Ollama 官方仓库直接支持，一键拉取
- ✅ 中文能力优秀（Qwen 系列强项），输出自然流畅

---

## 📋 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 操作系统 | Ubuntu 22.04+ | Ubuntu 24.04 LTS |
| GPU | NVIDIA GPU 16GB+ | NVIDIA GPU 24GB |
| GPU 驱动 | NVIDIA Driver 535+ | 最新稳定版 |
| 内存 | 16GB | 32GB+ |
| 磁盘 | 50GB 可用 | 100GB+ |
| 网络 | 可联网（首次部署需下载模型） | 稳定宽带 |

---

## 📁 项目结构

```
ollama/
├── README.md                         # 本文档（完整部署说明）
├── deploy_all.sh                     # 一键部署脚本（推荐）
├── configs/
│   ├── env.conf                      # 统一配置文件（端口/密码/模型等）
│   └── system_prompt.txt             # Dify 应用系统提示词模板
└── scripts/
    ├── 01_install_dependencies.sh    # Step1: 安装系统依赖
    ├── 02_install_ollama.sh          # Step2: 安装 Ollama + 拉取模型
    ├── 03_deploy_dify.sh             # Step3: Dify 源码部署
    ├── 04_configure_dify_app.sh      # Step4: Dify 应用配置指南
    ├── start_services.sh             # 启动所有服务
    ├── stop_services.sh              # 停止所有服务
    ├── check_status.sh               # 检查服务状态
    ├── setup_firewall.sh             # 防火墙端口配置
    └── setup_nginx.sh                # Nginx 反向代理配置（可选）
```

---

## 🚀 部署步骤

### 前提条件

确保你的 Ubuntu 服务器已安装 NVIDIA GPU 驱动：
```bash
# 检查 GPU 驱动
nvidia-smi

# 如果未安装驱动：
sudo apt install nvidia-driver-535
sudo reboot
```

### 方式一：一键部署（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/york1225yy/ollama.git
cd ollama

# 2. 修改配置（建议修改默认密码）
vim configs/env.conf

# 3. 一键部署（需要 sudo 权限）
sudo bash deploy_all.sh
```

脚本会按顺序自动执行所有部署步骤，包括安装依赖、部署 Ollama、部署 Dify、启动服务。

### 方式二：分步部署

如果需要更精细地控制每个步骤，可以分步执行：

#### Step 1: 安装系统依赖

```bash
sudo bash scripts/01_install_dependencies.sh
```

安装内容：
- **PostgreSQL 16** + pgvector 扩展（Dify 数据存储和向量检索）
- **Redis**（Dify 缓存和 Celery 消息队列）
- **Python 3.11** + Poetry（Dify API 后端运行环境）
- **Node.js 20.x** + pnpm（Dify Web 前端构建工具）
- 系统构建工具和其他必要依赖

#### Step 2: 安装 Ollama 并拉取模型

```bash
sudo bash scripts/02_install_ollama.sh
```

此步骤会：
1. 安装 Ollama 推理框架
2. 启动 Ollama 服务（监听 0.0.0.0:11434）
3. 拉取 Qwen2.5-VL 7B 多模态模型（约 4-5GB）
4. 自动验证模型可用性

验证命令：
```bash
# 检查 Ollama 服务
curl http://localhost:11434/api/tags

# 测试文本对话
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-vl:7b",
  "prompt": "你好，请简单介绍你自己",
  "stream": false
}'

# 测试多模态（图片+文字）
curl http://localhost:11434/api/chat -d '{
  "model": "qwen2.5-vl:7b",
  "messages": [{
    "role": "user",
    "content": "描述这张图片中的人物特征",
    "images": ["<图片的base64编码>"]
  }],
  "stream": false
}'
```

#### Step 3: 部署 Dify（源码方式，非 Docker）

```bash
sudo bash scripts/03_deploy_dify.sh
```

由于是在已有容器内运行（无法使用 Docker daemon），此脚本从源码部署 Dify 的所有组件：

1. **克隆源码**：从 GitHub 克隆 Dify 到 `/opt/dify`
2. **配置 PostgreSQL**：
   - 初始化数据目录
   - 创建 `dify` 用户和数据库
   - 安装 `pgvector`、`uuid-ossp` 扩展
   - 配置认证方式
3. **配置 Redis**：设置密码，绑定 localhost
4. **安装 API 后端**：
   - 创建 `/opt/dify/api/.env` 环境配置
   - 使用 Poetry 安装 Python 依赖
5. **数据库迁移**：执行 Flask-Migrate 迁移
6. **构建 Web 前端**：
   - 创建 `.env.local` 前端配置
   - 安装 Node.js 依赖
   - 构建 Next.js 生产版本
7. **创建服务管理**：
   - systemd 服务文件（物理机使用）
   - start/stop/check 管理脚本

#### Step 4: 启动所有服务

```bash
sudo bash scripts/start_services.sh
```

启动顺序：PostgreSQL → Redis → Ollama → Dify API + Worker → Dify Web

#### Step 5: 在浏览器中配置 Dify 应用

```bash
# 先查看配置指南
bash scripts/04_configure_dify_app.sh
```

然后按照下文"网页配置详细指南"在浏览器中完成操作。

---

## 🔧 服务管理

### 日常操作命令

```bash
# 启动所有服务
sudo bash scripts/start_services.sh

# 停止所有服务
sudo bash scripts/stop_services.sh

# 检查所有服务状态（显示各组件运行状态和 GPU 使用情况）
bash scripts/check_status.sh
```

### systemd 管理（物理机推荐）

```bash
# 启用开机自启动
sudo systemctl enable postgresql redis-server ollama dify-api dify-worker dify-web

# 单独管理服务
sudo systemctl start|stop|restart|status ollama
sudo systemctl start|stop|restart|status dify-api
sudo systemctl start|stop|restart|status dify-worker
sudo systemctl start|stop|restart|status dify-web
```

### 查看日志

```bash
tail -f /var/log/ollama.log        # Ollama 推理日志
tail -f /var/log/dify/api.log      # Dify API 后端日志
tail -f /var/log/dify/worker.log   # Dify Celery Worker 日志
tail -f /var/log/dify/web.log      # Dify Web 前端日志
```

---

## 🌐 网页配置详细指南

服务启动后，需要在浏览器中完成以下配置。

### Step 1: 初始化 Dify 管理员账户

在浏览器中访问：`http://<服务器IP>:3000/install`

- 填写管理员邮箱和密码
- 完成初始化设置

### Step 2: 添加 Ollama 模型提供商

1. 登录后，点击右上角头像 → **设置**
2. 在左侧菜单中选择 **模型提供商**
3. 找到 **Ollama** 并点击 **添加**
4. 填写以下配置：

| 配置项 | 值 |
|--------|-----|
| 模型名称 | `qwen2.5-vl:7b` |
| 基础 URL | `http://localhost:11434`（Dify 和 Ollama 同机部署） |
| 模型类型 | LLM（大语言模型） |
| 支持 Vision | ✅ 开启 |
| 上下文长度 | 32768 |
| 最大 Token 输出 | 8192 |

> **注意**：如果 Dify 和 Ollama 不在同一台机器上，将 `localhost` 替换为 Ollama 所在机器的实际 IP。

5. 点击 **保存**

### Step 3: 创建面部健康分析应用

1. 回到 Dify 首页 → 点击 **创建应用**
2. 选择 **从空白创建**
3. 应用类型：**聊天助手**
4. 应用名称：`AI面部健康分析助手`
5. 描述：`上传面部照片，AI为您分析健康状况并提供建议`

### Step 4: 配置应用编排

**4.1 选择模型**

在编排页面选择 `Ollama → qwen2.5-vl:7b`

**4.2 填写系统提示词**

将 `configs/system_prompt.txt` 中的完整提示词复制到"系统提示词"区域：

```text
你是一位专业的AI健康分析助手，擅长通过面部特征分析来评估用户的健康状况。

## 你的能力：
1. 面部特征分析：观察面部肤色、气色、眼睛、嘴唇等特征
2. 健康状况评估：基于面部观察提供初步健康参考
3. 生活建议：提供饮食、作息、运动等方面的建议

## 输出格式：
### 📋 面部特征观察
### 🔍 健康状况分析
### 💡 改善建议
  1. 饮食建议 / 2. 作息建议 / 3. 运动建议 / 4. 其他建议
### ⚠️ 重要提示
AI面部分析仅供参考，不能替代专业医学诊断。如有健康问题，请及时就医。
```

**4.3 开启功能特性**

| 功能 | 设置 |
|------|------|
| 图片上传 (Vision) | ✅ 开启，允许上传图片，分辨率选 **高 (High)** |
| 对话开场白 | ✅ 开启，内容见下方 |
| 下一步问题建议 | ✅ 开启（可选，提升体验） |

对话开场白内容：
```
👋 您好！我是AI面部健康分析助手。
请上传一张清晰的正面面部照片，我将为您分析健康状况并提供建议。
```

**4.4 设置模型参数**

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| Temperature | 0.3 | 低温度保证分析准确性和一致性 |
| Top P | 0.85 | 适度控制输出多样性 |
| Max Tokens | 4096 | 确保完整输出分析报告 |

### Step 5: 发布并分享

1. 点击右上角 **发布** 按钮
2. 点击 **访问** 或 **分享** 获取独立的 Web App 访问链接
3. 将链接分享给其他用户即可直接使用（无需 Dify 管理员账号）

---

## 🔗 远程访问配置

服务器没有显示器，需通过网络远程访问。以下提供三种方案：

### 方式一：直接 IP + 端口访问（最简单）

```bash
# 开放防火墙端口
sudo bash scripts/setup_firewall.sh
```

访问地址：`http://<服务器IP>:3000`

> 如果使用云服务器，还需在云平台安全组中放行 **3000** 和 **5001** 端口。

### 方式二：Nginx 反向代理（生产环境推荐）

```bash
sudo bash scripts/setup_nginx.sh
```

优点：
- 统一 80 端口访问（用户无需记端口号）
- 自动处理大文件上传（面部照片）
- 支持 WebSocket / SSE 流式输出
- 方便后续添加 HTTPS

访问地址：`http://<服务器IP>`

### 方式三：SSH 隧道（安全临时访问）

在 **本地电脑** 上执行：
```bash
ssh -L 3000:localhost:3000 -L 5001:localhost:5001 user@服务器IP
```

然后在本地浏览器访问：`http://localhost:3000`

---

## ⚙️ 配置文件说明

主配置文件 `configs/env.conf`（部署前建议修改）：

```bash
# Ollama 模型选择
OLLAMA_MODEL="qwen2.5-vl:7b"    # 可改为 :3b(轻量) 或 :32b(效果好但显存紧张)

# 服务端口
DIFY_API_PORT="5001"              # Dify API 后端
DIFY_WEB_PORT="3000"              # Dify Web 前端

# 数据库密码（⚠️ 请在生产环境中修改）
DB_PASSWORD="dify_password_2024"  

# Redis 密码（⚠️ 请在生产环境中修改）
REDIS_PASSWORD="dify_redis_2024"  

# Dify 源码路径
DIFY_DIR="/opt/dify"              
```

---

## 🔍 使用流程

```
1. 打开浏览器 → 访问 http://<服务器IP>:3000
         │
2. 登录 Dify → 打开 "AI面部健康分析助手"
         │
3. 点击 📎 图标 → 上传一张清晰的面部正面照片
         │
4. 输入需求文字: "请根据我上传的面部照片分析我的健康状况"
         │
5. AI 返回分析结果:
   ┌─────────────────────────────────────────┐
   │ 📋 面部特征观察                          │
   │  - 肤色偏暗沉，T区有轻微油腻感          │
   │  - 眼下有轻度黑眼圈                      │
   │  - 嘴唇颜色正常，略有干燥                │
   │                                           │
   │ 🔍 健康状况分析                          │
   │  - 可能存在近期睡眠不足的情况            │
   │  - 皮肤水油平衡可能需要关注              │
   │                                           │
   │ 💡 改善建议                              │
   │  1. 饮食：多饮水，增加蔬果摄入           │
   │  2. 作息：保证7-8小时充足睡眠            │
   │  3. 运动：每天30分钟有氧运动             │
   │  4. 护肤：注意防晒和保湿                 │
   │                                           │
   │ ⚠️ 以上分析仅供参考，如有问题请就医      │
   └─────────────────────────────────────────┘
         │
6. 继续追问细节 → 系统保持上下文记忆
```

---

## ❓ 常见问题排查

### Q1: 模型下载太慢？

```bash
# 使用代理
export http_proxy=http://your-proxy:port
export https_proxy=http://your-proxy:port
ollama pull qwen2.5-vl:7b
```

### Q2: Dify 前端构建失败？

```bash
node --version  # 确保 >= 20.x
cd /opt/dify/web
rm -rf node_modules .next
pnpm install
pnpm build
```

### Q3: PostgreSQL 连接报错？

```bash
sudo service postgresql status
# 重设密码
sudo su - postgres -c "psql -c \"ALTER USER dify PASSWORD 'dify_password_2024';\""
```

### Q4: GPU 没有被利用？

```bash
nvidia-smi                         # 确认驱动正常
ollama ps                           # 确认模型在 GPU 上运行
```

### Q5: Dify API 500 错误？

```bash
tail -100 /var/log/dify/api.log     # 查看 API 详细日志
# 常见原因：数据库迁移未完成
cd /opt/dify/api && poetry run flask db upgrade
```

### Q6: 如何备份？

```bash
# 备份数据库
sudo su - postgres -c "pg_dump dify > /backup/dify_$(date +%Y%m%d).sql"
# 备份文件
tar czf /backup/dify_storage_$(date +%Y%m%d).tar.gz /opt/dify/storage
```

### Q7: 开机自启？

```bash
sudo systemctl enable postgresql redis-server ollama dify-api dify-worker dify-web
```

---

## 🔒 安全建议

1. **修改默认密码**：部署后立即修改 `configs/env.conf` 中的数据库和 Redis 密码
2. **防火墙**：使用 `scripts/setup_firewall.sh` 只开放必要端口
3. **HTTPS**：生产环境建议配置 SSL 证书（参考 `scripts/setup_nginx.sh` 中注释的 HTTPS 配置）
4. **更新维护**：
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh   # 更新 Ollama
   cd /opt/dify && git pull origin main              # 更新 Dify
   ```

---

## 📝 技术栈总览

| 组件 | 版本 | 用途 |
|------|------|------|
| **Ollama** | latest | LLM 推理服务框架，管理模型生命周期 |
| **Qwen2.5-VL** | 7B | 多模态视觉语言模型，支持图文理解 |
| **Dify** | latest (源码) | AI 应用开发平台，提供 Web UI 和上下文记忆 |
| **PostgreSQL** | 16 + pgvector | 关系数据库 + 向量检索 |
| **Redis** | latest | 缓存 + Celery 异步任务队列 |
| **Python** | 3.11 | Dify API 后端 (Flask + Gunicorn + Celery) |
| **Node.js** | 20.x | Dify Web 前端 (Next.js) |
| **Nginx** | latest | 反向代理（可选） |

---

## 📄 License

MIT License
