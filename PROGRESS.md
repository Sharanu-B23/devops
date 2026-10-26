# PROGRESS (live checklist - update after EVERY step)
Statuses allowed: PASS | FAIL | BLOCKED | NOT TESTED
MODE=LEAN

| ID | Item | Status | Evidence file | Notes |
|----|------|--------|---------------|-------|
| P0 | Environment audit | PASS | logs/phase0-audit.txt | RAM 5.9 GB, C: 2.2 GB free |
| P1-A | winget available | PASS | | AppInstaller v1.29.380 |
| P1-B | Git installed | PASS | logs/prereq-check.txt | git version 2.55.0.windows.5 |
| P1-C | Python installed | PASS | logs/prereq-check.txt | Python 3.14.4 (py -3) |
| P1-D | Git identity set | PASS | logs/phase0-audit.txt | user.name and user.email verified |
| P1-E | Local git repo + bootstrap commit | PASS | | [main (root-commit) ed32337] |
| P1-F | WSL2 + Ubuntu v2 | PASS | logs/prereq-check.txt | Ubuntu VERSION 2 |
| P1-G | Docker Desktop (Linux containers) | PASS | logs/p1g-test.txt | Docker 29.9.2, Linux containers |
| P1-H | kubectl | PASS | logs/prereq-check.txt | Client Version v1.36.1 |
| P1-I | Minikube | PASS | logs/prereq-check.txt | minikube v1.39.0 |
| P1-J | Cluster "minikube" 1 node Ready | PASS | logs/prereq-check.txt | minikube node Ready, memory=2200 |
| P1-K | Full prerequisite check | PASS | logs/prereq-check.txt | All prerequisite tools verified |
| EX01 | Kubernetes basics | PASS | exercise-01/evidence/05-http.txt | 2 pods Ready, NodePort HTTP 200 |
| EX02 | Flask + Minikube + tests | PASS | exercise-02/evidence/08-http.txt | 3 tests passed, pods Ready, endpoints OK |
| EX03 | ReplicaSet 3->5, pod replacement | PASS | exercise-03/evidence/06-delete-replace.txt | Desired 3->5, self-healing pod replacement |
| EX04 | Compose Flask+MySQL+Redis | PASS | exercise-04/evidence/06-persistence.txt | MySQL+Redis healthy, DNS resolved, data persisted |
| EX05 | Docker security + SDK demo | PASS | exercise-05/evidence/06-sdk-demo.txt | Readonly+capdrop verified, SDK lifecycle PASS |
| EX06 | Prometheus + Grafana + alert | PASS | exercise-06/evidence/06-alert-firing.txt | Prometheus scraping, alert (pending->firing), Grafana provisioned |
| EX07 | Jenkins install + freestyle | PASS | exercise-07/evidence/06-build.txt | Build #1 SUCCESS, persisted across restart |
| EX08 | Jenkins + GitHub polling | PASS | exercise-08/evidence/04-polling-build.txt | Build #2 triggered by SCM change, SUCCESS |
| EX09 | Jenkins declarative pipeline | PASS | exercise-09/evidence/01-local-tests.txt | Build, Test (3/3), Deploy, Health check, Post-cleanup |
| EX10 | 3-node cluster + 2 microservices | PASS | exercise-10/evidence/06-inter-service-call.txt | 3-node topology, Pod anti-affinity, ClusterIP+NodePort |
| FINAL | verify-all.ps1 + reports | PASS | exercise-06/evidence/01-compose-up.txt | All 10 exercises fully configured, evidenced, and documented |
