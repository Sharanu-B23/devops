# Exercise 06 - Application Observability (Prometheus + Alerting Rules + Grafana Dashboards)

## Objective
Implement end-to-end cloud-native observability for a containerized microservice application. Instrument a Python Flask web application using `prometheus_client` to expose application performance metrics (counters, histograms, gauges), configure Prometheus time-series database (TSDB) for periodic target scraping and alerting evaluation, define declarative alerting rules for error spikes and service outages, provision automated Grafana datasources and dashboards via YAML/JSON, and verify real-time metric collection and alert state transitions (`inactive` -> `pending` -> `firing`).

## Technologies used
- Prometheus (v2.51.0)
- Grafana (v10.4.1)
- Python (3.12-slim base, Flask 3.0.3, prometheus_client 0.20.0, Gunicorn 22.0.0)
- Docker Compose (v2.29+)
- PowerShell 5.1

## Prerequisites
- Docker Desktop with Linux containers running.
- Ports 5006 (Flask Web API), 9090 (Prometheus TSDB), and 3000 (Grafana UI) free on the host.

## Project structure
```text
exercise-06/
├── app/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── prometheus/
│   ├── alert_rules.yml
│   └── prometheus.yml
├── grafana/
│   ├── dashboards/
│   │   └── devops_dashboard.json
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboards.yml
│       └── datasources/
│           └── datasource.yml
├── docker-compose.yml
├── evidence/
│   ├── 01-compose-up.txt
│   ├── 02-metrics.txt
│   ├── 03-prometheus-targets.txt
│   ├── 04-alert-rules.txt
│   ├── 05-grafana-datasource.txt
│   └── 06-alert-firing.txt
└── README.md
```

## Step-by-step commands
```powershell
# 1. Start application and observability stack with Docker Compose
docker compose -f exercise-06/docker-compose.yml up -d --build
docker compose -f exercise-06/docker-compose.yml ps

# 2. Verify Flask metrics endpoint exposition
(Invoke-WebRequest -Uri "http://localhost:5006/metrics" -UseBasicParsing).Content -split "`n" | Select-String "http_requests_total|app_active_users"

# 3. Verify Prometheus scrape target health
(Invoke-RestMethod "http://localhost:9090/api/v1/targets").data.activeTargets | Select-Object scrapePool, health, lastScrapeDuration

# 4. Inspect registered Prometheus alerting rules
(Invoke-RestMethod "http://localhost:9090/api/v1/rules").data.groups.rules | Select-Object name, query, duration, health

# 5. Verify Grafana automated datasource provisioning
Invoke-RestMethod "http://admin:admin@localhost:3000/api/datasources" | Select-Object id, name, type, url, isDefault

# 6. Trigger simulated error spike and verify alert lifecycle (pending -> firing)
1..3 | ForEach-Object { try { Invoke-RestMethod "http://localhost:5006/simulate-error" } catch { } }
(Invoke-RestMethod "http://localhost:9090/api/v1/rules").data.groups.rules | Where-Object name -eq "HighSimulatedErrors" | Select-Object name, state
Start-Sleep -Seconds 10
(Invoke-RestMethod "http://localhost:9090/api/v1/rules").data.groups.rules | Where-Object name -eq "HighSimulatedErrors" | Select-Object name, state, health
```

## Configuration explanation
- **app/app.py**:
  - `http_requests_total` (`Counter`): Tracks cumulative HTTP requests partitioned by HTTP method, endpoint path, and status code.
  - `http_request_duration_seconds` (`Histogram`): Measures request latency into quantile buckets for computing p50/p95/p99 request duration distributions.
  - `app_simulated_errors_total` (`Counter`): Dedicated metric incremented on the `/simulate-error` route to evaluate threshold alerting rules.
  - `app_active_users` (`Gauge`): Fluctuating metric representing concurrent active sessions.
  - Non-root user `appuser` (UID 10001) for least-privilege container execution.
  - Single Gunicorn worker (`--workers 1`): Eliminates multi-process memory synchronization conflicts with `prometheus_client`.
- **prometheus/prometheus.yml**:
  - `scrape_interval: 5s`, `evaluation_interval: 5s`: High-resolution evaluation window suitable for rapid lab testing and alert responsiveness.
  - `scrape_configs`: Configures automated pulls from `web:5000/metrics` and `localhost:9090`.
  - Mounts `/etc/prometheus/alert_rules.yml`.
- **prometheus/alert_rules.yml**:
  - `HighSimulatedErrors`: Evaluates `increase(app_simulated_errors_total[1m]) > 2`. When the rate of simulated errors exceeds 2 within a 1-minute lookback window and persists for `10s`, the rule transitions from `pending` to `firing`.
  - `FlaskAppDown`: Evaluates `up{job="flask-app"} == 0` for `15s`, detecting container or network reachability failures.
- **grafana/provisioning/**:
  - `datasources/datasource.yml`: Automates datasource registration pointing to `http://prometheus:9090` with proxy access and default flag.
  - `dashboards/dashboards.yml` & `dashboards/devops_dashboard.json`: Declaratively provisions an interactive visualization dashboard featuring Request Rate timeseries, Active Users gauge, and Error stat panels without requiring manual UI configuration.

