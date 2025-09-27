import subprocess
from flask import Flask, request, send_from_directory , render_template
import os
from datetime import datetime
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

UPLOAD_DIR = os.path.join(os.getcwd(), 'uploads', 'session1')
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.route('/upload', methods=['POST'])
def upload():
    files = request.files
    saved_files = []

    for key in files:
        file = files[key]
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S%f')
        filename = f"{timestamp}-{file.filename}"
        file_path = os.path.join(UPLOAD_DIR, filename)
        file.save(file_path)
        saved_files.append(filename)

    print("Files saved:", saved_files)
    return {"status": "success", "files": saved_files}, 200

@app.route('/<path:path>')
def serve_file(path):
    return send_from_directory(os.getcwd(), path)

@app.route('/')
def index():
    return render_template('omegale.html')

def run():
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)
