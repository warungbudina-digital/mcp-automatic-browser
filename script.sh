#!/bin/bash

echo "📦 Install tools pendukung (htop, jq)..."
sudo apt install -y htop jq

echo "⬇️ Install rclone..."
curl https://rclone.org/install.sh | sudo bash

# ========================
# Bagian: RCLONE CONF
# ========================
REMOTE_NAME="gdrive"
TOKEN_FILE="./token.json"
RCLONE_CONF_PATH="$HOME/.config/rclone/rclone.conf"
DEST_FOLDER="$(pwd)"
GDRIVE_FOLDER="Project-Tutorial/layer-miner/layer-bot"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "❌ File token.json tidak ditemukan di path: $TOKEN_FILE"
  exit 1
fi

echo "⚙️ Menyiapkan rclone.conf..."
mkdir -p "$(dirname "$RCLONE_CONF_PATH")"
TOKEN=$(jq -c . "$TOKEN_FILE")

cat > "$RCLONE_CONF_PATH" <<EOF
[$REMOTE_NAME]
type = drive
scope = drive
token = $TOKEN
EOF

echo "✅ rclone.conf berhasil dibuat."

echo "📁 Menyalin file layer-miner dari Drive ke $DEST_FOLDER ..."
rclone copy --config="$RCLONE_CONF_PATH" "$REMOTE_NAME:$GDRIVE_FOLDER" "$DEST_FOLDER" --progress

# ========================
# Bagian: DOCKER & CHROMIUM
# ========================
echo "🐳 Menyiapkan kontainer Chromium..."

sudo docker load -i chromium-stable.tar
sudo tar -xzvf chromium-data.tar.gz -C ~/

if [ ! -d "bromato" ]; then

  echo "⬇️ Clone Bromato..."
  git clone https://github.com/gyoridavid/bromato.git
fi

cat > Dockerfile <<'EOF'
FROM node:20-slim

# Skip download browser Playwright (gunakan Chromium external)
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Production mode
ENV NODE_ENV=production

# Disable telemetry
ENV PLAYWRIGHT_DISABLE_TELEMETRY=1

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libu2f-udev \
    libvulkan1 \
    xdg-utils \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

RUN npm install -g tsx

COPY . .

EXPOSE 3025

CMD ["tsx", "src/index.ts"]
EOF

echo "📝 Generating docker-compose.yml..."

cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  chromium:
    image: chromium-stable:latest
    container_name: chromium
    restart: always
    shm_size: "1gb"
    networks:
      - chromium_net
    ports:
      - "5678:5678"
    volumes:
      - ~/chromium-data:/config

  bromato:
  build: ./bromato
  container_name: bromato
  restart: always
  shm_size: "1gb"
  networks:
    - chromium_net
  ports:
    - "3025:3025"
  environment:
    - PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    - BROWSER_WS_ENDPOINT=ws://chromium:5678

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: always
    networks:
      - chromium_net
    command: >
      tunnel --no-autoupdate run --token xx

networks:
  chromium_net:
    driver: bridge
EOF

echo "🚀 Menjalankan Docker Compose..."
sudo docker compose up -d

echo "🧹 Membersihkan file yang tidak dibutuhkan..."
sudo rm -f chromium-stable.tar
sudo rm -f chromium-data.tar.gz

echo "✅ SETUP SELESAI"
echo "🌐 Bromato API : http://localhost:3025"

# ========================
# Bagian: Ping agar Cloud Shell tetap aktif
# ========================
ping 8.8.8.8
