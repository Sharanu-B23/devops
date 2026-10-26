# Exercise 09 - Jenkins Declarative Pipeline (Build, Test, Deploy, and Verify)

## Objective
Author and execute a robust multi-stage Jenkins Declarative Pipeline (`Jenkinsfile`) that automates continuous integration and continuous deployment (CI/CD) for a Python Flask application. The pipeline checks out repository code, builds a versioned Docker image, creates an isolated virtual environment to execute automated unit tests via PyTest, deploys the container onto a dedicated Docker bridge network, runs automated HTTP health verification against the live container, and executes automated post-build cleanup.

## Technologies used
- Jenkins LTS (v2.528.2 / lts-jdk17 with Docker CLI & Python 3.13 runtime)
- Docker Engine & Docker Pipelines
- Python (3.12-slim base, Flask 3.0.3, PyTest 8.3.2)
- Groovy / Jenkins Declarative Pipeline DSL
- PowerShell 5.1

## Prerequisites
- Jenkins controller running with Docker CLI and Python installed or Docker socket mounted (`/var/run/docker.sock`).
- Source code with `Jenkinsfile` and `exercise-09/app/` committed to repository.
- Host port 5009 free for application deployment.

## Project structure
```text
exercise-09/
├── app/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements-dev.txt
│   ├── requirements.txt
│   └── test_app.py
├── evidence/
│   ├── 01-local-tests.txt
│   ├── 02-jenkins-image.txt
│   ├── 03-network.txt
│   └── 04-swap-jenkins.txt
├── jenkins/
│   └── Dockerfile
├── jobs/
│   └── ex09-pipeline.template.xml
├── Jenkinsfile
└── README.md
```

## Declarative Pipeline Stages
1. **Build**: Verifies Docker daemon connectivity and builds container image `ex09-flask:ci`.
2. **Test**: Configures isolated virtual environment, installs development dependencies, and executes PyTest unit test suite.
3. **Deploy**: Cleans up previous container instances and launches new container on dedicated network `ex09-net` bound to host port 5009.
4. **Run Application**: Performs polling HTTP health checks against `/health` and queries root `/` endpoint.
5. **Cleanup**: Removes deployment container and temporary testing artifacts.
6. **Post Actions**: Enforces unconditional cleanup (`always`) and outputs build status alerts (`success` / `failure`).

## Step-by-step commands
```powershell
# 1. Run local test suite validation
python -m venv exercise-09/app/.venv
./exercise-09/app/.venv/Scripts/pip install -r exercise-09/app/requirements-dev.txt
./exercise-09/app/.venv/Scripts/pytest exercise-09/app -v

# 2. Build custom Jenkins LTS image with Docker and Python runtime
docker build -t jenkins-dind:custom exercise-09/jenkins

# 3. Create dedicated bridge network
docker network create ex09-net

# 4. Swap Jenkins container to custom image mounting docker.sock
docker stop jenkins-lab
docker rm jenkins-lab
docker run -d --name jenkins-lab -p 8081:8080 -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  -v //var/run/docker.sock:/var/run/docker.sock `
  --network ex09-net `
  jenkins-dind:custom

# 5. Register pipeline job in Jenkins via REST API
$H = Get-JenkinsHeaders
Set-JenkinsJob -Name "ex09-declarative-pipeline" -XmlPath "exercise-09/jobs/ex09-pipeline.xml" -Headers $H

# 6. Trigger pipeline build and inspect stage logs
Start-JenkinsBuild "ex09-declarative-pipeline" $H
```

## Configuration explanation
- **Jenkinsfile**:
  - `pipeline { agent any }`: Executes pipeline steps on any available executor.
  - `options { timeout(time: 15, unit: 'MINUTES'); disableConcurrentBuilds() }`: Prevents runaway builds and concurrent workspace collisions.
  - `stage('Build')`: Invokes `docker build -t "$IMAGE" "$APP_DIR"` to create the deployable container artifact.
  - `stage('Test')`: Runs `python -m pytest "$APP_DIR" -v` inside an ephemeral `.venv`. If any test fails, the pipeline aborts immediately, preventing bad code deployment.
  - `stage('Deploy')`: Deploys the freshly built container onto `ex09-net` with host port mapping `5009:5000`.
  - `stage('Run Application')`: Polls the application's `/health` endpoint up to 20 times with 2-second intervals, ensuring the server has initialized before accepting traffic.
  - `post { always { ... } }`: Ensures teardown of testing containers and virtual environments even if test or deploy stages encounter fatal errors.
- **jenkins/Dockerfile**:
  - Base `jenkins/jenkins:lts-jdk17`, installing `docker.io`, `python3`, `python3-venv`, and `python3-pip` via apt as `root`, adding user `jenkins` to the `docker` group.

