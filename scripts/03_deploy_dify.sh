#!/bin/bash
#================================================================
# 03_deploy_dify.sh
# 从源码部署 Dify（不使用 Docker Compose）
# 包含: PostgreSQL配置、Redis配置、API后端、Web前端、Worker
# 使用方法: sudo bash 03_deploy_dify.sh
#================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/configs/env.conf" 2>/dev/null || true

DIFY_DIR="${DIFY_DIR:-/opt/dify}"
DIFY_BRANCH="${DIFY_BRANCH:-main}"
DB_NAME="${DB_NAME:-dify}"
DB_USER="${DB_USER:-dify}"
DB_PASSWORD="${DB_PASSWORD:-dify_password_2024}"
REDIS_PASSWORD="${REDIS_PASSWORD:-dify_redis_2024}"
SECRET_KEY="${SECRET_KEY:-$(openssl rand -hex 32)}"
DIFY_API_PORT="${DIFY_API_PORT:-5001}"
DIFY_WEB_PORT="${DIFY_WEB_PORT:-3000}"

echo "=========================================="
echo "  [Step 1/8] 准备 Dify 源码..."
echo "=========================================="

if [ -d "$DIFY_DIR" ] && [ -d "$DIFY_DIR/.git" ]; then
    echo "Dify 源码已存在，更新中..."
    cd "$DIFY_DIR"
    git fetch origin
    git checkout $DIFY_BRANCH
    git pull origin $DIFY_BRANCH || true
else
    echo "克隆 Dify 源码..."
    rm -rf "$DIFY_DIR"
    git clone https://github.com/langgenius/dify.git "$DIFY_DIR" --branch $DIFY_BRANCH --depth 1
fi

cd "$DIFY_DIR"
echo "Dify 源码准备完成: $DIFY_DIR"

echo "=========================================="
echo "  [Step 2/8] 配置 PostgreSQL..."
echo "=========================================="

# 启动 PostgreSQL
PG_VERSION=$(ls /etc/postgresql/ 2>/dev/null | head -1)
if [ -z "$PG_VERSION" ]; then
    echo "错误: 未找到 PostgreSQL，请先运行 01_install_dependencies.sh"
    exit 1
fi

# 确保 PostgreSQL 数据目录已初始化
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
if [ ! -d "$PG_DATA" ] || [ ! -f "$PG_DATA/PG_VERSION" ]; then
    echo "初始化 PostgreSQL 数据目录..."
    su - postgres -c "/usr/lib/postgresql/${PG_VERSION}/bin/initdb -D $PG_DATA" || true
fi

# 配置 pg_hba.conf 允许本地密码认证
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
if [ -f "$PG_HBA" ]; then
    # 确保本地连接使用 md5 认证
    sed -i 's/local\s\+all\s\+all\s\+peer/local   all             all                                     md5/' "$PG_HBA"
    # 确保允许 localhost 连接
    grep -q "host.*all.*all.*127.0.0.1/32.*md5" "$PG_HBA" || \
        echo "host    all             all             127.0.0.1/32            md5" >> "$PG_HBA"
fi

# 配置 postgresql.conf
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
if [ -f "$PG_CONF" ]; then
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$PG_CONF"
fi

# 启动 PostgreSQL
echo "启动 PostgreSQL..."
pg_ctlcluster ${PG_VERSION} main start 2>/dev/null || \
    su - postgres -c "/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl start -D $PG_DATA" 2>/dev/null || \
    service postgresql start 2>/dev/null || true

sleep 3

# 创建数据库和用户
echo "创建数据库和用户..."
su - postgres -c "psql -c \"CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';\"" 2>/dev/null || true
su - postgres -c "psql -c \"CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};\"" 2>/dev/null || true
su - postgres -c "psql -d ${DB_NAME} -c \"CREATE EXTENSION IF NOT EXISTS vector;\"" 2>/dev/null || true
su - postgres -c "psql -d ${DB_NAME} -c \"CREATE EXTENSION IF NOT EXISTS uuid-ossp;\"" 2>/dev/null || true
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};\"" 2>/dev/null || true
su - postgres -c "psql -d ${DB_NAME} -c \"GRANT ALL ON SCHEMA public TO ${DB_USER};\"" 2>/dev/null || true

