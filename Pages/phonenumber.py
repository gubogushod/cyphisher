from flask import Flask, render_template, request, jsonify
import os
import datetime
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)

app = Flask(__name__)

DATA_DIR = "phone_data"
os.makedirs(DATA_DIR, exist_ok=True)
PHONE_FILE = os.path.join(DATA_DIR, "phone_numbers.txt")

if not os.path.exists(PHONE_FILE):
    with open(PHONE_FILE, "a", encoding="utf-8") as f:
        f.write("Anonymous Call System - Phone Numbers Log\n")
        f.write("=" * 50 + "\n\n")


@app.route('/')
def index():
    return render_template('phone_number.html')


@app.route('/save-number', methods=['POST'])
def save_number():
    phone_number = request.form.get('phoneNumber', '')

    if not phone_number:
        return jsonify({"success": False, "error": "No phone number provided"})

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ip_address = request.remote_addr

    try:
        with open(PHONE_FILE, "a", encoding="utf-8") as f:
            f.write(f"Time: {timestamp} | IP: {ip_address} | Phone: {phone_number}\n")
            print(f"✅ Save Information: {phone_number} - IP: {ip_address}")

        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)