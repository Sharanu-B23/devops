import os
import time
from flask import Flask, jsonify

app = Flask(__name__)

NODE_NAME = os.environ.get("NODE_NAME", "unknown-node")
POD_NAME = os.environ.get("POD_NAME", "unknown-pod")
SERVICE_NAME = "backend-catalog-service"

ITEMS = [
    {"id": 1, "name": "Kubernetes Cluster Controller", "category": "DevOps", "stock": 14},
    {"id": 2, "name": "Prometheus Metrics Exporter", "category": "Observability", "stock": 25},
    {"id": 3, "name": "Grafana Dashboard Provisioner", "category": "Observability", "stock": 8},
    {"id": 4, "name": "Jenkins Automated Pipeline Agent", "category": "CI/CD", "stock": 19},
]


@app.route("/")
def root():
    return jsonify({
        "service": SERVICE_NAME,
        "pod": POD_NAME,
        "node": NODE_NAME,
        "status": "operational",
        "endpoints": ["/health", "/api/items"],
    })


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "service": SERVICE_NAME,
        "pod": POD_NAME,
        "node": NODE_NAME,
    }), 200


@app.route("/api/items")
def get_items():
    return jsonify({
        "service": SERVICE_NAME,
        "serviced_by_pod": POD_NAME,
        "serviced_by_node": NODE_NAME,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "total_items": len(ITEMS),
        "items": ITEMS,
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
