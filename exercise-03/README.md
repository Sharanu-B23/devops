# Exercise 03 - Kubernetes ReplicaSet (3 -> 5, pod self-healing)

## Objective
Demonstrate the fundamental behavior of a Kubernetes ReplicaSet controller by deploying a Flask web application with 3 initial replicas, dynamically scaling the ReplicaSet to 5 replicas, validating automatic pod self-healing upon the intentional deletion of an active pod, and testing HTTP traffic routing.

## Technologies used
- Kubernetes (v1.37.0)
- Minikube (v1.39.0)
- Docker (29.9.2)
- Python (3.12-slim base, Flask 3.0.3, Gunicorn 22.0.0)
- Kubectl CLI (v1.36.1)

## Prerequisites
- Minikube single-node cluster `minikube` running and healthy.
- Docker Desktop Linux container runtime available.

## Project structure
```text
exercise-03/
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── k8s/
│   ├── replicaset.yaml
│   └── service.yaml
├── README.md
└── evidence/
    ├── 01-build-load.txt
    ├── 02-apply.txt
    ├── 03-ready3.txt
    ├── 04-scale5.txt
    ├── 05-before-delete.txt
    ├── 06-delete-replace.txt
    └── 07-http.txt
```

## Step-by-step commands
```powershell
# 1. Build application image and sideload into Minikube
docker build -t ex03-flask:1.0 exercise-03/app
minikube -p minikube image load ex03-flask:1.0
minikube -p minikube image ls | Select-String "ex03-flask"

# 2. Apply ReplicaSet and Service manifests
kubectl --context minikube apply -f exercise-03/k8s/

# 3. Wait for 3 replicas to reach Ready state
$ok = Wait-ReadyCount -Context minikube -Kind rs -Name flask-rs -Want 3 -TimeoutSec 150
"READY3: $ok"
kubectl --context minikube get rs flask-rs
kubectl --context minikube get pods -l app=flask-rs -o wide

# 4. Scale ReplicaSet from 3 to 5
kubectl --context minikube scale rs/flask-rs --replicas=5
$ok = Wait-ReadyCount -Context minikube -Kind rs -Name flask-rs -Want 5 -TimeoutSec 150
"READY5: $ok"
kubectl --context minikube get rs flask-rs
kubectl --context minikube get pods -l app=flask-rs

# 5. Snapshot pods before deletion
kubectl --context minikube get pods -l app=flask-rs

# 6. Delete a pod (victim) and verify replacement creation
$victim = kubectl --context minikube get pods -l app=flask-rs -o jsonpath='{.items[0].metadata.name}'
kubectl --context minikube delete pod $victim
# Wait for replacement pod to be Running and Ready
kubectl --context minikube get pods -l app=flask-rs

# 7. Port-forward and query HTTP endpoint
$pf = Start-PortForward -Context minikube -Target svc/flask-rs-service -LocalPort 8087 -RemotePort 80
1..6 | ForEach-Object { (Invoke-WebRequest http://localhost:8087/ -UseBasicParsing).Content }
Stop-PortForward $pf
```

## Configuration explanation
- **k8s/replicaset.yaml**:
  - `apiVersion: apps/v1`, `kind: ReplicaSet`: Defines a ReplicaSet controller resource.
  - `spec.replicas: 3`: Desired count of active pods.
  - `spec.selector.matchLabels.app: flask-rs`: Immutable label query used to acquire and maintain pod ownership.
  - `spec.template.spec.containers`: Runs `ex03-flask:1.0` with `imagePullPolicy: IfNotPresent` on port 5000.
  - `readinessProbe`: Validates `/health` endpoint before the pod is considered Ready.
- **k8s/service.yaml**:
  - `kind: Service`, `type: NodePort`: Exposes the pods matching `app: flask-rs` on cluster nodePort 30083 (mapping port 80 to container targetPort 5000).

## Image availability (ErrImageNeverPull)
Locally built images exist only in the Docker daemon of the host; Minikube nodes have their own separate container runtime storage. Therefore, `minikube image load <image:tag>` is required to transfer host-built images into Minikube's image cache (on a multi-node cluster, the image must exist on EVERY node, see Exercise 10). If a manifest uses `imagePullPolicy: Never` and the image was not loaded or is missing on the node, kubelet immediately fails with `ErrImageNeverPull`. To ensure robust, reproducible scheduling, this lab specifies `imagePullPolicy: IfNotPresent`, which allows kubelet to use the local node image when available and prevents unnecessary pull failures.

