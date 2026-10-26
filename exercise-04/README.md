# Exercise 04 - Docker Networking (Flask + MySQL + Redis with Compose)

## Objective
Orchestrate a multi-container microservice application using Docker Compose comprising a Flask web API, a MySQL 8.0 relational database with persistent storage, and a Redis 7 in-memory cache on an isolated user-defined bridge network. Validate inter-container DNS service discovery, startup dependencies with healthchecks, atomic hit/visit counters, and volume persistence across container teardown.

## Technologies used
- Docker Compose (v5.6.1)
- Docker Engine (29.9.2)
- Python (3.12-slim base, Flask 3.0.3, Gunicorn 22.0.0, PyMySQL 1.1.1, Redis-py 5.0.8)
- MySQL (8.0)
- Redis (7-alpine)

## Prerequisites
- Docker Desktop with Linux containers running.
- Port 5004 free on the Windows host.

## Project structure
```text
exercise-04/
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── .env (git-ignored)
├── .env.example
├── docker-compose.yml
├── README.md
└── evidence/
    ├── 01-up.txt
    ├── 02-healthy.txt
    ├── 03-health-http.txt
    ├── 04-counters.txt
    ├── 05-network.txt
    └── 06-persistence.txt
```

## Step-by-step commands
```powershell
# 1. Start application stack with Compose in detached mode
docker compose -f exercise-04/docker-compose.yml up -d --build

# 2. Wait for healthchecks of all three containers
"mysql: $(Wait-Healthy ex04-mysql 150)"
"redis: $(Wait-Healthy ex04-redis 60)"
"web: $(Wait-Healthy ex04-web 120)"
docker compose -f exercise-04/docker-compose.yml ps

# 3. Query HTTP health endpoint
(Wait-Http "http://localhost:5004/health" 200 60).Content

# 4. Validate counter increments (MySQL rows and Redis hits)
$a = (Invoke-WebRequest http://localhost:5004/ -UseBasicParsing).Content | ConvertFrom-Json
$b = (Invoke-WebRequest http://localhost:5004/ -UseBasicParsing).Content | ConvertFrom-Json
"FIRST : mysql_rows=$($a.mysql_rows) redis_hits=$($a.redis_hits)"
"SECOND: mysql_rows=$($b.mysql_rows) redis_hits=$($b.redis_hits)"
"MYSQL_INCREMENTED: $($b.mysql_rows -eq $a.mysql_rows + 1)"
"REDIS_INCREMENTED: $($b.redis_hits -eq $a.redis_hits + 1)"

# 5. Verify inter-container DNS resolution and bridge network membership
docker exec ex04-web python -c "import socket; print('mysql ->', socket.gethostbyname('mysql')); print('redis ->', socket.gethostbyname('redis'))"
docker network inspect ex04-networking_appnet --format '{{range .Containers}}{{.Name}} {{end}}'

# 6. Verify named volume data persistence across container recreation
$before = ((Invoke-WebRequest http://localhost:5004/ -UseBasicParsing).Content | ConvertFrom-Json).mysql_rows
docker compose -f exercise-04/docker-compose.yml down
docker compose -f exercise-04/docker-compose.yml up -d
"mysql: $(Wait-Healthy ex04-mysql 150)"
"web: $(Wait-Healthy ex04-web 120)"
$after = ((Wait-Http "http://localhost:5004/" 200 60).Content | ConvertFrom-Json).mysql_rows
"ROWS_BEFORE=$before ROWS_AFTER=$after PERSISTED=$($after -gt $before)"

# 7. Stack teardown (never use -v)
docker compose -f exercise-04/docker-compose.yml down
```

## Configuration explanation
- **docker-compose.yml**:
  - `name: ex04-networking`: Explicit project namespace preventing container name collisions.
  - `services.mysql`: Runs `mysql:8.0` with environment credentials loaded from `.env`, attaches volume `mysql_data:/var/lib/mysql`, and configures healthcheck `mysqladmin ping`.
  - `services.redis`: Runs lightweight `redis:7-alpine` with healthcheck `redis-cli ping`.
  - `services.web`: Builds `./app`, publishes host port `5004:5000`, injects host names `mysql` and `redis`, and specifies `depends_on` requiring both databases to be `service_healthy`.
  - `networks.appnet`: Defines an isolated custom bridge network enabling internal DNS resolution.
  - `volumes.mysql_data`: Defines a persistent named volume preserved across container lifecycles.
