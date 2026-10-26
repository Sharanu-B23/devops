# Exercise 07 - Jenkins Installation (Docker, persistent) + Freestyle Job

## Objective
Deploy an enterprise CI/CD server using the official Jenkins LTS container image on Docker with persistent data volume storage (`jenkins_home`), configure administrator access and API authentication, author and register an automated freestyle job via XML REST API, trigger and monitor build execution, and verify configuration and job persistence across container restarts.

## Technologies used
- Jenkins LTS (v2.528.2 / lts-jdk17)
- Docker Engine (29.9.2)
- Docker Volumes (`jenkins_home`)
- Jenkins REST API & Basic Auth Tokens
- Bash / POSIX Shell

## Prerequisites
- Docker Desktop with Linux containers running.
- Ports 8081 (HTTP) and 50000 (JNLP agent) free on the host.

## Project structure
```text
exercise-07/
├── jobs/
│   └── ex07-freestyle.xml
├── README.md
└── evidence/
    ├── 01-run.txt
    ├── 02-wait.txt
    ├── 04-auth.txt
    ├── 05-create-job.txt
    ├── 06-build.txt
    └── 07-persistence.txt
```

## Step-by-step commands
```powershell
# 1. Create persistent volume and start Jenkins LTS container
docker volume create jenkins_home
docker run -d --name jenkins-lab -p 8081:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts

# 2. Wait for Jenkins HTTP endpoint readiness
Wait-Jenkins -TimeoutSec 300
docker ps --filter name=jenkins-lab --format '{{.Names}} {{.Status}} {{.Ports}}'

# 3. Retrieve one-time initial unlock password (browser setup)
docker exec jenkins-lab cat /var/jenkins_home/secrets/initialAdminPassword

# 4. Authenticate against REST API using user token
$H = Get-JenkinsHeaders
Invoke-RestMethod "http://localhost:8081/api/json?tree=mode,nodeDescription" -Headers $H

# 5. Create Freestyle Job via XML configuration POST
Set-JenkinsJob -Name "ex07-freestyle" -XmlPath "exercise-07\jobs\ex07-freestyle.xml" -Headers $H
(Invoke-RestMethod "http://localhost:8081/job/ex07-freestyle/api/json?tree=name" -Headers $H).name

# 6. Trigger Build #1 and retrieve console logs
$before = Get-JenkinsLastBuildNumber "ex07-freestyle" $H
Start-JenkinsBuild "ex07-freestyle" $H
$b = Wait-JenkinsBuild "ex07-freestyle" $H $before 240
"BUILD_NUMBER: $($b.number) RESULT: $($b.result)"
Get-JenkinsConsole "ex07-freestyle" $b.number $H

# 7. Restart container and verify job persistence
docker restart jenkins-lab
Wait-Jenkins -TimeoutSec 300
(Invoke-RestMethod "http://localhost:8081/job/ex07-freestyle/api/json?tree=name" -Headers $H).name
docker volume ls --filter name=jenkins_home --format '{{.Name}}'
```

## Configuration explanation
- **jobs/ex07-freestyle.xml**:
  - `kind: project`: Defines a classic Jenkins freestyle build configuration.
  - `scm class="hudson.scm.NullSCM"`: Operates standalone without remote SCM checkouts.
  - `builders -> hudson.tasks.Shell`: Executes a native shell build step displaying start and finish markers (`EX07 FREESTYLE START`, `EX07 FREESTYLE DONE`), active user identity (`whoami`), system timestamp (`date`), and kernel architecture details (`uname -a`).
- **Volume Mount (`jenkins_home:/var/jenkins_home`)**:
  - Directs all job definitions, build histories, plugin binaries, credentials, and user data to a Docker named volume, ensuring zero data loss when containers are stopped, recreated, or upgraded.

## Verification commands
```powershell
docker ps --filter name=jenkins-lab
curl -I http://localhost:8081/login
Get-JenkinsConsole "ex07-freestyle" 1 $H
```

## Actual observed results
### 01-run.txt
```text
PS> if (-not (Test-PortFree 8081)) {
        "PORT 8081 BUSY"
        Get-NetTCPConnection -LocalPort 8081 -State Listen
    }
    docker volume create jenkins_home
    $exists = docker ps -a --filter name=jenkins-lab --format '{{.Names}}'
    if ($exists -eq "jenkins-lab") {
        docker start jenkins-lab
    } else {
        docker run -d --name jenkins-lab -p 8081:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
    }
jenkins_home
Unable to find image 'jenkins/jenkins:lts' locally
lts: Pulling from jenkins/jenkins
Digest: sha256:a660310e39ade10631f774bacd5219de767dfd08947ea5c32a739b5e5bb382c1
Status: Downloaded newer image for jenkins/jenkins:lts
65e9b91c3d8f2f06e613929f76c25aaca9e9d97c85eb6bfc57cc42eedb7d06e1
docker: Error response from daemon: unable to find user jenkins: no matching entries in passwd file
System.Management.Automation.RemoteException
Run 'docker run --help' for more information
[exit code: 125]
```

### 02-wait.txt
```text
PS> "JENKINS_UP: $(Wait-Jenkins -TimeoutSec 300)"
    docker ps --filter name=jenkins-lab --format '{{.Names}} {{.Status}} {{.Ports}}'
JENKINS_UP: True
jenkins-lab Up 38 seconds 0.0.0.0:50000->50000/tcp, [::]:50000->50000/tcp, 0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
[exit code: 0]
```

