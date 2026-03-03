# 面部健康分析 AI 系统

> 基于 **Ollama + Qwen2.5-VL + Dify** 的智能面部健康分析平台  
> 上传人脸照片 + 文字描述 → AI 分析面部特征并给出健康建议

---

## 📋 系统架构

```
用户浏览器 (远程访问)
     │
     ▼
┌──────────┐     ┌─────────────────┐     ┌──────────────────────┐
│  Dify    │────▶│  Ollama API     │────▶│  Qwen2.5-VL:7b      │
│  (Web UI)│     │  (localhost:    │     │  (视觉语言模型)       │
│  :80     │     │   11434)        │     │  GPU 加速             │
└──────────┘     └─────────────────┘     └──────────────────────┘
   Nginx            模型服务                 24GB GPU
```

### 技术选型

| 组件 | 选择 | 说明 |
|------|------|------|
| **大模型** | Qwen2.5-VL:7b | 通义千问视觉语言模型，支持图片理解，7B参数适配24GB GPU |
| **模型服务** | Ollama | 本地大模型管理与推理服务，简单易用 |
| **应用平台** | Dify | 开源 LLM 应用开发平台，提供 Web UI、对话管理、上下文记忆 |
| **容器化** | Docker Compose | Dify 及其依赖服务的容器编排 |

### 为什么选择 Qwen2.5-VL:7b？

- ✅ **视觉理解能力**：原生支持图片输入，可以分析面部照片
- ✅ **中文能力优秀**：Qwen 系列对中文支持极好
- ✅ **内存占用合理**：7B 模型约需 ~5GB 显存，在 24GB GPU 上运行流畅
- ✅ **Ollama 已收录**：直接 `ollama pull` 即可使用
- ✅ **推理速度快**：7B 参数量保证了较快的响应速度

---

## 🖥️ 环境要求

### 硬件要求

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| GPU | NVIDIA GPU (≥16GB显存) | NVIDIA GPU (24GB显存) |
| 内存 | 16GB | 32GB+ |
| 硬盘 | 50GB 可用空间 | 100GB+ SSD |
| CPU | 4核 | 8核+ |

### 软件要求

| 软件 | 版本 |
|------|------|
| Ubuntu | 22.04 / 24.04 LTS |
| NVIDIA 驱动 | ≥ 535 |
| Docker | ≥ 24.0 |
| Docker Compose | ≥ 2.0 (docker compose 插件) |
| NVIDIA Container Toolkit | 最新版 |

---

## 🚀 快速部署

### 方式一：一键部署（推荐）

```bash
# 1. 克隆项目
git clone <your-repo-url> ~/ollama-project
cd ~/ollama-project

# 2. 赋予脚本执行权限
chmod +x scripts/*.sh

# 3. 一键部署（需要 sudo 权限）
sudo bash scripts/deploy_all.sh
```

### 方式二：分步部署

如果你希望分步控制部署过程：

#### Step 1: 安装 NVIDIA 驱动 + Docker

```bash
sudo bash scripts/install_nvidia.sh
```

此脚本会：
- 检测 NVIDIA GPU
- 安装/更新 NVIDIA 驱动
- 安装 Docker 和 Docker Compose
- 安装 NVIDIA Container Toolkit
- 验证 GPU 在 Docker 中可用

> ⚠️ 如果是首次安装 NVIDIA 驱动，安装后需要**重启系统**，然后重新运行验证。

#### Step 2: 安装 Ollama + 下载模型

```bash
bash scripts/install_ollama.sh
```

此脚本会：
- 安装 Ollama
- 配置 Ollama 监听所有网络接口（`0.0.0.0:11434`）
- 下载 Qwen2.5-VL:7b 模型（约 4.7GB）
- 验证模型可正常推理

#### Step 3: 部署 Dify

```bash
bash scripts/setup_dify.sh
```

此脚本会：
- 克隆 Dify 官方仓库
- 配置环境变量
- 通过 Docker Compose 启动 Dify 所有服务
- 验证 Web 页面可访问

---

## ⚙️ 在 Dify 中配置应用

