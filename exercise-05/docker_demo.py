import sys

import docker

NAME = "ex05-temp-demo"
IMAGE = "alpine:3.20"

client = docker.from_env()
print("DOCKER SERVER VERSION:", client.version()["Version"])

print("EXISTING CONTAINERS:")
for c in client.containers.list(all=True):
    print("  ", c.short_id, c.name, c.status)

if any(c.name == NAME for c in client.containers.list(all=True)):
    print("ERROR: a container named", NAME, "already exists; refusing to touch it.")
    sys.exit(2)

client.images.pull(IMAGE)
container = client.containers.run(
    IMAGE,
    ["sh", "-c", "echo log-line-from-demo; sleep 60"],
    detach=True,
    name=NAME,
    labels={"created-by": "ex05-demo"},
)
try:
    container.reload()
    print("STARTED:", container.name, "status =", container.status)
    result = container.exec_run(["sh", "-c", "echo hello from exec"])
    print("EXEC EXIT CODE:", result.exit_code)
    print("EXEC OUTPUT:", result.output.decode().strip())
    print("LOGS:", container.logs().decode().strip())
finally:
    container.stop(timeout=1)
    container.remove(force=True)
    print("REMOVED:", NAME)
