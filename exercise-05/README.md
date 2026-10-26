# Exercise 05 - Docker Security (+ Python Docker SDK demo)

## Objective
Audit and analyze Docker daemon security subsystems (seccomp, cgroups, AppArmor/SELinux), demonstrate container isolation enforcement mechanisms including read-only root filesystems and capability dropping (`--cap-drop ALL`), author an example AppArmor security profile, and programmatically manage container lifecycles via the official Python Docker SDK.

## Technologies used
- Docker Engine (29.9.2, Linux container runtime)
- Python 3.14 (virtual environment `exercise-05/.venv`)
- Docker SDK for Python (`docker==7.1.0`)
- Alpine Linux (3.20)
- Linux Kernel Security Subsystems (seccomp, capabilities, namespaces)

## Prerequisites
- Docker Desktop with Linux containers running.
- Python 3 installed (`py -3`).

## Project structure
```text
exercise-05/
├── apparmor/
│   └── ex05-deny-write
├── .venv/ (git-ignored)
├── docker_demo.py
├── requirements.txt
├── README.md
└── evidence/
    ├── 01-security-options.txt
    ├── 02-apparmor-check.txt
    ├── 03-readonly-demo.txt
    ├── 04-capdrop-demo.txt
    ├── 05-sdk-venv.txt
    ├── 06-sdk-demo.txt
    └── 07-confirm-removed.txt
```

## Step-by-step commands
```powershell
# 1. Audit daemon security options
docker info --format '{{json .SecurityOptions}}'
docker info

# 2. Check AppArmor support in the container environment
docker run --rm alpine:3.20 sh -c "cat /proc/self/attr/current 2>&1; echo; cat /sys/module/apparmor/parameters/enabled 2>&1"
docker run --rm --security-opt apparmor=ex05-deny-write alpine:3.20 echo hi

# 3. Demonstrate read-only root filesystem restriction
docker run --rm --read-only alpine:3.20 sh -c "touch /testfile"

# 4. Demonstrate Linux capability restriction (dropping ALL capabilities)
docker run --rm --cap-drop ALL alpine:3.20 sh -c "touch /tmp/f && chown 1000 /tmp/f"

# 5. Create Python virtual environment and install Docker SDK
py -3 -m venv exercise-05\.venv
exercise-05\.venv\Scripts\python.exe -m pip install -r exercise-05\requirements.txt

# 6. Execute Python Docker SDK automation script
exercise-05\.venv\Scripts\python.exe exercise-05\docker_demo.py

# 7. Confirm temporary container removal
docker ps -a --filter "name=ex05-temp-demo" --format '{{.Names}}'
```

## Configuration explanation
- **apparmor/ex05-deny-write**:
  - Declares an AppArmor profile targeting container confinement.
  - Grants base permissions (`network`, `capability`, `file`, `umount`).
  - Explicitly denies write access to sensitive directory trees (`deny /etc/** w`, `deny /root/** w`).
- **docker_demo.py**:
  - Connects to the local Docker daemon via named pipe using `docker.from_env()`.
  - Queries server version and lists existing containers non-destructively.
  - Pulls image `alpine:3.20` and creates an isolated detached container `ex05-temp-demo`.
  - Executes dynamic commands (`exec_run`), captures process output and logs, and cleanly stops and removes the container in a `finally:` block.

## AppArmor Statement
The Docker daemon does not report AppArmor on this host (Docker Desktop / WSL2). The example profile was created for reference; its syntax was not validated and enforcement was NOT TESTED.

## Verification commands
```powershell
docker info --format '{{json .SecurityOptions}}'
exercise-05\.venv\Scripts\python.exe exercise-05\docker_demo.py
docker ps -a --filter "name=ex05-temp-demo"
```

## Actual observed results
### 01-security-options.txt
```text
PS> docker info --format '{{json .SecurityOptions}}'
    docker info
["name=seccomp,profile=builtin","name=cgroupns"]
Client:
 Version:    29.9.2
 Context:    desktop-linux
 Debug Mode: false
...
 Security Options:
  seccomp
   Profile: builtin
  cgroupns
 Kernel Version: 6.18.54.1-microsoft-standard-WSL2
 Operating System: Docker Desktop
 OSType: linux
 Architecture: x86_64
 CPUs: 8
 Total Memory: 2.781GiB
 Name: docker-desktop
 ID: da4a58f4-05e2-4f2b-a4ee-73ad28703aa1
 Docker Root Dir: /var/lib/docker
[exit code: 0]
```

### 02-apparmor-check.txt
```text
PS> docker run --rm alpine:3.20 sh -c "cat /proc/self/attr/current 2>&1; echo; cat /sys/module/apparmor/parameters/enabled 2>&1"
    docker run --rm --security-opt apparmor=ex05-deny-write alpine:3.20 echo hi
Unable to find image 'alpine:3.20' locally
3.20: Pulling from library/alpine
25f1d6b1951a: Pulling fs layer
3a030ca3f633: Download complete
d4050d56ebf2: Download complete
25f1d6b1951a: Download complete
25f1d6b1951a: Pull complete
Digest: sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc
Status: Downloaded newer image for alpine:3.20
kernel 
N
hi
[exit code: 0]
```