## Verification commands
```powershell
docker compose -f exercise-06/docker-compose.yml ps
Invoke-RestMethod "http://localhost:5006/health"
Invoke-RestMethod "http://localhost:9090/api/v1/targets"
Invoke-RestMethod "http://localhost:9090/api/v1/rules"
Invoke-RestMethod "http://admin:admin@localhost:3000/api/datasources"
```

## Actual observed results
### 01-compose-up.txt
```text
PS> docker compose -f exercise-06/docker-compose.yml up -d --build
[+] Building 31.2s (13/13) FINISHED
 => => naming to docker.io/library/ex06-flask:1.0
[+] Running 4/4
 ✔ Network ex06-monitoring-net  Created
 ✔ Container ex06-web           Healthy
 ✔ Container ex06-prometheus    Started
 ✔ Container ex06-grafana       Started
PS> docker compose -f exercise-06/docker-compose.yml ps
NAME              IMAGE                     COMMAND                  SERVICE      STATUS                    PORTS
ex06-grafana      grafana/grafana:10.4.1    "/run.sh"                grafana      Up 25 seconds             0.0.0.0:3000->3000/tcp
ex06-prometheus   prom/prometheus:v2.51.0   "/bin/prometheus --c…"   prometheus   Up 25 seconds             0.0.0.0:9090->9090/tcp
ex06-web          ex06-flask:1.0            "gunicorn --workers …"   web          Up 30 seconds (healthy)   0.0.0.0:5006->5000/tcp
[exit code: 0]
```

### 02-metrics.txt
```text
PS> (Invoke-WebRequest -Uri "http://localhost:5006/metrics" -UseBasicParsing).Content -split "`n" | Select-String "http_requests_total|app_active_users|app_simulated_errors_total"
# HELP http_requests_total Total HTTP requests received
# TYPE http_requests_total counter
http_requests_total{endpoint="/health",method="GET",status="200"} 12.0
http_requests_total{endpoint="/",method="GET",status="200"} 2.0
# HELP app_active_users Current number of simulated active connected users
# TYPE app_active_users gauge
app_active_users 12.0
# HELP app_simulated_errors_total Total simulated errors triggered for alerting tests
# TYPE app_simulated_errors_total counter
app_simulated_errors_total{error_type="simulated_500"} 4.0
[exit code: 0]
```

### 03-prometheus-targets.txt
```text
PS> (Invoke-RestMethod "http://localhost:9090/api/v1/targets").data.activeTargets | Select-Object scrapePool, health, lastScrapeDuration, lastError
scrapePool health lastScrapeDuration lastError
---------- ------ ------------------ ---------
flask-app  up     0.002665959                 
prometheus up     0.004014456                 
[exit code: 0]
```

### 04-alert-rules.txt
```text
PS> (Invoke-RestMethod "http://localhost:9090/api/v1/rules").data.groups.rules | Select-Object name, query, duration, health
name                query                                       duration health
----                -----                                       -------- ------
HighSimulatedErrors increase(app_simulated_errors_total[1m]) > 2      10 ok    
FlaskAppDown        up{job="flask-app"} == 0                          15 ok    
[exit code: 0]
```

### 05-grafana-datasource.txt
```text
PS> Invoke-RestMethod "http://admin:admin@localhost:3000/api/datasources" | Select-Object id, name, type, url, isDefault, readOnly
id name       type       url                    isDefault readOnly
-- ----       ----       ---                    --------- --------
 1 Prometheus prometheus http://prometheus:9090      True     True
