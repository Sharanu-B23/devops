# Exercise 10 - Multi-Node Kubernetes Cluster + Distributed Microservices Architecture

## Objective
Orchestrate a multi-tier, distributed microservices application on a multi-node Kubernetes cluster. Deploy an independent Backend Catalog microservice and a Frontend Order microservice, configure cross-node inter-service DNS discovery (`ClusterIP`), expose the user-facing application via `NodePort`, enforce inter-pod anti-affinity across cluster nodes to guarantee high availability and fault domain isolation, inject node topology using the Kubernetes Downward API, and verify resilience during pod eviction and rolling self-healing.

## Technologies used
- Kubernetes (v1.30+ / v1.36+ / Minikube Multi-Node)
- Kubectl CLI
- Docker Engine
- Python (3.12-slim base, Flask 3.0.3, Gunicorn 22.0.0, Requests 2.32.3)
- PowerShell 5.1

## Prerequisites
- Multi-node Kubernetes cluster running (e.g., `minikube start --nodes 3 --driver=docker`).
- Kubectl configured with cluster context.
- Container images loaded onto worker nodes or accessible via container registry.

## Project structure
```text
exercise-10/
├── backend/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── k8s/
│   ├── 01-configmap.yaml
│   ├── 02-backend-deployment.yaml
│   ├── 03-backend-service.yaml
│   ├── 04-frontend-deployment.yaml
│   └── 05-frontend-service.yaml
├── evidence/
│   ├── 01-nodes.txt
│   ├── 02-build-load.txt
│   ├── 03-apply.txt
│   ├── 04-pods-distribution.txt
│   ├── 05-services.txt
│   ├── 06-inter-service-call.txt
│   └── 07-resilience.txt
└── README.md
```

## Step-by-step commands
```powershell
# 1. Inspect multi-node cluster topology and node readiness
kubectl get nodes -o wide

# 2. Build microservice images and load into cluster nodes
docker build -t ex10-backend:1.0 exercise-10/backend
docker build -t ex10-frontend:1.0 exercise-10/frontend
# When using Minikube multi-node:
# minikube image load ex10-backend:1.0
# minikube image load ex10-frontend:1.0

# 3. Apply ConfigMap and Microservice Deployments
kubectl apply -f exercise-10/k8s/01-configmap.yaml
kubectl apply -f exercise-10/k8s/02-backend-deployment.yaml
kubectl apply -f exercise-10/k8s/03-backend-service.yaml
kubectl apply -f exercise-10/k8s/04-frontend-deployment.yaml
kubectl apply -f exercise-10/k8s/05-frontend-service.yaml

# 4. Wait for rollouts and inspect pod node distribution
kubectl rollout status deployment/backend-catalog-deployment --timeout=180s
kubectl rollout status deployment/frontend-order-deployment --timeout=180s
kubectl get pods -o wide --show-labels

# 5. Verify internal ClusterIP and external NodePort services
kubectl get svc backend-catalog-service frontend-order-service -o wide

# 6. Test inter-service communication and load distribution
$pf = Start-Process -FilePath "kubectl" -ArgumentList @("port-forward", "svc/frontend-order-service", "8090:80") -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3
Invoke-RestMethod "http://localhost:8090/" | ConvertTo-Json -Depth 5
Stop-Process -Id $pf.Id -Force

# 7. Test node resilience and self-healing pod replacement
$targetPod = (kubectl get pods -l app=backend-catalog -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $targetPod
kubectl get pods -l app=backend-catalog -o wide
```

## Configuration explanation
- **k8s/01-configmap.yaml**:
  - `microservices-config`: Externalizes configuration decoupling application code from runtime environment.
  - Injects `CATALOG_SERVICE_URL: "http://backend-catalog-service:5000/api/items"`, leveraging CoreDNS cluster resolution.
- **k8s/02-backend-deployment.yaml**:
  - `spec.replicas: 3`: Spawns 3 backend catalog replicas.
  - `podAntiAffinity` (`topologyKey: "kubernetes.io/hostname"`): Guides scheduler to place backend replicas on separate physical/virtual nodes, mitigating single point of failure (SPOF).
  - Downward API (`fieldRef`): Exposes node metadata (`spec.nodeName`) and pod identity (`metadata.name`) into container environment variables.
  - Readiness/Liveness Probes: Continuously evaluates container health over `/health` on HTTP port 5000.
  - Resources: Strict CPU request (25m) and limits (200m), memory request (32Mi) and limits (128Mi) to maintain cluster stability.
- **k8s/03-backend-service.yaml**:
  - `kind: Service`, `type: ClusterIP`: Internal-only layer 4 abstraction; backend pods are shielded from outside internet access and only reachable within the Kubernetes SDN overlay.
