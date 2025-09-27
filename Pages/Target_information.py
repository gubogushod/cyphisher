from flask import Flask, request, jsonify, render_template
import json
import datetime
import os
from uuid import uuid4
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)


app = Flask(__name__)

if not os.path.exists('collected_data'):
    os.makedirs('collected_data')


def save_device_info(device_data):
    try:
        device_data['collection_id'] = str(uuid4())
        device_data['server_timestamp'] = datetime.datetime.now().isoformat()

        filename = f"device_info_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}_{device_data['collection_id'][:8]}.json"
        filepath = os.path.join('collected_data', filename)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(device_data, f, indent=2, ensure_ascii=False)

        master_file = 'collected_data/all_devices.json'
        if os.path.exists(master_file):
            with open(master_file, 'r+', encoding='utf-8') as f:
                try:
                    data = json.load(f)
                except:
                    data = []
        else:
            data = []

        data.append(device_data)
        with open(master_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        return True
    except Exception as e:
        print(f"Error saving device info: {e}")
        return False


@app.route('/')
def index():
    return render_template('information.html')


@app.route('/collect', methods=['POST'])
def collect_device_info():
    try:
        device_data = request.get_json()

        if device_data:
            success = save_device_info(device_data)

            if success:
                print(f"✅ Device info collected successfully - IP: {request.remote_addr}")
                return jsonify({'status': 'success', 'message': 'Device information collected'})
            else:
                return jsonify({'status': 'error', 'message': 'Failed to save information'}), 500
        else:
            return jsonify({'status': 'error', 'message': 'No data received'}), 400

    except Exception as e:
        print(f"Error collecting device info: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/admin')
def admin():
    try:
        master_file = 'collected_data/all_devices.json'
        if os.path.exists(master_file):
            with open(master_file, 'r', encoding='utf-8') as f:
                devices = json.load(f)
            return jsonify({'total_devices': len(devices), 'devices': devices})
        else:
            return jsonify({'total_devices': 0, 'devices': []})
    except:
        return jsonify({'total_devices': 0, 'devices': []})


def run():
    app.run(debug=True, host='0.0.0.0', port=5000)



if __name__ == '__main__':
    run()