import os
import platform
import webbrowser


def run():
    index_file = os.path.join(os.path.dirname(__file__), "index.html")

    # تشخیص پلتفرم
    if "ANDROID_ROOT" in os.environ:
        detected_platform = "Termux/Android"
    else:
        detected_platform = platform.system()

    print(f"[+] Detected platform: {detected_platform}")
    print(f"[+] Opening index.html located at: {index_file}")

    file_url = f"file://{os.path.abspath(index_file)}"

    try:
        webbrowser.open(file_url)
        print(f"[+] index.html opened in default browser: {file_url}")
    except Exception as e:
        print(f"[!] Could not open browser automatically: {e}")
        print(f"[*] You can open it manually here: {file_url}")


if __name__ == "__main__":
    run()