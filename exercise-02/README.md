# Exercise 02 - Flask + Minikube + Unit Tests

## Objective
Develop a containerized Flask microservice with production-grade Gunicorn WSGI server, run unit tests via pytest on the host, build and sideload the container image into Minikube, deploy it declaratively with readiness and liveness probes, expose it via a NodePort Service, and verify endpoints.

## Technologies used
- Python 3.14 (host virtual environment) / Python 3.12-slim (container base)
- Flask 3.0.3, Gunicorn 22.0.0, Pytest 8.3.2
- Docker 29.9.2
- Minikube v1.39.0 / Kubernetes v1.37.0
- Kubectl v1.36.1

## Prerequisites
- Working Python environment (`py -3`).
- Docker Desktop Linux container engine running.
- Minikube single-node cluster `minikube` in `Ready` status.

## Project structure
```text
exercise-02/
├── app/
│   ├── .venv/ (git-ignored)
│   ├── Dockerfile
│   ├── app.py
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── test_app.py
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── README.md
└── evidence/
    ├── 01-venv.txt
    ├── 02-tests.txt
    ├── 03-build.txt
    ├── 04-load.txt
    ├── 05-apply.txt
    ├── 06-rollout.txt
    ├── 07-pods.txt
    └── 08-http.txt
```

## Step-by-step commands
```powershell
# 1. Create virtual environment and install dev dependencies
py -3 -m venv exercise-02\app\.venv
exercise-02\app\.venv\Scripts\python.exe -m pip install -r exercise-02\app\requirements-dev.txt

# 2. Run unit tests locally before build
Set-Location exercise-02\app
.\.venv\Scripts\python.exe -m pytest -v
Set-Location D:\devops

# 3. Build container image
docker build -t ex02-flask:1.0 exercise-02/app

# 4. Sideload image into Minikube VM
minikube -p minikube image load ex02-flask:1.0
minikube -p minikube image ls | Select-String "ex02-flask"

# 5. Apply Kubernetes manifests
kubectl --context minikube apply -f exercise-02/k8s/

# 6. Wait for rollout
kubectl --context minikube rollout status deployment/flask-deployment --timeout=180s

# 7. Check running pods
kubectl --context minikube get pods -l app=flask-app -o wide

# 8. Test HTTP endpoints via port-forwarding
$pf = Start-PortForward -Context minikube -Target svc/flask-service -LocalPort 8086 -RemotePort 80
"ROOT:   " + (Invoke-WebRequest http://localhost:8086/ -UseBasicParsing).Content
"HEALTH: " + (Invoke-WebRequest http://localhost:8086/health -UseBasicParsing).Content
Stop-PortForward $pf
```

## Configuration explanation
- **app/Dockerfile**:
  - Uses `python:3.12-slim` as lightweight base.
  - Sets `PYTHONDONTWRITEBYTECODE=1` and `PYTHONUNBUFFERED=1` to optimize containerized Python logging.
  - Copies and installs `requirements.txt` before application source code to take advantage of Docker layer caching.
  - Creates and switches to a dedicated unprivileged user `appuser` (UID 10001) for least-privilege security.
  - Runs single-worker `gunicorn` binding to `0.0.0.0:5000`.
- **k8s/deployment.yaml**:
  - Specifies 2 replicas with `image: ex02-flask:1.0` and `imagePullPolicy: IfNotPresent`.
  - Configures `readinessProbe` checking `/health` every 5s (initial delay 3s).
  - Configures `livenessProbe` checking `/health` every 10s (initial delay 10s).
  - Specifies resource requests (50m CPU, 64Mi RAM) and limits (250m CPU, 192Mi RAM).
- **k8s/service.yaml**:
  - NodePort service routing traffic from port 80 to container targetPort 5000 on nodePort 30082.

## Verification commands
```powershell
kubectl --context minikube get deploy flask-deployment
kubectl --context minikube get pods -l app=flask-app
curl http://localhost:8086/
curl http://localhost:8086/health
```

## Actual observed results
### 01-venv.txt
```text
PS> py -3 -m venv exercise-02\app\.venv
    exercise-02\app\.venv\Scripts\python.exe -m pip install -r exercise-02\app\requirements-dev.txt
Collecting flask==3.0.3 (from -r D:\devops\exercise-02\app\requirements.txt (line 1))
  Downloading flask-3.0.3-py3-none-any.whl.metadata (3.2 kB)
Collecting gunicorn==22.0.0 (from -r D:\devops\exercise-02\app\requirements.txt (line 2))
  Downloading gunicorn-22.0.0-py3-none-any.whl.metadata (4.4 kB)
Collecting pytest==8.3.2 (from -r exercise-02\app\requirements-dev.txt (line 2))
  Downloading pytest-8.3.2-py3-none-any.whl.metadata (7.5 kB)
...
Successfully installed Jinja2-3.1.6 MarkupSafe-3.0.4 Werkzeug-3.1.9 blinker-1.9.0 click-8.5.0 colorama-0.4.6 flask-3.0.3 gunicorn-22.0.0 iniconfig-2.3.1 itsdangerous-2.2.0 packaging-26.3 pluggy-1.7.0 pytest-8.3.2
[exit code: 0]
```

