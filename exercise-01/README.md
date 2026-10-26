# Exercise 01 - Kubernetes Basics (Nginx Deployment + Service)

## Objective
Deploy an Nginx web server on a local single-node Minikube Kubernetes cluster using declarative YAML manifests, expose it via a NodePort Service, verify pod readiness with probes, and test HTTP accessibility via port forwarding.

## Technologies used
- Kubernetes (v1.37.0)
- Minikube (v1.39.0, Docker driver)
- Kubectl CLI (v1.36.1)
- Nginx (1.27-alpine)
- PowerShell 5.1

## Prerequisites
- Docker Desktop with Linux containers running.
- Minikube single-node cluster started and in `Ready` status (`minikube start --driver=docker`).
- Kubectl client configured with context `minikube`.

## Project structure
```text
exercise-01/
├── deployment.yaml
├── service.yaml
├── README.md
└── evidence/
    ├── 01-apply.txt
    ├── 02-rollout.txt
    ├── 03-pods.txt
    ├── 04-service.txt
    └── 05-http.txt
```

## Step-by-step commands
```powershell
# 1. Apply Kubernetes Deployment and Service manifests
kubectl --context minikube apply -f exercise-01/deployment.yaml -f exercise-01/service.yaml

# 2. Wait for Deployment rollout completion
kubectl --context minikube rollout status deployment/nginx-deployment --timeout=180s

# 3. Inspect running pods
kubectl --context minikube get pods -l app=nginx -o wide

# 4. Verify NodePort Service configuration
kubectl --context minikube get svc nginx-service

# 5. Port-forward and query HTTP root endpoint
$pf = Start-PortForward -Context minikube -Target svc/nginx-service -LocalPort 8085 -RemotePort 80
$r = Wait-Http "http://localhost:8085/" 200 30
"StatusCode: $($r.StatusCode)"
($r.Content -split "`n" | Select-String "Welcome to nginx")
Stop-PortForward $pf
```

## Configuration explanation
- **deployment.yaml**:
  - `apiVersion: apps/v1`, `kind: Deployment`: Declares a controller managing replicated pods.
  - `metadata.name: nginx-deployment`: Names the deployment resource.
  - `spec.replicas: 2`: Specifies that two identical Pod instances should run concurrently.
  - `spec.selector.matchLabels.app: nginx`: Determines which pods are managed by this deployment controller.
  - `spec.template.spec.containers`: Configures container `nginx` with image `nginx:1.27-alpine` on port 80.
  - `readinessProbe`: Performs an HTTP GET on `/` every 5 seconds (initial delay 2s); traffic is only routed when this returns 200–399.
  - `resources.requests` & `resources.limits`: Enforces CPU (25m request, 200m limit) and memory bounds (32Mi request, 128Mi limit).
- **service.yaml**:
  - `apiVersion: v1`, `kind: Service`: Creates a stable network endpoint abstraction for dynamic Pod IPs.
  - `spec.type: NodePort`: Exposes the service on each node's IP at a static port (`nodePort: 30080`).
  - `spec.selector.app: nginx`: Routes incoming traffic to pods carrying the `app=nginx` label.
  - `spec.ports`: Maps port 80 to container targetPort 80.

## Verification commands
```powershell
kubectl --context minikube get deploy nginx-deployment
kubectl --context minikube get pods -l app=nginx
kubectl --context minikube get svc nginx-service
```

## Actual observed results
### 01-apply.txt
```text
PS> kubectl --context minikube apply -f exercise-01/deployment.yaml -f exercise-01/service.yaml
deployment.apps/nginx-deployment created
service/nginx-service created
[exit code: 0]
```

### 02-rollout.txt
```text
PS> kubectl --context minikube rollout status deployment/nginx-deployment --timeout=180s
Waiting for deployment "nginx-deployment" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 1 of 2 updated replicas are available...
deployment "nginx-deployment" successfully rolled out
[exit code: 0]
```

### 03-pods.txt
```text
PS> kubectl --context minikube get pods -l app=nginx -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
nginx-deployment-c68859594-zn6w5   1/1     Running   0          36s   10.244.0.3   minikube   <none>           <none>
nginx-deployment-c68859594-zzxbg   1/1     Running   0          36s   10.244.0.4   minikube   <none>           <none>
[exit code: 0]
```

### 04-service.txt
```text
PS> kubectl --context minikube get svc nginx-service
NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx-service   NodePort   10.110.85.13   <none>        80:30080/TCP   37s
[exit code: 0]
```

### 05-http.txt
```text
PS> $pf = Start-PortForward -Context minikube -Target svc/nginx-service -LocalPort 8085 -RemotePort 80
    $r = Wait-Http "http://localhost:8085/" 200 30
    "StatusCode: $($r.StatusCode)"
    ($r.Content -split "`n" | Select-String "Welcome to nginx")
    Stop-PortForward $pf
StatusCode: 200
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
[exit code: 0]
```

## Troubleshooting
No problems encountered.

## Key concepts
- **Pod**: The smallest deployable unit in Kubernetes containing one or more tightly coupled containers.
- **Deployment**: Higher-level controller providing declarative updates for Pods and ReplicaSets.
- **ReplicaSet**: Low-level controller ensuring a specified number of identical pod replicas are running.
- **Service**: Stable network abstraction that load balances traffic across an ephemeral set of pods.
- **Labels & Selectors**: Key-value pairs used to group, query, and bind Kubernetes resources.
- **Readiness Probe**: Health check verifying whether a pod is ready to accept user network traffic.
- **Rolling Update**: Phased replacement of old pods with new pods to eliminate downtime during upgrades.

## Viva questions
1. **What is the difference between a Pod and a Deployment?**  
   *Answer:* A Pod is an ephemeral instance executing containers. A Deployment is a controller that manages Pod lifecycles, desired replica counts, and rolling updates.
2. **What are the differences between ClusterIP, NodePort, and LoadBalancer services?**  
   *Answer:* ClusterIP exposes the service internally within the cluster. NodePort exposes it on a static port across every node's external IP. LoadBalancer provisions an external cloud load balancer.
3. **What does `kubectl apply` do?**  
   *Answer:* It performs a three-way merge patch between the current live configuration, the target manifest, and the last-applied configuration annotation.
4. **How do label selectors connect Services to Deployments/Pods?**  
   *Answer:* A Service's `spec.selector` queries pods whose `metadata.labels` match those key-value pairs, generating matching Endpoint slices.
5. **What is the distinction between readiness and liveness probes?**  
   *Answer:* A readiness probe determines if a pod receives traffic via Services; a liveness probe determines if the container is healthy or must be restarted by kubelet.
6. **How can you roll back a deployment in Kubernetes?**  
   *Answer:* Using `kubectl rollout undo deployment/<name>` to revert to the previous revision.
7. **What happens if a pod managed by a Deployment crashes?**  
   *Answer:* The ReplicaSet detects `readyReplicas < desiredReplicas` and immediately schedules a new pod replacement.
8. **Why are resource requests and limits essential?**  
   *Answer:* Requests guide scheduler node placement; limits prevent a container from consuming excessive node CPU or memory (triggering OOM killer).

## Conclusion
Status: PASS. Both replicas reached 1/1 Running state, rollout succeeded, and the service served HTTP 200 with the default Nginx welcome text via port 8085.