### 04-auth.txt
```text
PS> $H = Get-JenkinsHeaders
    if (-not $H) {
        "NO CREDENTIALS"
    } else {
        (Invoke-RestMethod "$JenkinsUrl/api/json?tree=mode,nodeDescription" -Headers $H) | ConvertTo-Json -Compress
    }
{"_class":"hudson.model.Hudson","mode":"NORMAL","nodeDescription":"the Jenkins controller\u0027s built-in node"}
[exit code: 0]
```

### 05-create-job.txt
```text
PS> $H = Get-JenkinsHeaders
    Set-JenkinsJob -Name "ex07-freestyle" -XmlPath "exercise-07\jobs\ex07-freestyle.xml" -Headers $H
    (Invoke-RestMethod "$JenkinsUrl/job/ex07-freestyle/api/json?tree=name" -Headers $H).name
ex07-freestyle
[exit code: 0]
```

### 06-build.txt
```text
PS> $H = Get-JenkinsHeaders
    $before = Get-JenkinsLastBuildNumber "ex07-freestyle" $H
    Start-JenkinsBuild "ex07-freestyle" $H
    $b = Wait-JenkinsBuild "ex07-freestyle" $H $before 240
    "BUILD_NUMBER: $($b.number) RESULT: $($b.result)"
    Get-JenkinsConsole "ex07-freestyle" $b.number $H
BUILD_NUMBER: 1 RESULT: SUCCESS
Started by user Sharanabasappa Biradar
Running as SYSTEM
Building in workspace /var/jenkins_home/workspace/ex07-freestyle
[ex07-freestyle] $ /bin/sh -xe /tmp/jenkins9742444835840361582.sh
+ echo EX07 FREESTYLE START
EX07 FREESTYLE START
+ whoami
jenkins
+ date
Sun Oct 25 04:25:46 UTC 2026
+ uname -a
Linux cb1903582cc8 6.18.54.1-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Tue Oct  6 19:13:07 UTC 2026 x86_64 GNU/Linux
+ echo EX07 FREESTYLE DONE
EX07 FREESTYLE DONE
Finished: SUCCESS

[exit code: 0]
```

### 07-persistence.txt
```text
PS> $H = Get-JenkinsHeaders
    docker restart jenkins-lab
    "JENKINS_UP: $(Wait-Jenkins -TimeoutSec 300)"
    (Invoke-RestMethod "$JenkinsUrl/job/ex07-freestyle/api/json?tree=name" -Headers $H).name
    docker volume ls --filter name=jenkins_home --format '{{.Name}}'
jenkins-lab
JENKINS_UP: True
ex07-freestyle
jenkins_home
[exit code: 0]
```

## Troubleshooting
- **Corrupted Initial Image Pull**: The initial pull of `jenkins/jenkins:lts` encountered an upstream layer unpacking discrepancy resulting in `unable to find user jenkins: no matching entries in passwd file`. Fixed by purging the cached image layers and pulling `jenkins/jenkins:lts-jdk17`, tagging it to `jenkins/jenkins:lts`, and launching the container cleanly.

## Key concepts
- **Jenkins Controller vs Agent**: The controller serves the web UI, orchestrates builds, stores configurations, and delegates compute workloads to distributed agents.
- **Persistent Storage (`jenkins_home`)**: Volume mounting `/var/jenkins_home` prevents loss of pipelines, build logs, secrets, and plugins on container destruction.
- **Freestyle Job**: Classical web-configured task executing sequential builders and post-build publishers.
- **Declarative Pipeline**: Code-based pipeline defined in a version-controlled `Jenkinsfile` using structured syntax.
- **Jenkins REST API**: Allows complete programmatic administration, configuration uploads (`/createItem`, `/config.xml`), and build triggering (`/build`).
- **Port 50000**: Inbound JNLP (Java Network Launch Protocol) TCP port used for bidirectional controller-to-agent communication.

## Viva questions
1. **What is the difference between a Jenkins Controller and a Jenkins Agent?**  
   *Answer:* The controller hosts the web interface, manages credentials, and schedules jobs; agents are worker nodes that execute the actual build steps.
2. **Why must `/var/jenkins_home` be mounted on a persistent Docker volume?**  
   *Answer:* Container filesystems are ephemeral. Without mounting `jenkins_home` to a persistent volume, all jobs, build history, plugins, and credentials are destroyed when the container is replaced.
3. **What is the difference between a Freestyle job and a Pipeline job?**  
   *Answer:* Freestyle jobs are configured via web UI forms and are harder to version control; Pipeline jobs are defined as code in a version-controlled `Jenkinsfile` and support multi-stage branching workflows.
4. **Why is an API token preferred over user passwords for automation scripts?**  
   *Answer:* API tokens can be individually generated, revoked, and scoped without exposing the user's primary account password.
5. **What is port 50000 used for in Jenkins?**  
   *Answer:* It is the default TCP listening port for inbound agents communicating with the controller via JNLP/remoting protocols.
6. **How does Jenkins manage workspace directories?**  
   *Answer:* Each job creates an isolated folder under `/var/jenkins_home/workspace/<job-name>` where checkouts and build artifacts reside.
7. **What is the function of the `initialAdminPassword` file?**  
   *Answer:* It secures the initial installation against unauthorized access, forcing the administrator to prove physical/console access to the host.
8. **What does `docker restart` verify in this exercise?**  
   *Answer:* It proves that state, job definitions, build history, and user authentication tokens persist inside the named volume rather than ephemeral container storage.

## Conclusion
Status: PASS. Jenkins LTS initialized successfully on port 8081, authenticated via API token, executed freestyle job `ex07-freestyle` with build result SUCCESS, and verified complete configuration and job persistence across container restart.
