import time
from flask import Flask, jsonify, request, Response
from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

app = Flask(__name__)

# Prometheus Metrics Definitions
HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests received",
    ["method", "endpoint", "status"],
)

HTTP_REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)

SIMULATED_ERRORS_TOTAL = Counter(
    "app_simulated_errors_total",
    "Total simulated errors triggered for alerting tests",
    ["error_type"],
)

ACTIVE_USERS_GAUGE = Gauge(
    "app_active_users",
    "Current number of simulated active connected users",
)
ACTIVE_USERS_GAUGE.set(12)


@app.before_request
def start_timer():
    request._start_time = time.time()


@app.after_request
def record_metrics(response):
    if hasattr(request, "_start_time") and request.path != "/metrics":
        latency = time.time() - request._start_time
        endpoint = request.path
        status = str(response.status_code)
        method = request.method

        HTTP_REQUESTS_TOTAL.labels(method=method, endpoint=endpoint, status=status).inc()
        HTTP_REQUEST_DURATION.labels(endpoint=endpoint).observe(latency)

    return response


@app.route("/")
def index():
    return jsonify(
        {
            "service": "DevOps Observability Web API",
            "version": "1.0.0",
            "status": "operational",
            "endpoints": ["/health", "/metrics", "/simulate-error", "/users"],
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "web-api"}), 200


@app.route("/simulate-error")
def simulate_error():
    SIMULATED_ERRORS_TOTAL.labels(error_type="simulated_500").inc()
    return jsonify({"error": "Internal Server Error", "reason": "Simulated error triggered"}), 500


@app.route("/users")
def get_users():
    count = request.args.get("count", type=int)
    if count is not None:
        ACTIVE_USERS_GAUGE.set(count)
    return jsonify({"active_users": count or 12}), 200


@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