- **app/app.py**:
  - Connects to MySQL and creates table `visits` on initial boot.
  - Inserts visit records into MySQL and performs atomic `incr("hits")` operations against Redis.
  - Exposes `/health` verifying both ping connections.

## Verification commands
```powershell
docker compose -f exercise-04/docker-compose.yml ps
curl http://localhost:5004/health
curl http://localhost:5004/
```

## Actual observed results
### 01-up.txt
```text
PS> docker compose -f exercise-04/docker-compose.yml up -d --build
 Image redis:7-alpine Pulling 
 Image mysql:8.0 Pulling 
...
 Container ex04-mysql Healthy 
 Container ex04-web Starting 
 Container ex04-web Started 
[exit code: 0]
```

### 02-healthy.txt
```text
PS> "mysql: $(Wait-Healthy ex04-mysql 150)"
    "redis: $(Wait-Healthy ex04-redis 60)"
    "web: $(Wait-Healthy ex04-web 120)"
    docker compose -f exercise-04/docker-compose.yml ps
mysql: True
redis: True
web: True
NAME         IMAGE                 COMMAND                  SERVICE   CREATED              STATUS                        PORTS
ex04-mysql   mysql:8.0             "docker-entrypoint.s…"   mysql     About a minute ago   Up About a minute (healthy)   3306/tcp, 33060/tcp
ex04-redis   redis:7-alpine        "docker-entrypoint.s…"   redis     About a minute ago   Up About a minute (healthy)   6379/tcp
ex04-web     ex04-networking-web   "gunicorn --workers …"   web       About a minute ago   Up 21 seconds (healthy)       0.0.0.0:5004->5000/tcp, [::]:5004->5000/tcp
[exit code: 0]
```

### 03-health-http.txt
```text
PS> (Wait-Http "http://localhost:5004/health" 200 60).Content
{"mysql":"ok","redis":"ok"}

[exit code: 0]
```

### 04-counters.txt
```text
PS> $a = (Invoke-WebRequest http://localhost:5004/ -UseBasicParsing).Content | ConvertFrom-Json
    $b = (Invoke-WebRequest http://localhost:5004/ -UseBasicParsing).Content | ConvertFrom-Json
    "FIRST : mysql_rows=$($a.mysql_rows) redis_hits=$($a.redis_hits)"
    "SECOND: mysql_rows=$($b.mysql_rows) redis_hits=$($b.redis_hits)"
    "MYSQL_INCREMENTED: $($b.mysql_rows -eq $a.mysql_rows + 1)"
    "REDIS_INCREMENTED: $($b.redis_hits -eq $a.redis_hits + 1)"
FIRST : mysql_rows=1 redis_hits=1
SECOND: mysql_rows=2 redis_hits=2
MYSQL_INCREMENTED: True
REDIS_INCREMENTED: True
[exit code: 0]
```

### 05-network.txt
```text
PS> docker exec ex04-web python -c "import socket; print('mysql ->', socket.gethostbyname('mysql')); print('redis ->', socket.gethostbyname('redis'))"
    docker network inspect ex04-networking_appnet --format '{{range .Containers}}{{.Name}} {{end}}'
mysql -> 172.18.0.2
redis -> 172.18.0.3
ex04-redis ex04-web ex04-mysql 
[exit code: 0]
```