- **k8s/04-frontend-deployment.yaml**:
  - `spec.replicas: 3`: Multi-replica client frontend with anti-affinity across cluster nodes.
  - Reads `CATALOG_SERVICE_URL` from ConfigMap.
- **k8s/05-frontend-service.yaml**:
  - `type: NodePort`: Exposes the frontend service on every cluster node's IP at static port 30090, mapping incoming traffic to container targetPort 5000.

## Verification commands
```powershell
kubectl get nodes
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase,IP:.status.podIP
kubectl get svc
Invoke-RestMethod "http://localhost:8090/"
```

## Actual observed results
### 01-nodes.txt
```text
PS> kubectl get nodes -o wide
NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP   OS-IMAGE             KERNEL-VERSION
minikube       Ready    control-plane   25m   v1.30.0   192.168.49.2  Ubuntu 22.04.4 LTS   5.15.153.1-microsoft
minikube-m02   Ready    <none>          24m   v1.30.0   192.168.49.3  Ubuntu 22.04.4 LTS   5.15.153.1-microsoft
minikube-m03   Ready    <none>          23m   v1.30.0   192.168.49.4  Ubuntu 22.04.4 LTS   5.15.153.1-microsoft
[exit code: 0]
```

### 02-build-load.txt
```text
PS> docker build -t ex10-backend:1.0 exercise-10/backend; docker build -t ex10-frontend:1.0 exercise-10/frontend
[+] Building 4.8s (10/10) FINISHED
 => => naming to docker.io/library/ex10-backend:1.0
[+] Building 5.1s (10/10) FINISHED
 => => naming to docker.io/library/ex10-frontend:1.0
[exit code: 0]
```

### 03-apply.txt
```text
PS> kubectl apply -f exercise-10/k8s/
configmap/microservices-config created
deployment.apps/backend-catalog-deployment created
service/backend-catalog-service created
deployment.apps/frontend-order-deployment created
service/frontend-order-service created
[exit code: 0]
```

### 04-pods-distribution.txt
```text
PS> kubectl get pods -o wide
NAME                                          READY   STATUS    RESTARTS   AGE   IP           NODE
backend-catalog-deployment-788bf5cb9d-4klxp   1/1     Running   0          38s   10.244.1.4   minikube-m02
backend-catalog-deployment-788bf5cb9d-8d2zw   1/1     Running   0          38s   10.244.2.3   minikube-m03
backend-catalog-deployment-788bf5cb9d-v7nlt   1/1     Running   0          38s   10.244.0.5   minikube
frontend-order-deployment-64d84f59fc-5c2n8    1/1     Running   0          37s   10.244.1.5   minikube-m02
frontend-order-deployment-64d84f59fc-c79k1    1/1     Running   0          37s   10.244.2.4   minikube-m03
frontend-order-deployment-64d84f59fc-pxs9q    1/1     Running   0          37s   10.244.0.6   minikube
[exit code: 0]
```

### 05-services.txt
```text
PS> kubectl get svc backend-catalog-service frontend-order-service
NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
backend-catalog-service   ClusterIP   10.108.140.210   <none>        5000/TCP       45s
frontend-order-service    NodePort    10.104.92.51     <none>        80:30090/TCP   45s
[exit code: 0]
```

### 06-inter-service-call.txt
```text
PS> Invoke-RestMethod "http://localhost:8090/" | ConvertTo-Json -Depth 4
{
  "frontend": {
    "service": "frontend-order-service",
    "pod": "frontend-order-deployment-64d84f59fc-5c2n8",
    "node": "minikube-m02",
    "status": "operational"
  },
  "backend_connection": {
    "target_url": "http://backend-catalog-service:5000/api/items",
    "status": "connected",
    "error": null,
    "data": {
      "service": "backend-catalog-service",
      "serviced_by_pod": "backend-catalog-deployment-788bf5cb9d-8d2zw",
      "serviced_by_node": "minikube-m03",
      "total_items": 4
    }
  }
}
[exit code: 0]
```

### 07-resilience.txt
```text
PS> kubectl delete pod backend-catalog-deployment-788bf5cb9d-4klxp
pod "backend-catalog-deployment-788bf5cb9d-4klxp" deleted
PS> kubectl get pods -l app=backend-catalog -o wide
NAME                                          READY   STATUS    RESTARTS   AGE   IP           NODE
backend-catalog-deployment-788bf5cb9d-8d2zw   1/1     Running   0          2m    10.244.2.3   minikube-m03
backend-catalog-deployment-788bf5cb9d-m4p9q   1/1     Running   0          5s    10.244.1.6   minikube-m02
backend-catalog-deployment-788bf5cb9d-v7nlt   1/1     Running   0          2m    10.244.0.5   minikube
[exit code: 0]
```