部署完成后，需要在 Dify 的 Web 界面中完成以下配置：

### 1. 初始化 Dify

1. 打开浏览器，访问 `http://<你的服务器IP>`
2. 首次访问会要求**创建管理员账户**
3. 设置邮箱和密码，点击注册

### 2. 添加 Ollama 模型提供商

1. 点击右上角头像 → **设置**
2. 进入 **模型提供商** 页面
3. 找到 **Ollama** 并点击添加
4. 填写配置：

| 配置项 | 值 |
|--------|-----|
| Model Name | `qwen2.5-vl:7b` |
| Base URL | `http://host.docker.internal:11434` 或 `http://<服务器IP>:11434` |
| Model Type | `LLM` |
| Vision Support | ✅ **开启** |
| Context Length | `32768` |

> **重要**：Base URL 说明
> - 如果 Dify 是 Docker 部署，Ollama 是宿主机部署：使用 `http://host.docker.internal:11434`（Docker Desktop）或 `http://<宿主机IP>:11434`
> - 在 Linux Docker 中，推荐使用 `http://<宿主机实际IP>:11434`（如 `http://192.168.1.100:11434`）
> - 也可使用 Docker 网关 IP：`http://172.17.0.1:11434`

5. 点击 **保存**，等待连接验证通过

### 3. 创建「面部健康分析」应用

#### 3.1 创建应用

1. 回到首页，点击 **创建应用**
2. 选择 **聊天助手 (Chatbot)**
3. 应用名称填入：`面部健康分析助手`
4. 描述填入：`基于 AI 视觉分析的面部健康咨询助手`

#### 3.2 配置模型

1. 在应用编排页面，找到 **模型** 设置
2. 选择 **Ollama** → **qwen2.5-vl:7b**

#### 3.3 设置系统提示词 (System Prompt)

在 **提示词** 区域，填入以下内容：

```
# 角色定义
你是一位专业的面部健康分析 AI 助手，具备一定的中医面诊和现代医学面部特征分析能力。

# 核心能力
- 分析用户上传的面部照片，观察面色、气色、五官特征等
- 结合中医面诊理论和现代健康知识提供健康建议
- 根据面部特征推测可能的健康状况

# 分析维度
当用户上传面部照片时，请从以下维度进行分析：

1. **面色分析**：观察面部整体色泽（红润/苍白/发黄/暗沉等）
2. **眼部特征**：眼白颜色、黑眼圈、眼袋情况、眼神是否有神
3. **唇色分析**：嘴唇颜色和状态（红润/苍白/干裂/发紫等）
4. **皮肤状态**：皮肤光泽度、纹理、是否有异常斑点
5. **气色综合**：整体精神状态评估

# 回复格式
请按以下格式输出分析结果：

## 📋 面部健康分析报告

### 整体评估
[总体健康印象]

### 详细分析
1. **面色**：[分析内容]
2. **眼部**：[分析内容]
3. **唇色**：[分析内容]
4. **皮肤**：[分析内容]
5. **气色**：[分析内容]

### 💡 健康建议
[具体的健康建议和改善方向]

### ⚠️ 免责声明
本分析仅基于 AI 图像识别，不构成医学诊断。如有健康问题，请及时就医。

# 重要规则
- 始终保持专业和友善的态度
- 分析结果必须附带免责声明
- 不做确定性的医学诊断
- 鼓励用户如有疑虑应咨询专业医生
- 可以结合用户描述的症状进行更全面的分析
- 支持多轮对话，可以对之前的分析进行补充说明
```

#### 3.4 配置功能开关

在应用配置中，确保开启以下功能：

| 功能 | 状态 | 说明 |
|------|------|------|
| **Vision (视觉)** | ✅ 开启 | 允许上传图片 |
| **对话开场白** | ✅ 开启 | 设置欢迎语 |
| **上下文记忆** | ✅ 开启 | 保持对话连贯性 |
| **文件上传** | ✅ 开启 | 允许上传图片文件 |

#### 3.5 设置对话开场白

