import subprocess
from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import os
from datetime import datetime
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)


app = Flask(__name__)
CORS(app)


LOCATION_DIR = "location_information"
if not os.path.exists(LOCATION_DIR):
    os.makedirs(LOCATION_DIR)


def save_location_to_file(latitude, longitude, accuracy):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    filename = os.path.join(LOCATION_DIR, "location_data.txt")

    data = f"Timestamp: {timestamp}\nLatitude: {latitude}\nLongitude: {longitude}\nAccuracy: {accuracy} meters\n"
    data += "=" * 50 + "\n\n"

    with open(filename, "a", encoding="utf-8") as file:
        file.write(data)

    return filename


@app.route('/')
def index():
    return render_template('location.html')


@app.route('/location', methods=['POST'])
def receive_location():
    try:
        latitude = request.form.get('latitude')
        longitude = request.form.get('longitude')
        accuracy = request.form.get('accuracy')

        print(f"Received location data: Latitude={latitude}, Longitude={longitude}, Accuracy={accuracy}")

        filename = save_location_to_file(latitude, longitude, accuracy)
        print(f"Location data saved to: {filename}")

        return jsonify({
            'status': 'success',
            'message': 'Location data received and saved successfully',
            'data': {
                'latitude': latitude,
                'longitude': longitude,
                'accuracy': accuracy,
                'saved_to': filename
            }
        }), 200

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500


def run():
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)