## Verification commands
```powershell
kubectl --context minikube get rs flask-rs
kubectl --context minikube get pods -l app=flask-rs
kubectl --context minikube get svc flask-rs-service
```

## Actual observed results
### 01-build-load.txt
```text
PS> docker build -t ex03-flask:1.0 exercise-03/app
    minikube -p minikube image load ex03-flask:1.0
    minikube -p minikube image ls | Select-String "ex03-flask"
#0 building with "desktop-linux" instance using docker driver
...
#11 naming to docker.io/library/ex03-flask:1.0 done
#11 unpacking to docker.io/library/ex03-flask:1.0 0.3s done
#11 DONE 0.8s
docker.io/library/ex03-flask:1.0
[exit code: 0]
```

### 02-apply.txt
```text
PS> kubectl --context minikube apply -f exercise-03/k8s/
replicaset.apps/flask-rs created
service/flask-rs-service created
[exit code: 0]
```

### 03-ready3.txt
```text
PS> $ok = Wait-ReadyCount -Context minikube -Kind rs -Name flask-rs -Want 3 -TimeoutSec 150
    "READY3: $ok"
    kubectl --context minikube get rs flask-rs
    kubectl --context minikube get pods -l app=flask-rs -o wide
READY3: True
NAME       DESIRED   CURRENT   READY   AGE
flask-rs   3         3         3       24s
NAME             READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
flask-rs-6wwrf   1/1     Running   0          24s   10.244.0.8   minikube   <none>           <none>
flask-rs-dh687   1/1     Running   0          24s   10.244.0.9   minikube   <none>           <none>
flask-rs-kng7j   1/1     Running   0          24s   10.244.0.7   minikube   <none>           <none>
[exit code: 0]
```

### 04-scale5.txt
```text
PS> kubectl --context minikube scale rs/flask-rs --replicas=5
    $ok = Wait-ReadyCount -Context minikube -Kind rs -Name flask-rs -Want 5 -TimeoutSec 150
    "READY5: $ok"
    kubectl --context minikube get rs flask-rs
    kubectl --context minikube get pods -l app=flask-rs
replicaset.apps/flask-rs scaled
READY5: True
NAME       DESIRED   CURRENT   READY   AGE
flask-rs   5         5         5       45s
NAME             READY   STATUS    RESTARTS   AGE
flask-rs-6wwrf   1/1     Running   0          45s
flask-rs-dh687   1/1     Running   0          45s
flask-rs-h7gn7   1/1     Running   0          21s
flask-rs-kng7j   1/1     Running   0          45s
flask-rs-whz4w   1/1     Running   0          21s
[exit code: 0]
```

### 05-before-delete.txt
```text
PS> kubectl --context minikube get pods -l app=flask-rs
NAME             READY   STATUS    RESTARTS   AGE
flask-rs-6wwrf   1/1     Running   0          47s
flask-rs-dh687   1/1     Running   0          47s
flask-rs-h7gn7   1/1     Running   0          23s
flask-rs-kng7j   1/1     Running   0          47s
flask-rs-whz4w   1/1     Running   0          23s
[exit code: 0]
```

### 06-delete-replace.txt
```text
PS> $victim = kubectl --context minikube get pods -l app=flask-rs -o jsonpath='{.items[0].metadata.name}'
    "VICTIM: $victim"
    kubectl --context minikube delete pod $victim
    $deadline = (Get-Date).AddSeconds(120); $good = $false
    while ((Get-Date) -lt $deadline) {
        $names = (kubectl --context minikube get pods -l app=flask-rs -o jsonpath='{.items[*].metadata.name}') -split ' ' | Where-Object { $_ }
        $ready = kubectl --context minikube get rs flask-rs -o jsonpath='{.status.readyReplicas}'
        if (($names.Count -eq 5) -and ($names -notcontains $victim) -and ("$ready" -eq "5")) { $good = $true; break }
        Start-Sleep -Seconds 3
    }
    "REPLACEMENT_CREATED: $good"
    kubectl --context minikube get pods -l app=flask-rs
VICTIM: flask-rs-6wwrf
pod "flask-rs-6wwrf" deleted from default namespace
REPLACEMENT_CREATED: True
NAME             READY   STATUS    RESTARTS   AGE
flask-rs-4jsfr   1/1     Running   0          15s
flask-rs-dh687   1/1     Running   0          64s
flask-rs-h7gn7   1/1     Running   0          40s
flask-rs-kng7j   1/1     Running   0          64s
flask-rs-whz4w   1/1     Running   0          40s
[exit code: 0]
```