## Verification commands
```powershell
docker ps --filter name=jenkins-lab
Invoke-RestMethod "http://localhost:8081/job/ex09-declarative-pipeline/api/json" -Headers $H
Invoke-RestMethod "http://localhost:5009/health"
```

## Actual observed results
### 01-local-tests.txt
```text
PS> py -3 -m venv exercise-09\app\.venv
    exercise-09\app\.venv\Scripts\python.exe -m pip install -r exercise-09\app\requirements-dev.txt
    .\.venv\Scripts\python.exe -m pytest -v
============================= test session starts =============================
test_app.py::test_index_returns_200_and_message PASSED                   [ 33%]
test_app.py::test_health_returns_healthy PASSED                          [ 66%]
test_app.py::test_unknown_route_returns_404 PASSED                       [100%]
============================== 3 passed in 1.05s ==============================
[exit code: 0]
```

### 04-swap-jenkins.txt
```text
PS> "JENKINS_UP: $(Wait-Jenkins -TimeoutSec 300)"
    docker exec jenkins-lab docker version --format '{{.Server.Version}}'
    docker exec jenkins-lab python3 --version
JENKINS_UP: True
29.9.2
Python 3.13.5
[exit code: 0]
```

## Troubleshooting
- **Docker-in-Docker Socket Permissions**: When Jenkins runs inside a container and communicates with host Docker via `/var/run/docker.sock`, non-root user `jenkins` can encounter permission denied errors. Adding `jenkins` user to host group `docker` (or GID mapping) inside the container Dockerfile resolves socket access.
- **Workspace Cleanup on Build Failure**: Partial build failures in script blocks can leave orphaned test containers bound to port 5009. The `post { always { ... } }` block ensures cleanup commands execute regardless of stage completion status.

## Key concepts
- **Declarative Pipeline**: Structured, opinionated syntax for defining CI/CD workflows with built-in stage scoping, agent management, and directive options.
- **Shift-Left Testing**: Automating test execution in the CI pipeline prior to deployment, preventing regressions from propagating downstream.
- **Docker-out-of-Docker (DooD)**: Mounting host `/var/run/docker.sock` into the CI container so Jenkins commands control the host Docker daemon directly without container-in-container nesting overhead.
- **Readiness Probing in CI**: Verifying live container responsiveness (`/health`) as part of the pipeline verification stage before concluding deployment success.

## Viva questions
1. **What is the difference between Scripted and Declarative Jenkins Pipelines?**  
   *Answer:* Declarative syntax is strict, structured, and easier to read with defined blocks (`pipeline`, `stages`, `steps`, `post`), whereas Scripted syntax uses Groovy procedural code with `node { ... }` blocks for arbitrary programming logic.
2. **What is the role of the `post` block in a Declarative Pipeline?**  
   *Answer:* It defines actions executed at the completion of the pipeline or stage depending on the outcome (`always`, `changed`, `success`, `failure`, `unstable`, `aborted`).
3. **What is DooD (Docker-out-of-Docker) vs DinD (Docker-in-Docker)?**  
   *Answer:* DooD mounts the host `/var/run/docker.sock` so containers spawned run alongside the CI container on the host Docker daemon; DinD runs a complete isolated daemon inside a privileged container with nested filesystems.
4. **Why should `disableConcurrentBuilds()` be used in deployment pipelines?**  
   *Answer:* It prevents race conditions and port/resource conflicts where multiple simultaneous pipeline runs attempt to bind to the same host port or overwrite deployed containers.
5. **What happens when a step in the `Test` stage exits with a non-zero exit code?**  
   *Answer:* The stage immediately fails, subsequent stages (`Deploy`, `Run Application`) are skipped, and execution transitions directly to matching `post` handlers.
6. **How does Jenkins locate a `Jenkinsfile` from SCM?**  
   *Answer:* The Jenkins Git/SCM plugin fetches the repository branch, checks out the files into the workspace, and looks for the path specified in `scriptPath` (default `Jenkinsfile`).
7. **What is the benefit of running tests in a dedicated Python virtual environment (`venv`) inside CI?**  
   *Answer:* It isolates testing dependencies from the host/system Python packages, guaranteeing reproducibility and eliminating dependency version conflicts.
8. **Why is polling `/health` in a loop necessary after `docker run -d`?**  
   *Answer:* `docker run -d` returns immediately once the process begins starting, but web frameworks and WSGI servers require several seconds to bind to the socket and initialize application routes.

## Conclusion
Status: PASS. The end-to-end declarative CI/CD pipeline was successfully configured and verified. Automated testing, image packaging, container deployment, and health verification stages executed with 100% test pass rate and automated cleanup.
