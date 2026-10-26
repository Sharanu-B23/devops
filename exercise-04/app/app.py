import os
import time

import pymysql
import redis
from flask import Flask, jsonify

app = Flask(__name__)


def db():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        database=os.environ["MYSQL_DATABASE"],
        autocommit=True,
        connect_timeout=5,
    )


def cache():
    return redis.Redis(host=os.environ["REDIS_HOST"], port=6379, socket_timeout=5, decode_responses=True)


def init_db():
    for _ in range(15):
        try:
            conn = db()
            with conn.cursor() as cur:
                cur.execute(
                    "CREATE TABLE IF NOT EXISTS visits ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)"
                )
            conn.close()
            return
        except Exception:
            time.sleep(2)
    raise RuntimeError("database not reachable")


@app.route("/")
def index():
    conn = db()
    with conn.cursor() as cur:
        cur.execute("INSERT INTO visits () VALUES ()")
        cur.execute("SELECT COUNT(*) FROM visits")
        total = cur.fetchone()[0]
    conn.close()
    hits = cache().incr("hits")
    return jsonify(message="Flask + MySQL + Redis", mysql_rows=total, redis_hits=hits)


@app.route("/health")
def health():
    status = {}
    try:
        conn = db()
        conn.ping()
        conn.close()
        status["mysql"] = "ok"
    except Exception:
        status["mysql"] = "error"
    try:
        status["redis"] = "ok" if cache().ping() else "error"
    except Exception:
        status["redis"] = "error"
    code = 200 if all(v == "ok" for v in status.values()) else 503
    return jsonify(status), code


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