### 07-http.txt
```text
PS> $pf = Start-PortForward -Context minikube -Target svc/flask-rs-service -LocalPort 8087 -RemotePort 80
    1..6 | ForEach-Object { (Invoke-WebRequest http://localhost:8087/ -UseBasicParsing).Content }
    Stop-PortForward $pf
{"message":"Hello from ReplicaSet demo","pod":"flask-rs-kng7j"}

{"message":"Hello from ReplicaSet demo","pod":"flask-rs-kng7j"}

{"message":"Hello from ReplicaSet demo","pod":"flask-rs-kng7j"}

{"message":"Hello from ReplicaSet demo","pod":"flask-rs-kng7j"}

{"message":"Hello from ReplicaSet demo","pod":"flask-rs-kng7j"}

{"message":"Hello from ReplicaSet demo","pod":"flask-rs-kng7j"}

[exit code: 0]
```

## Troubleshooting
No problems encountered.

## Key concepts
- **ReplicaSet Controller**: Continuously reconciles cluster state to ensure that the current number of active pods matching its selector matches the desired replica count.
- **Pod Self-Healing**: Automated detection and recreation of failed, deleted, or missing pods without manual operator intervention.
- **Dynamic Scaling**: Instantly adjusting capacity (`kubectl scale`) by increasing or decreasing desired replica count in the object spec.
- **Selector Immutability**: Once created, a ReplicaSet's label selector cannot be altered, ensuring unambiguous ownership of pod sets.
- **Desired vs Current vs Ready**: Desired is the target count; Current is the total scheduled pods; Ready is the subset that passed readiness probes.
- **Deployment Superiority**: Deployments wrap ReplicaSets to provide declarative rollouts, pausing, revision tracking, and zero-downtime rollbacks.

## Viva questions
1. **What is the difference between a ReplicaSet and a Deployment?**  
   *Answer:* A ReplicaSet ensures that a specific number of pod replicas are running. A Deployment manages ReplicaSets and adds declarative rollout strategies, revision history, and rollback capabilities.
2. **How does self-healing work in a ReplicaSet?**  
   *Answer:* The ReplicaSet controller reconciliation loop compares the number of live pods matching its selector against `spec.replicas`. If a pod is deleted, the count drops below desired and the controller calls the Kubernetes API to create a new pod.
3. **Can you change the selector of an existing ReplicaSet?**  
   *Answer:* No, `spec.selector` is immutable after creation because changing it would break controller ownership and orphan existing pods.
4. **Why is `kubectl scale` useful?**  
   *Answer:* It allows rapid manual scaling of workloads in response to traffic surges or resource constraints without modifying YAML files directly.
5. **What do DESIRED, CURRENT, and READY mean in `kubectl get rs`?**  
   *Answer:* DESIRED is the configured target replica count; CURRENT is the count of pods created; READY is the number of pods passing readiness probes and serving traffic.
6. **Why are bare ReplicaSets rarely used directly in production?**  
   *Answer:* Because bare ReplicaSets cannot perform rolling updates or rollbacks without manual pod management; Deployments should always be preferred.
7. **What is `ErrImageNeverPull` and why does it occur?**  
   *Answer:* It occurs when `imagePullPolicy: Never` is set and the container image is not present in the local node runtime cache, causing scheduling to fail.
8. **What does `minikube image load` do under the hood?**  
   *Answer:* It streams the container image from the host Docker daemon directly into Minikube's container runtime storage (containerd/docker).

## Conclusion
Status: PASS. The ReplicaSet was initialized with 3 pods, scaled up to 5 pods, recovered seamlessly from pod deletion by spawning replacement pod `flask-rs-4jsfr`, and served HTTP traffic properly.