echo "PostgreSQL 配置完成"

echo "=========================================="
echo "  [Step 3/8] 配置 Redis..."
echo "=========================================="

# 配置 Redis 密码
REDIS_CONF="/etc/redis/redis.conf"
if [ -f "$REDIS_CONF" ]; then
    sed -i "s/^# requirepass .*/requirepass ${REDIS_PASSWORD}/" "$REDIS_CONF"
    sed -i "s/^requirepass .*/requirepass ${REDIS_PASSWORD}/" "$REDIS_CONF"
    grep -q "^requirepass" "$REDIS_CONF" || echo "requirepass ${REDIS_PASSWORD}" >> "$REDIS_CONF"
    # 绑定 localhost
    sed -i "s/^bind .*/bind 127.0.0.1/" "$REDIS_CONF"
fi

# 启动 Redis
echo "启动 Redis..."
redis-server "$REDIS_CONF" --daemonize yes 2>/dev/null || \
    service redis-server start 2>/dev/null || true

sleep 2

# 验证 Redis
if redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q "PONG"; then
    echo "Redis 启动成功"
else
    echo "尝试无密码启动 Redis..."
    redis-server --daemonize yes
    REDIS_PASSWORD=""
    echo "Redis 以无密码模式启动"
fi

echo "=========================================="
echo "  [Step 4/8] 配置 Dify API 后端..."
echo "=========================================="

cd "$DIFY_DIR/api"

# 创建 .env 文件
cat > .env << ENVEOF
# Dify API Configuration
# ===========================
# 基础配置
FLASK_APP=app.py
FLASK_ENV=production
FLASK_DEBUG=false
EDITION=SELF_HOSTED
DEPLOY_ENV=PRODUCTION
CONSOLE_API_URL=http://0.0.0.0:${DIFY_API_PORT}
SERVICE_API_URL=http://0.0.0.0:${DIFY_API_PORT}
APP_WEB_URL=http://0.0.0.0:${DIFY_WEB_PORT}
CONSOLE_WEB_URL=http://0.0.0.0:${DIFY_WEB_PORT}

# 安全密钥
SECRET_KEY=${SECRET_KEY}

# 数据库
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=${DB_NAME}
SQLALCHEMY_DATABASE_URI=postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=0
REDIS_USE_SSL=false

# Celery (使用 Redis 作为 broker)
CELERY_BROKER_URL=redis://:${REDIS_PASSWORD}@localhost:6379/1
BROKER_USE_SSL=false

# 存储
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=/opt/dify/storage

# 向量数据库 (使用 pgvector)
VECTOR_STORE=pgvector
PGVECTOR_HOST=localhost
PGVECTOR_PORT=5432
PGVECTOR_USER=${DB_USER}
PGVECTOR_PASSWORD=${DB_PASSWORD}
PGVECTOR_DATABASE=${DB_NAME}

# 日志
LOG_LEVEL=INFO
LOG_FILE=/var/log/dify/api.log

# 文件上传限制
UPLOAD_FILE_SIZE_LIMIT=15
UPLOAD_FILE_BATCH_LIMIT=5
UPLOAD_IMAGE_FILE_SIZE_LIMIT=10

# 多模态
MULTIMODAL_SEND_IMAGE_FORMAT=base64

# 其他
MIGRATION_ENABLED=true
CHECK_UPDATE=false
INIT_PASSWORD=
ENVEOF

# 创建必要目录
mkdir -p /opt/dify/storage
mkdir -p /var/log/dify

# 安装 Python 依赖
echo "安装 API Python 依赖..."

