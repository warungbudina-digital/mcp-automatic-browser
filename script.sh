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
      - "3040:3040"
    volumes:
      - ~/chromium-data:/config
  
  bromato:
    image: node:20-slim
    container_name: bromato
    restart: always
    shm_size: "1gb"
    networks:  
      - chromium_net
    working_dir: /app
    volumes:
      - ./bromato:/app
    ports:
      - "3025:3025"
    command: >
      sh -c "
      npm install &&
      npx playwright install chromium &&
      npm start
      "

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