```
👋 您好！我是面部健康分析助手。

我可以通过分析您上传的面部照片，结合中医面诊理论和现代健康知识，为您提供面部健康状况的初步评估。

**使用方法：**
1. 📸 点击下方的附件按钮上传您的面部照片
2. 💬 描述您想了解的内容（如："请分析我的健康状况"）
3. 🔍 我会为您生成详细的面部健康分析报告

> ⚠️ 请注意：AI 分析仅供参考，不构成医学诊断。

请上传您的照片开始分析吧！
```

#### 3.6 发布应用

1. 点击右上角 **发布** → **更新**
2. 点击 **运行** 或 **公开访问 URL** 获取访问链接
3. 将链接分享给需要使用的用户

---

## 🌐 远程网络访问配置

由于你的服务器没有显示器，需要通过网络远程访问。

### 局域网访问

如果访问设备与服务器在同一局域网：

```
http://<服务器局域网IP>
```

查看服务器 IP:
```bash
hostname -I
# 或
ip addr show
```

### 防火墙配置

```bash
# UFW 防火墙（Ubuntu 默认）
sudo ufw allow 80/tcp      # Dify Web
sudo ufw allow 443/tcp     # Dify HTTPS
sudo ufw allow 11434/tcp   # Ollama API（可选，如果不需外部直接访问可不开）

# 查看防火墙状态
sudo ufw status
```

### 外网访问（可选）

如果需要从公网访问，有以下几种方式：

#### 方式1：端口转发

在路由器中将以下端口转发到服务器 IP：
- 外部端口 80 → 服务器 IP:80

#### 方式2：使用 frp 内网穿透

```bash
# 在服务器上安装 frpc (客户端)
# 配置 frpc.toml
[common]
server_addr = <你的frp服务器IP>
server_port = 7000

[dify]
type = tcp
local_ip = 127.0.0.1
local_port = 80
remote_port = 8080
```

#### 方式3：Cloudflare Tunnel（推荐）

```bash
# 安装 cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# 登录并创建隧道
cloudflared tunnel login
cloudflared tunnel create face-health
cloudflared tunnel route dns face-health your-domain.com

# 运行隧道
cloudflared tunnel --url http://localhost:80 run face-health
```

---

## 📂 项目文件结构

```
ollama-project/
├── README.md                     # 本文档
├── scripts/
│   ├── deploy_all.sh             # 一键完整部署
│   ├── install_nvidia.sh         # NVIDIA 驱动 + Docker 安装
│   ├── install_ollama.sh         # Ollama 安装 + 模型下载
│   ├── setup_dify.sh             # Dify 平台部署
│   ├── start_all.sh              # 启动所有服务
│   ├── stop_all.sh               # 停止所有服务
│   └── check_status.sh           # 服务状态检查
└── dify/                         # (部署时自动生成) Dify 源码
    └── docker/
        ├── docker-compose.yml
        └── .env
```

---

## 🔧 日常运维

### 启动/停止服务

```bash
# 启动所有服务
bash scripts/start_all.sh

# 停止所有服务
bash scripts/stop_all.sh

# 检查服务状态
bash scripts/check_status.sh
```

### Ollama 管理

```bash
# 查看已安装模型
ollama list

# 查看正在运行的模型
ollama ps

# 手动测试模型
ollama run qwen2.5-vl:7b

# 更新模型
ollama pull qwen2.5-vl:7b

# 查看 Ollama 日志
journalctl -u ollama -f

# 重启 Ollama
sudo systemctl restart ollama
```

### Dify 管理

```bash
cd ~/ollama-project/dify/docker

# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启 Dify
docker compose restart

# 更新 Dify
docker compose down
git pull origin main
docker compose up -d
```

### GPU 监控

```bash
# 实时 GPU 使用情况
watch -n 1 nvidia-smi

# 查看 GPU 内存使用
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

---

## ❓ 常见问题

### Q1: Dify 中无法连接 Ollama

**原因**：Docker 容器无法访问宿主机的 Ollama 服务

**解决方案**：
```bash
# 方案1: 使用宿主机 IP
# Base URL 填写: http://<宿主机IP>:11434

# 方案2: 使用 Docker 网关
# Base URL 填写: http://172.17.0.1:11434

