import os
import time
import requests
from flask import Flask, jsonify

app = Flask(__name__)

NODE_NAME = os.environ.get("NODE_NAME", "unknown-node")
POD_NAME = os.environ.get("POD_NAME", "unknown-pod")
CATALOG_SERVICE_URL = os.environ.get("CATALOG_SERVICE_URL", "http://backend-catalog-service:5000/api/items")
SERVICE_NAME = "frontend-order-service"


@app.route("/")
def index():
    backend_data = None
    backend_status = "unreachable"
    error_message = None

    try:
        resp = requests.get(CATALOG_SERVICE_URL, timeout=4)
        if resp.status_code == 200:
            backend_data = resp.json()
            backend_status = "connected"
        else:
            backend_status = f"error-{resp.status_code}"
    except Exception as exc:
        error_message = str(exc)

    return jsonify({
        "frontend": {
            "service": SERVICE_NAME,
            "pod": POD_NAME,
            "node": NODE_NAME,
            "status": "operational",
        },
        "backend_connection": {
            "target_url": CATALOG_SERVICE_URL,
            "status": backend_status,
            "error": error_message,
            "data": backend_data,
        },
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    })


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "service": SERVICE_NAME,
        "pod": POD_NAME,
        "node": NODE_NAME,
    }), 200


@app.route("/info")
def info():
    return jsonify({
        "service": SERVICE_NAME,
        "pod": POD_NAME,
        "node": NODE_NAME,
        "backend_target": CATALOG_SERVICE_URL,
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