# 使用 poetry 安装依赖
if command -v poetry &> /dev/null || [ -f "$HOME/.local/bin/poetry" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    
    # 配置 poetry 使用 python3.11
    if command -v python3.11 &> /dev/null; then
        poetry env use python3.11
    fi
    
    poetry install --no-root 2>&1 | tail -5
    echo "API 依赖安装完成 (poetry)"
else
    # 回退到 pip
    echo "Poetry 未找到，使用 pip 安装..."
    PYTHON_BIN=$(command -v python3.11 || command -v python3)
    $PYTHON_BIN -m venv /opt/dify/api-venv
    source /opt/dify/api-venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt 2>&1 | tail -5
    echo "API 依赖安装完成 (pip)"
fi

echo "Dify API 配置完成"

echo "=========================================="
echo "  [Step 5/8] 数据库迁移..."
echo "=========================================="

cd "$DIFY_DIR/api"
export PATH="$HOME/.local/bin:$PATH"

echo "执行数据库迁移..."
if [ -f "pyproject.toml" ]; then
    poetry run python -m flask db upgrade 2>&1 | tail -10 || {
        echo "尝试使用 poetry run flask db upgrade..."
        poetry run flask db upgrade 2>&1 | tail -10 || {
            echo "警告: 数据库迁移可能需要手动执行"
        }
    }
else
    source /opt/dify/api-venv/bin/activate 2>/dev/null
    flask db upgrade 2>&1 | tail -10 || true
fi

echo "数据库迁移完成"

echo "=========================================="
echo "  [Step 6/8] 配置 Dify Web 前端..."
echo "=========================================="

cd "$DIFY_DIR/web"

# 创建 .env.local
cat > .env.local << ENVEOF
# Dify Web Frontend Configuration
NEXT_PUBLIC_API_PREFIX=http://0.0.0.0:${DIFY_API_PORT}/console/api
NEXT_PUBLIC_PUBLIC_API_PREFIX=http://0.0.0.0:${DIFY_API_PORT}/api
NEXT_PUBLIC_DEPLOY_ENV=PRODUCTION
NEXT_PUBLIC_EDITION=SELF_HOSTED
NEXT_PUBLIC_SENTRY_DSN=
NEXT_PUBLIC_SITE_ABOUT=
ENVEOF

# 安装前端依赖并构建
echo "安装 Web 前端依赖..."

# 检查是否有 pnpm lock 文件
if [ -f "pnpm-lock.yaml" ]; then
    pnpm install --frozen-lockfile 2>&1 | tail -5 || pnpm install 2>&1 | tail -5
elif [ -f "yarn.lock" ]; then
    yarn install --frozen-lockfile 2>&1 | tail -5 || yarn install 2>&1 | tail -5
else
    npm install 2>&1 | tail -5
fi

echo "构建前端..."
if [ -f "pnpm-lock.yaml" ]; then
    pnpm build 2>&1 | tail -10
elif [ -f "yarn.lock" ]; then
    yarn build 2>&1 | tail -10
else
    npm run build 2>&1 | tail -10
fi

echo "Dify Web 前端构建完成"

echo "=========================================="
echo "  [Step 7/8] 创建 systemd 服务文件..."
echo "=========================================="

# 注意：在容器内可能不支持 systemd，这些文件可用于物理机部署
# 容器内使用 start_services.sh 脚本启动

# Ollama 服务文件
cat > /etc/systemd/system/ollama.service 2>/dev/null << 'SVCEOF' || true
[Unit]
Description=Ollama LLM Service
After=network-online.target

[Service]
Type=simple
User=root
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

# Dify API 服务文件
cat > /etc/systemd/system/dify-api.service 2>/dev/null << SVCEOF || true
[Unit]
Description=Dify API Server
After=network-online.target postgresql.service redis-server.service
Requires=postgresql.service redis-server.service

[Service]
Type=simple
User=root
WorkingDirectory=${DIFY_DIR}/api
EnvironmentFile=${DIFY_DIR}/api/.env
ExecStart=$(command -v poetry 2>/dev/null || echo "$HOME/.local/bin/poetry") run gunicorn --bind 0.0.0.0:${DIFY_API_PORT} --workers 4 --timeout 200 --preload app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# Dify Worker 服务文件
cat > /etc/systemd/system/dify-worker.service 2>/dev/null << SVCEOF || true
[Unit]
Description=Dify Celery Worker
After=network-online.target postgresql.service redis-server.service
Requires=postgresql.service redis-server.service

[Service]
Type=simple
User=root
WorkingDirectory=${DIFY_DIR}/api
EnvironmentFile=${DIFY_DIR}/api/.env
ExecStart=$(command -v poetry 2>/dev/null || echo "$HOME/.local/bin/poetry") run celery -A app.celery worker -P gevent -c 1 --loglevel INFO -Q dataset,generation,mail,ops_trace,app_deletion
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# Dify Web 服务文件
cat > /etc/systemd/system/dify-web.service 2>/dev/null << SVCEOF || true
[Unit]
Description=Dify Web Frontend
After=network-online.target dify-api.service

[Service]
Type=simple
User=root
WorkingDirectory=${DIFY_DIR}/web
ExecStart=$(command -v pnpm 2>/dev/null || echo "npx pnpm") start -p ${DIFY_WEB_PORT} -H 0.0.0.0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

echo "服务文件创建完成"

echo "=========================================="
echo "  [Step 8/8] 创建启动/停止脚本..."
echo "=========================================="

# ------------------------------------
# 创建启动脚本
# ------------------------------------
cat > "$PROJECT_DIR/scripts/start_services.sh" << 'STARTEOF'
#!/bin/bash
#================================================================
# start_services.sh - 启动所有服务
# 使用方法: sudo bash start_services.sh
#================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/configs/env.conf" 2>/dev/null || true

DIFY_DIR="${DIFY_DIR:-/opt/dify}"
DIFY_API_PORT="${DIFY_API_PORT:-5001}"
DIFY_WEB_PORT="${DIFY_WEB_PORT:-3000}"
REDIS_PASSWORD="${REDIS_PASSWORD:-dify_redis_2024}"

export PATH="$HOME/.local/bin:$PATH"

echo "=========================================="
echo "  启动所有服务..."
echo "=========================================="

# 1. 启动 PostgreSQL
echo "[1/5] 启动 PostgreSQL..."
PG_VERSION=$(ls /etc/postgresql/ 2>/dev/null | head -1)
if [ -n "$PG_VERSION" ]; then
    pg_ctlcluster ${PG_VERSION} main start 2>/dev/null || \
        service postgresql start 2>/dev/null || true
fi
sleep 2
echo "  PostgreSQL: OK"

# 2. 启动 Redis
echo "[2/5] 启动 Redis..."
REDIS_CONF="/etc/redis/redis.conf"
if [ -f "$REDIS_CONF" ]; then
    redis-server "$REDIS_CONF" --daemonize yes 2>/dev/null || true
else
    redis-server --daemonize yes 2>/dev/null || true
fi
sleep 1
echo "  Redis: OK"

# 3. 启动 Ollama
echo "[3/5] 启动 Ollama..."
export OLLAMA_HOST=0.0.0.0:11434
export OLLAMA_ORIGINS=*
if ! pgrep -x "ollama" > /dev/null 2>&1; then
    nohup ollama serve > /var/log/ollama.log 2>&1 &
    sleep 5
fi
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "  Ollama: OK (http://localhost:11434)"
else
    echo "  Ollama: 等待启动..."
    sleep 10
    echo "  Ollama: $(curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && echo OK || echo FAILED)"
fi

# 4. 启动 Dify API + Worker
echo "[4/5] 启动 Dify API + Worker..."
cd "$DIFY_DIR/api"
mkdir -p /var/log/dify

# 停止已有进程
pkill -f "gunicorn.*app:app" 2>/dev/null || true
pkill -f "celery.*worker" 2>/dev/null || true
sleep 2

# 启动 API (gunicorn)
if [ -f "pyproject.toml" ] && command -v poetry &> /dev/null; then
    nohup poetry run gunicorn \
        --bind 0.0.0.0:${DIFY_API_PORT} \
        --workers 4 \
        --timeout 200 \
        --preload \
        app:app > /var/log/dify/api.log 2>&1 &
else
    source /opt/dify/api-venv/bin/activate 2>/dev/null || true
    nohup gunicorn \
        --bind 0.0.0.0:${DIFY_API_PORT} \
        --workers 4 \
        --timeout 200 \
        --preload \
        app:app > /var/log/dify/api.log 2>&1 &
fi
sleep 3

# 启动 Worker (celery)
if [ -f "pyproject.toml" ] && command -v poetry &> /dev/null; then
    nohup poetry run celery \
        -A app.celery worker \
        -P gevent -c 1 \
        --loglevel INFO \
        -Q dataset,generation,mail,ops_trace,app_deletion \
        > /var/log/dify/worker.log 2>&1 &
else
    source /opt/dify/api-venv/bin/activate 2>/dev/null || true
    nohup celery \
        -A app.celery worker \
        -P gevent -c 1 \
        --loglevel INFO \
        -Q dataset,generation,mail,ops_trace,app_deletion \
        > /var/log/dify/worker.log 2>&1 &
fi
sleep 2
echo "  Dify API: http://0.0.0.0:${DIFY_API_PORT}"
echo "  Dify Worker: OK"

# 5. 启动 Dify Web
echo "[5/5] 启动 Dify Web..."
cd "$DIFY_DIR/web"
pkill -f "next.*start" 2>/dev/null || true
sleep 1

if [ -f "pnpm-lock.yaml" ]; then
    nohup pnpm start -p ${DIFY_WEB_PORT} -H 0.0.0.0 > /var/log/dify/web.log 2>&1 &
elif [ -f "yarn.lock" ]; then
    nohup yarn start -p ${DIFY_WEB_PORT} -H 0.0.0.0 > /var/log/dify/web.log 2>&1 &
else
    nohup npm start -- -p ${DIFY_WEB_PORT} -H 0.0.0.0 > /var/log/dify/web.log 2>&1 &
fi
sleep 3
echo "  Dify Web: http://0.0.0.0:${DIFY_WEB_PORT}"

echo ""
echo "=========================================="
echo "  所有服务启动完成！"
echo "=========================================="
echo ""
echo "  服务状态:"
echo "    PostgreSQL : $(pg_isready -q && echo '运行中' || echo '未运行')"
echo "    Redis      : $(redis-cli -a ${REDIS_PASSWORD} ping 2>/dev/null | grep -q PONG && echo '运行中' || echo '未运行')"
echo "    Ollama     : $(curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && echo '运行中' || echo '未运行')"
echo "    Dify API   : $(curl -s http://localhost:${DIFY_API_PORT}/health > /dev/null 2>&1 && echo '运行中' || echo '启动中...')"
echo "    Dify Web   : $(curl -s http://localhost:${DIFY_WEB_PORT} > /dev/null 2>&1 && echo '运行中' || echo '启动中...')"
echo ""
echo "  访问地址:"
echo "    Dify Web UI: http://<服务器IP>:${DIFY_WEB_PORT}"
echo "    Dify API:    http://<服务器IP>:${DIFY_API_PORT}"
echo "    Ollama API:  http://<服务器IP>:11434"
echo ""
echo "  日志文件:"
echo "    Ollama:      /var/log/ollama.log"
echo "    Dify API:    /var/log/dify/api.log"
echo "    Dify Worker:  /var/log/dify/worker.log"
echo "    Dify Web:    /var/log/dify/web.log"
STARTEOF

chmod +x "$PROJECT_DIR/scripts/start_services.sh"

# ------------------------------------
# 创建停止脚本
# ------------------------------------
cat > "$PROJECT_DIR/scripts/stop_services.sh" << 'STOPEOF'
#!/bin/bash
#================================================================
# stop_services.sh - 停止所有服务
# 使用方法: sudo bash stop_services.sh
#================================================================

echo "=========================================="
echo "  停止所有服务..."
echo "=========================================="

echo "[1/5] 停止 Dify Web..."
pkill -f "next.*start" 2>/dev/null || true

echo "[2/5] 停止 Dify Worker..."
pkill -f "celery.*worker" 2>/dev/null || true

echo "[3/5] 停止 Dify API..."
pkill -f "gunicorn.*app:app" 2>/dev/null || true

echo "[4/5] 停止 Ollama..."
pkill -f "ollama serve" 2>/dev/null || true

echo "[5/5] 停止 Redis (可选)..."
redis-cli shutdown 2>/dev/null || true

# 注意: PostgreSQL 通常不需要停止
# 如需停止: sudo service postgresql stop

echo ""
echo "所有服务已停止"
STOPEOF

chmod +x "$PROJECT_DIR/scripts/stop_services.sh"

# ------------------------------------
# 创建状态检查脚本
# ------------------------------------
cat > "$PROJECT_DIR/scripts/check_status.sh" << 'CHECKEOF'
#!/bin/bash
#================================================================
# check_status.sh - 检查所有服务状态
# 使用方法: bash check_status.sh
#================================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/configs/env.conf" 2>/dev/null || true

DIFY_API_PORT="${DIFY_API_PORT:-5001}"
DIFY_WEB_PORT="${DIFY_WEB_PORT:-3000}"
REDIS_PASSWORD="${REDIS_PASSWORD:-dify_redis_2024}"

echo "=========================================="
echo "  服务状态检查"
echo "=========================================="
echo ""

# PostgreSQL
PG_STATUS="❌ 未运行"
pg_isready -q 2>/dev/null && PG_STATUS="✅ 运行中"
echo "  PostgreSQL  : $PG_STATUS"

# Redis
REDIS_STATUS="❌ 未运行"
redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG && REDIS_STATUS="✅ 运行中"
echo "  Redis       : $REDIS_STATUS"

# Ollama
OLLAMA_STATUS="❌ 未运行"
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; data=json.load(sys.stdin); print(', '.join([m['name'] for m in data.get('models',[])]))" 2>/dev/null || echo "未知")
    OLLAMA_STATUS="✅ 运行中 | 模型: $MODELS"
fi
echo "  Ollama      : $OLLAMA_STATUS"

# Dify API
API_STATUS="❌ 未运行"
curl -s http://localhost:${DIFY_API_PORT}/health > /dev/null 2>&1 && API_STATUS="✅ 运行中"
echo "  Dify API    : $API_STATUS (端口: ${DIFY_API_PORT})"

# Dify Worker
WORKER_STATUS="❌ 未运行"
pgrep -f "celery.*worker" > /dev/null 2>&1 && WORKER_STATUS="✅ 运行中"
echo "  Dify Worker : $WORKER_STATUS"

# Dify Web
WEB_STATUS="❌ 未运行"
curl -s http://localhost:${DIFY_WEB_PORT} > /dev/null 2>&1 && WEB_STATUS="✅ 运行中"
echo "  Dify Web    : $WEB_STATUS (端口: ${DIFY_WEB_PORT})"

echo ""
echo "=========================================="

# GPU 状态
if command -v nvidia-smi &> /dev/null; then
    echo ""
    echo "  GPU 状态:"
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null | while read line; do
        echo "    $line"
    done
fi
echo ""
CHECKEOF

chmod +x "$PROJECT_DIR/scripts/check_status.sh"

echo ""
echo "=========================================="
echo "  Dify 部署完成！"
echo "=========================================="
echo ""
echo "  使用以下脚本管理服务:"
echo "    启动: sudo bash $PROJECT_DIR/scripts/start_services.sh"
echo "    停止: sudo bash $PROJECT_DIR/scripts/stop_services.sh"
echo "    状态: bash $PROJECT_DIR/scripts/check_status.sh"
echo ""
echo "下一步: 运行 04_configure_dify_app.sh 配置应用"