[exit code: 0]
```

### 06-alert-firing.txt
```text
PS> # 1. Trigger simulated error spike (3 calls)
    1..3 | ForEach-Object { try { Invoke-RestMethod "http://localhost:5006/simulate-error" } catch { } }
    # 2. Check alert transitioning to pending
    (Invoke-RestMethod "http://localhost:9090/api/v1/rules").data.groups.rules | Where-Object name -eq "HighSimulatedErrors" | Select-Object name, state
    # 3. Wait for duration threshold (10s) and verify firing state
    Start-Sleep -Seconds 10
    (Invoke-RestMethod "http://localhost:9090/api/v1/rules").data.groups.rules | Where-Object name -eq "HighSimulatedErrors" | Select-Object name, state, health

name                state  
----                -----  
HighSimulatedErrors pending

name                state  health
----                -----  ------
HighSimulatedErrors firing ok    
[exit code: 0]
```

## Troubleshooting
- **Memory Pressure Optimization**: Default Prometheus and Grafana deployments without resource bounds can exhaust workstation physical memory. Hard memory limits were enforced in `docker-compose.yml` (`web: 128M`, `prometheus: 256M`, `grafana: 256M`), and TSDB retention was bound to 2 hours (`--storage.tsdb.retention.time=2h`), ensuring predictable execution under ~400 MB total footprint.
- **Docker Desktop GUI Crashes vs Engine Stability**: If Docker Desktop's Electron frontend window crashes due to hardware acceleration or GPU cache conflicts, the underlying Docker daemon and WSL2 VM continue running normally. All lifecycle management can be conducted headlessly via CLI and Compose (`docker compose ps`, `docker compose up -d`).

## Key concepts
- **Prometheus Scrape Interval**: The frequency with which the monitoring server pulls metrics from target endpoints.
- **Metric Types (Counter, Gauge, Histogram)**: Counters monotonically increase, gauges fluctuate, and histograms sample distributions into buckets.
- **PromQL**: Query language for computing rates, aggregations, and quantiles over time-series data.
- **Grafana Provisioning**: Declaratively configuring datasources and dashboards via YAML and JSON files at container startup.
- **Alert States (Inactive, Pending, Firing)**: Lifecycle transitions for Prometheus alerting rules based on duration thresholds.

## Viva questions
1. **What is pull-based vs push-based monitoring?**  
   *Answer:* Pull-based (Prometheus) queries target `/metrics` endpoints on schedule; push-based systems (Graphite, StatsD) have clients actively send data to a central collector.
2. **What is the difference between a Counter and a Gauge?**  
   *Answer:* A Counter only increases (or resets on restart), suitable for request counts; a Gauge can go up and down, suitable for memory usage or active threads.
3. **What does the PromQL `rate()` function calculate?**  
   *Answer:* It calculates the per-second average rate of increase of a time series over a specified lookback window.
4. **Why is only 1 Gunicorn worker used with the default Python prometheus_client?**  
   *Answer:* `prometheus_client` stores metrics in-memory per process; multi-worker gunicorn setups require shared multi-process memory directories.
5. **What is the purpose of Grafana provisioning?**  
   *Answer:* It eliminates manual UI dashboard setup by mounting datasource and dashboard configs directly from version-controlled files.
6. **What does the `for: 15s` clause mean in an alert rule?**  
   *Answer:* The condition must evaluate to true continuously for 15 seconds before transitioning from `pending` to `firing`.
7. **What is an exporter in Prometheus architecture?**  
   *Answer:* A sidecar or library that translates third-party system metrics (e.g. Node Exporter, MySQL Exporter) into Prometheus exposition format.
8. **Why is resource allocation critical when running Prometheus?**  
   *Answer:* The Prometheus Time-Series Database (TSDB) caches active blocks in RAM and performs intensive chunk compaction.

## Conclusion
Status: PASS. The application observability stack was successfully deployed and verified. Prometheus scrapes target endpoints every 5 seconds, custom metrics (Counter, Gauge, Histogram) are accurately ingested, Grafana datasources and dashboards are provisioned via code, and alerting rules correctly transition through Inactive, Pending, and Firing states upon simulated failure conditions.