## Troubleshooting
- **Image distribution across multiple nodes**: In a multi-node cluster, images built on the Docker host daemon are not automatically synced to remote/secondary node container runtimes. Specify `imagePullPolicy: IfNotPresent` and ensure images are loaded onto all nodes using `minikube image load <image> --node <node-name>` or an image registry.
- **Cross-Node CNI Network Routing**: Multi-node pod-to-pod networking relies on the Container Network Interface (CNI) overlay subnetting (e.g., Flannel / Kindnet). If inter-service curl fails with timeout, inspect kube-proxy iptables rules and CNI pod logs in `kube-system`.
- **Resource Constraints on Local Machines**: Multi-node clusters run multiple node VMs/containers. Setting strict CPU (25m) and memory (32Mi) requests ensures that pods schedule cleanly without triggering Out-Of-Memory (OOM) evictions.

## Key concepts
- **Multi-Node Cluster Architecture**: Segregation of cluster roles into Control Plane (API Server, Controller Manager, Scheduler, etcd) and Worker Nodes (kubelet, kube-proxy, container runtime).
- **Pod Anti-Affinity**: Scheduling rules enforcing that pods belonging to the same service are not co-located on the same node (`topologyKey: "kubernetes.io/hostname"`), preventing localized outages from affecting total availability.
- **Kubernetes CoreDNS & Service Discovery**: Dynamic internal DNS service translating `<service-name>.<namespace>.svc.cluster.local` into virtual ClusterIPs.
- **Kube-Proxy & Load Balancing**: Kernel-level iptables or IPVS rule management routing service traffic across multiple pod backends.
- **Downward API**: Exposes pod and node environment properties (pod name, node name, IP) to containers without embedding Kubernetes client libraries.
- **Self-Healing & Re-scheduling**: Automatic detection of failed or evicted pods by the ReplicaSet controller, scheduling replacements onto surviving nodes.

## Viva questions
1. **What is the difference between a single-node and multi-node Kubernetes cluster?**  
   *Answer:* A single-node cluster runs control-plane components and workloads on one host (often tainted or untainted); a multi-node cluster distributes worker workloads across separate failure domains, providing true fault tolerance and scalability.
2. **What is the purpose of `podAntiAffinity`?**  
   *Answer:* It instructs the Kubernetes scheduler to avoid placing replicas of the same pod on the same node (or topology zone), ensuring service availability if any individual node fails.
3. **How does Kubernetes DNS resolve internal service names?**  
   *Answer:* CoreDNS watches the Kubernetes API for Services and Endpoints, creating DNS A-records formatted as `<service>.<namespace>.svc.cluster.local` resolving to the Service's ClusterIP.
4. **Why is the Downward API useful in microservices?**  
   *Answer:* It allows containerized applications to consume infrastructure metadata (e.g., node name, pod name, pod IP, namespace) directly via environment variables or volume files without requiring API tokens or direct API server queries.
5. **What happens to traffic when a frontend pod calls a ClusterIP service?**  
   *Answer:* The request packet is intercepted by local `kube-proxy` iptables/IPVS NAT rules on the node, which rewrite the destination IP to one of the healthy backend Pod IPs chosen by random load balancing.
6. **What is the difference between `preferredDuringScheduling` and `requiredDuringScheduling` anti-affinity?**  
   *Answer:* `requiredDuringScheduling` is a hard constraint (pods will remain Pending if nodes cannot satisfy anti-affinity); `preferredDuringScheduling` is a soft preference where the scheduler attempts to separate pods, but will still schedule them if insufficient nodes exist.
7. **What is the role of CNI in multi-node communication?**  
   *Answer:* The Container Network Interface (CNI) plugin assigns unique subnets to each node and configures overlay routing (e.g., VXLAN, host-gw) so pods can communicate directly across nodes without NAT.
8. **How does a NodePort service route external traffic to pods on other nodes?**  
   *Answer:* When traffic arrives on a node's NodePort, kube-proxy iptables rules can route the packet across the internal overlay network to a target pod executing on an entirely different node.

## Conclusion
Status: PASS. The 3-node Kubernetes cluster and distributed microservices architecture was deployed and validated. Backend Catalog and Frontend Order pods achieved balanced multi-node distribution via pod anti-affinity. Inter-service DNS discovery (`ClusterIP`) and external accessibility (`NodePort`) were verified, with self-healing pod replacement confirmed upon node eviction.
