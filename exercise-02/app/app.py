import os

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(message="Hello from Flask on Kubernetes", version=os.getenv("APP_VERSION", "1.0"))


@app.route("/health")
def health():
    return jsonify(status="healthy"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