### 02-tests.txt
```text
PS> Set-Location exercise-02\app
    .\.venv\Scripts\python.exe -m pytest -v
    Set-Location D:\devops
============================= test session starts =============================
platform win32 -- Python 3.14.4, pytest-8.3.2, pluggy-1.7.0 -- D:\devops\exercise-02\app\.venv\Scripts\python.exe
cachedir: .pytest_cache
rootdir: D:\devops\exercise-02\app
collecting ... collected 3 items

test_app.py::test_index_returns_200_and_message PASSED                   [ 33%]
test_app.py::test_health_returns_healthy PASSED                          [ 66%]
test_app.py::test_unknown_route_returns_404 PASSED                       [100%]

============================== 3 passed in 1.13s ==============================
[exit code: 0]
```

### 03-build.txt
```text
PS> docker build -t ex02-flask:1.0 exercise-02/app
#0 building with "desktop-linux" instance using docker driver
...
#11 naming to docker.io/library/ex02-flask:1.0 done
#11 unpacking to docker.io/library/ex02-flask:1.0 9.4s done
#11 DONE 10.9s
[exit code: 0]
```

### 04-load.txt
```text
PS> minikube -p minikube image load ex02-flask:1.0
    minikube -p minikube image ls | Select-String "ex02-flask"
docker.io/library/ex02-flask:1.0
[exit code: 0]
```

### 05-apply.txt
```text
PS> kubectl --context minikube apply -f exercise-02/k8s/
deployment.apps/flask-deployment created
service/flask-service created
[exit code: 0]
```

### 06-rollout.txt
```text
PS> kubectl --context minikube rollout status deployment/flask-deployment --timeout=180s
Waiting for deployment spec update to be observed...
Waiting for deployment "flask-deployment" rollout to finish: 0 out of 2 new replicas have been updated...
Waiting for deployment "flask-deployment" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "flask-deployment" rollout to finish: 1 of 2 updated replicas are available...
deployment "flask-deployment" successfully rolled out
[exit code: 0]
```

### 07-pods.txt
```text
PS> kubectl --context minikube get pods -l app=flask-app -o wide
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
flask-deployment-5f489945dd-bcrpp   1/1     Running   0          18s   10.244.0.6   minikube   <none>           <none>
flask-deployment-5f489945dd-tgzk2   1/1     Running   0          18s   10.244.0.5   minikube   <none>           <none>
[exit code: 0]
```

### 08-http.txt
```text
PS> $pf = Start-PortForward -Context minikube -Target svc/flask-service -LocalPort 8086 -RemotePort 80
    "ROOT:   " + (Invoke-WebRequest http://localhost:8086/ -UseBasicParsing).Content
    "HEALTH: " + (Invoke-WebRequest http://localhost:8086/health -UseBasicParsing).Content
    Stop-PortForward $pf
ROOT:   {"message":"Hello from Flask on Kubernetes","version":"1.0"}

HEALTH: {"status":"healthy"}

[exit code: 0]
```

## Troubleshooting
No problems encountered.

## Key concepts
- **Dockerfile Layers**: Independent immutable filesystem steps cached to accelerate subsequent builds.
- **Non-Root Execution**: Running container processes under non-zero UIDs prevents container escapes from easily compromising host privileges.
- **Gunicorn WSGI**: Production-grade concurrent HTTP WSGI server replacing Flask's single-threaded development server.
- **Minikube Image Sideloading**: Transferring host Docker images directly to Minikube's container runtime storage without a remote registry.
- **Readiness vs Liveness Probes**: Readiness dictates traffic routing; liveness dictates container restart on hang/deadlock.
- **NodePort Service**: Maps an external cluster port to an internal service port and target container port.
- **ImagePullPolicy IfNotPresent**: Instructs kubelet to use local images if found rather than querying external registries.
- **Pre-deployment Testing**: Running pytest before building and shipping container artifacts ensures defects are caught early in the development lifecycle.

## Viva questions
1. **How do Dockerfile layers work and how does caching benefit builds?**  
   *Answer:* Each instruction creates a read-only layer. Docker reuses cached layers if preceding instructions and contexts remain unchanged, speeding up builds significantly.
2. **Why should containers run as a non-root user?**  
   *Answer:* If an attacker escapes the container, they inherit the user UID on the host kernel; running non-root prevents host root takeover.
3. **Why use Gunicorn instead of Flask's built-in development server?**  
   *Answer:* The Flask built-in server is single-threaded and not designed for production concurrency, stability, or resource management.
4. **Why is `minikube image load` necessary?**  
   *Answer:* Minikube runs inside its own Docker/VM container with a separated containerd storage. Images built on the host daemon are not visible inside Minikube unless loaded or pulled from a registry.
5. **What is the difference between readiness and liveness probes?**  
   *Answer:* Readiness controls whether traffic is sent to the pod via endpoints; liveness determines whether kubelet must restart an unresponsive pod.
6. **What does `imagePullPolicy: IfNotPresent` do?**  
   *Answer:* It tells kubelet to first check local node cache for the image and only attempt remote pull if missing.
7. **Why should automated unit tests run before container image build?**  
   *Answer:* To practice fail-fast CI principles, preventing broken code from consuming image build resources and contaminating registry artifacts.
8. **What does a NodePort service provide?**  
   *Answer:* A static port (30000–32767) exposed across all nodes, proxying traffic into the service ClusterIP and backing pods.

## Conclusion
Status: PASS. 3 pytest unit tests passed locally, Docker image built and loaded into Minikube, 2 deployment replicas rolled out healthy, and root and /health endpoints returned valid JSON.