### 03-readonly-demo.txt
```text
PS> docker run --rm --read-only alpine:3.20 sh -c "touch /testfile"
touch: /testfile: Read-only file system
[exit code: 1]
```

### 04-capdrop-demo.txt
```text
PS> docker run --rm --cap-drop ALL alpine:3.20 sh -c "touch /tmp/f && chown 1000 /tmp/f"
chown: /tmp/f: Operation not permitted
[exit code: 1]
```

### 05-sdk-venv.txt
```text
PS> py -3 -m venv exercise-05\.venv
    exercise-05\.venv\Scripts\python.exe -m pip install -r exercise-05\requirements.txt
Collecting docker==7.1.0 (from -r exercise-05\requirements.txt (line 1))
  Downloading docker-7.1.0-py3-none-any.whl.metadata (3.8 kB)
...
Successfully installed certifi-2026.10.23 charset_normalizer-3.5.2 docker-7.1.0 idna-3.20 pywin32-312 requests-2.34.2 urllib3-2.8.0
[exit code: 0]
```

### 06-sdk-demo.txt
```text
PS> exercise-05\.venv\Scripts\python.exe exercise-05\docker_demo.py
DOCKER SERVER VERSION: 29.9.2
EXISTING CONTAINERS:
   786306c0f5ac minikube running
STARTED: ex05-temp-demo status = running
EXEC EXIT CODE: 0
EXEC OUTPUT: hello from exec
LOGS: log-line-from-demo
REMOVED: ex05-temp-demo
[exit code: 0]
```

### 07-confirm-removed.txt
```text
PS> docker ps -a --filter "name=ex05-temp-demo" --format '{{.Names}}'

[exit code: 0]
```

## Troubleshooting
No problems encountered.

## Key concepts
- **Namespaces**: Linux kernel primitives (PID, NET, IPC, MNT, UTS, USER) providing process-level isolation.
- **Control Groups (cgroups v2)**: Subsystems that meter, throttle, and bound CPU, memory, I/O, and pids per container.
- **Linux Capabilities**: Splitting superuser root privileges into granular independent permissions (e.g., `CAP_CHOWN`, `CAP_NET_BIND_SERVICE`).
- **Seccomp (Secure Computing Mode)**: Restricts the system calls a containerized process can invoke against the host kernel.
- **AppArmor vs SELinux**: Linux Security Modules implementing Mandatory Access Control (MAC); AppArmor uses path-based rules whereas SELinux enforces label/type-based policies.
- **Read-Only Root Filesystem**: Prevents attackers or compromised services from modifying binary files or dropping persistent malware in the container filesystem.
- **Docker Socket Security**: Mounting `/var/run/docker.sock` provides unauthenticated administrative control over the host Docker daemon.

## Viva questions
1. **What are Linux namespaces and what do they isolate?**  
   *Answer:* Namespaces partition kernel resources so each container sees its own isolated view of processes (pid), networking (net), mounts (mnt), hostnames (uts), and user UIDs (user).
2. **What role do cgroups play in container security?**  
   *Answer:* Cgroups enforce hard limits on physical resources (CPU, RAM, swap, IOPS), preventing a single container from starving host resources (Denial of Service).
3. **What is the security significance of dropping capabilities (`--cap-drop ALL`)?**  
   *Answer:* It adheres to the principle of least privilege, preventing processes—even if running as root—from modifying file ownership, raw sockets, or kernel parameters.
4. **How does seccomp protect the host kernel?**  
   *Answer:* Seccomp filters system calls using BPF programs, blocking dangerous kernel syscalls that could be exploited to escape containers.
5. **What is the difference between AppArmor and SELinux?**  
   *Answer:* AppArmor matches filesystem pathname strings and is standard on Ubuntu/Debian; SELinux attaches security labels to inodes and subjects and is standard on RHEL/Fedora.
6. **Why is mounting `/var/run/docker.sock` inside a container a major security vulnerability?**  
   *Answer:* Any process with write access to the Docker socket can communicate with the daemon to create privileged containers, mount the host root filesystem, and achieve full host takeover.
7. **What is `--security-opt no-new-privileges`?**  
   *Answer:* It prevents child processes from gaining additional privileges via `setuid` or `setgid` binaries inside the container.
8. **Why should container root filesystems be mounted read-only?**  
   *Answer:* To ensure immutability; attackers cannot modify application code, replace shared libraries, or persist malicious files within the container.

## Conclusion
Status: PASS. Daemon security options were recorded, read-only rootfs and capability dropping restrictions successfully demonstrated expected enforcement, and the Python Docker SDK automated the full container lifecycle with zero remaining orphaned containers.