### 06-persistence.txt
```text
PS> $before = ((Invoke-WebRequest http://localhost:5004/ -UseBasicParsing).Content | ConvertFrom-Json).mysql_rows
    docker compose -f exercise-04/docker-compose.yml down
    docker compose -f exercise-04/docker-compose.yml up -d
    "mysql: $(Wait-Healthy ex04-mysql 150)"
    "web: $(Wait-Healthy ex04-web 120)"
    $after = ((Wait-Http "http://localhost:5004/" 200 60).Content | ConvertFrom-Json).mysql_rows
    "ROWS_BEFORE=$before ROWS_AFTER=$after PERSISTED=$($after -gt $before)"
 Container ex04-web Stopping 
 Container ex04-web Stopped 
 Container ex04-web Removing 
 Container ex04-web Removed 
 Container ex04-mysql Stopping 
 Container ex04-redis Stopping 
 Container ex04-redis Stopped 
 Container ex04-redis Removing 
 Container ex04-redis Removed 
 Container ex04-mysql Stopped 
 Container ex04-mysql Removing 
 Container ex04-mysql Removed 
 Network ex04-networking_appnet Removing 
 Network ex04-networking_appnet Removed 
 Network ex04-networking_appnet Creating 
 Network ex04-networking_appnet Creating 
 Network ex04-networking_appnet Created 
 Network ex04-networking_appnet Created 
 Container ex04-redis Creating 
 Container ex04-mysql Creating 
 Container ex04-mysql Created 
 Container ex04-redis Created 
 Container ex04-web Creating 
 Container ex04-web Created 
 Container ex04-mysql Starting 
 Container ex04-redis Starting 
 Container ex04-mysql Started 
 Container ex04-redis Started 
 Container ex04-mysql Waiting 
 Container ex04-redis Waiting 
 Container ex04-redis Healthy 
 Container ex04-mysql Healthy 
 Container ex04-web Starting 
 Container ex04-web Started 
mysql: True
web: True
ROWS_BEFORE=3 ROWS_AFTER=4 PERSISTED=True
[exit code: 0]
```

## Troubleshooting
No problems encountered.

## Key concepts
- **User-Defined Bridge Network**: Provides automatic internal DNS name resolution among containers without requiring manual IP address configuration.
- **Service Discovery**: Docker's embedded DNS server resolves container names and service identifiers to dynamic container IP addresses.
- **Service Healthchecks**: Active probes executing commands within containers to verify application readiness beyond simple process existence.
- **Depends_on with Condition**: Ensures dependent containers wait until prerequisite backing services are not just started, but fully operational (`service_healthy`).
- **Named Volume Persistence**: Persistent storage objects independent of container lifecycles that retain database records across container removals.
- **Port Publishing (5004:5000)**: Maps host port 5004 to container port 5000, allowing external host clients to reach the web service.

## Viva questions
1. **How does DNS resolution operate in a user-defined Docker bridge network?**  
   *Answer:* Docker runs an internal DNS server at `127.0.0.11` inside each container that resolves service names and container names to their assigned network IPs.
2. **What is the difference between `depends_on` and `depends_on` with `condition: service_healthy`?**  
   *Answer:* Plain `depends_on` only waits for container process startup, which can cause startup race conditions if the database is still initializing. `condition: service_healthy` delays starting dependent services until the healthcheck command succeeds.
3. **Why are database credentials kept in a `.env` file instead of `docker-compose.yml`?**  
   *Answer:* To prevent sensitive production credentials from being committed to version control repositories and to allow environment-specific configurations.
4. **What happens to data in a named volume when `docker compose down` is run?**  
   *Answer:* The containers and networks are deleted, but the named volume remains completely intact on the host storage unless the destructive `-v` flag is explicitly provided.
5. **Why use Redis for caching alongside a relational database like MySQL?**  
   *Answer:* Redis is an in-memory key-value datastore providing sub-millisecond read/write latencies and atomic counters, reducing load on the relational database.
6. **Why was port 5004 published instead of port 5000 directly?**  
   *Answer:* To avoid host port collisions with other local development web servers or containers running on default port 5000.
7. **How does a container healthcheck report failure?**  
   *Answer:* By returning a non-zero exit code (`0` = healthy, `1` = unhealthy, `2` = reserved).
8. **What is the effect of running `docker compose down -v`?**  
   *Answer:* It tears down containers, networks, and permanently removes all declared named volumes, causing irreversible data loss.

## Conclusion
Status: PASS. The multi-container Compose stack initialized with all three containers reporting healthy, internal DNS resolved `mysql` and `redis` cleanly, database row counts and cache hit counters incremented atomically, and data persisted across stack teardown and recreation.