# 方案3: 确认 Ollama 监听地址
# 检查 Ollama 是否监听 0.0.0.0
ss -tlnp | grep 11434
# 应该显示 0.0.0.0:11434 而不是 127.0.0.1:11434

# 如果是 127.0.0.1，重新配置:
sudo mkdir -p /etc/systemd/system/ollama.service.d
echo '[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"' | sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Q2: 模型推理速度慢

**排查步骤**：
```bash
# 检查是否使用 GPU
nvidia-smi  # 查看 GPU 使用率

# 检查 Ollama 是否使用 GPU
ollama ps  # 查看 PROCESSOR 列应显示 GPU

# 如果显示 CPU，检查 NVIDIA 驱动
nvidia-smi
# 重装 Ollama
curl -fsSL https://ollama.com/install.sh | sh
```

### Q3: 图片上传失败

**解决方案**：
```bash
# 检查 Dify 文件大小限制
cd dify/docker
grep "UPLOAD_FILE_SIZE_LIMIT\|NGINX_CLIENT_MAX_BODY_SIZE" .env

# 修改限制（支持更大文件）
sed -i 's/NGINX_CLIENT_MAX_BODY_SIZE=.*/NGINX_CLIENT_MAX_BODY_SIZE=50m/' .env
sed -i 's/UPLOAD_FILE_SIZE_LIMIT=.*/UPLOAD_FILE_SIZE_LIMIT=50/' .env

# 重启 Dify
docker compose restart
```

### Q4: GPU 内存不足 (OOM)

```bash
# 查看 GPU 内存使用
nvidia-smi

# 如果 24GB 不够（通常不会），可以使用更小的模型
ollama pull qwen2.5-vl:3b

# 或清理不使用的模型
ollama rm <model-name>
```

### Q5: Dify 服务启动失败

```bash
cd dify/docker

# 查看错误日志
docker compose logs --tail=50

# 常见原因：端口被占用
sudo lsof -i :80
# 如果被占用，停止占用进程或修改 .env 中的端口
sed -i 's/EXPOSE_NGINX_PORT=80/EXPOSE_NGINX_PORT=8080/' .env
docker compose up -d
# 然后通过 http://<IP>:8080 访问
```

### Q6: 如何设置开机自启动

```bash
# Ollama 默认通过 systemd 自启动
sudo systemctl enable ollama

# Dify Docker 容器自启动
cd dify/docker
# 在 docker-compose.yml 中各服务已有 restart: always 配置
# 确保 Docker 服务自启动
sudo systemctl enable docker
```

---

## 🔒 安全建议

1. **修改默认密码**：首次设置 Dify 管理员账户时使用强密码
2. **防火墙**：仅开放必要端口（80/443），不建议将 11434 端口暴露到公网
3. **HTTPS**：生产环境建议配置 SSL 证书
4. **访问控制**：使用 Dify 的成员管理功能控制访问权限
5. **定期更新**：保持 Ollama、Dify、系统安全更新

---

## 📊 使用示例

### 示例对话

**用户**：[上传一张面部照片] 请你根据我上传的面部照片判断我的健康情况

**AI 助手**：

> ## 📋 面部健康分析报告
> 
> ### 整体评估
> 从您上传的照片来看，整体面色红润，精神状态良好...
> 
> ### 详细分析
> 1. **面色**：面部整体呈红润色泽，血气充足...
> 2. **眼部**：眼神有神，但眼下有轻微黑眼圈...
> 3. **唇色**：嘴唇颜色红润正常...
> 4. **皮肤**：皮肤光泽度较好...
> 5. **气色**：整体气色良好...
>
> ### 💡 健康建议
> - 注意作息规律，改善轻微黑眼圈
> - 保持良好的饮食习惯...
>
> ### ⚠️ 免责声明
> 本分析仅基于 AI 图像识别，不构成医学诊断...

---

## 📄 许可证

本项目仅供学习和研究使用。模型服务遵循各自的开源许可证：
- Qwen2.5-VL: Apache 2.0
- Ollama: MIT License  
- Dify: Apache 2.0