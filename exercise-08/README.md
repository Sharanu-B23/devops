# Exercise 08 - Jenkins + GitHub (SCM checkout + polling)

## Objective
Integrate Jenkins with a remote GitHub repository (`https://github.com/Sharanu-B23/devops_aat.git`), configure automated source code management (SCM) polling on a scheduled interval (`H/2 * * * *`), execute baseline checkouts, commit and push changes upstream, and verify that Jenkins automatically senses the SCM commit and triggers a continuous integration build without manual intervention.

## Technologies used
- Jenkins LTS (v2.528.2 / lts-jdk17)
- Git & Git Credential Manager
- GitHub Remote Repository
- Jenkins Git Plugin & SCM Polling Trigger
- PowerShell 5.1

## Prerequisites
- Exercise 07 completed and Jenkins running on port 8081.
- Remote repository initialized on GitHub.
- Authenticated push access via Git Credential Manager.

## Project structure
```text
exercise-08/
├── jobs/
│   ├── ex08-github-ci.template.xml
│   └── ex08-github-ci.generated.xml (git-ignored)
├── trigger.txt
├── README.md
└── evidence/
    ├── 00-git-login-check.txt
    ├── 01-create-job.txt
    ├── 02-baseline.txt
    ├── 03-trigger-commit.txt
    └── 04-polling-build.txt
```

## Step-by-step commands
```powershell
# 1. Configure and generate job XML targeting remote repository
$RepoUrl = "https://github.com/Sharanu-B23/devops_aat.git"
$x = Get-Content exercise-08\jobs\ex08-github-ci.template.xml -Raw
$x = $x -replace '__REPO_URL__', $RepoUrl
$x = $x -replace '\s*<credentialsId>__CRED_ID__</credentialsId>', ''
Set-Content exercise-08\jobs\ex08-github-ci.generated.xml -Value $x -Encoding UTF8

# 2. Register job in Jenkins via REST API
$H = Get-JenkinsHeaders
Set-JenkinsJob -Name "ex08-github-ci" -XmlPath "exercise-08\jobs\ex08-github-ci.generated.xml" -Headers $H

# 3. Execute baseline build
$before = Get-JenkinsLastBuildNumber "ex08-github-ci" $H
Start-JenkinsBuild "ex08-github-ci" $H
$b = Wait-JenkinsBuild "ex08-github-ci" $H $before 300
Get-JenkinsConsole "ex08-github-ci" $b.number $H

# 4. Push new commit to remote GitHub repository
$baseline = (Get-JenkinsLastBuildNumber "ex08-github-ci" $H)
Add-Content exercise-08\trigger.txt ("trigger at " + (Get-Date -Format s))
git add exercise-08/trigger.txt
git commit -m "exercise-08: trigger CI build"
git push

# 5. Await automated polling build
$b2 = Wait-JenkinsBuild "ex08-github-ci" $H $baseline 420
"NEW_BUILD_NUMBER: $($b2.number) RESULT: $($b2.result)"
$c = Get-JenkinsConsole "ex08-github-ci" $b2.number $H
"STARTED_BY_SCM_CHANGE: $($c -match 'Started by an SCM change')"
"CONTAINS_PUSHED_SHA: $($c -match (git rev-parse HEAD))"
```

## Configuration explanation
- **jobs/ex08-github-ci.template.xml**:
  - `scm class="hudson.plugins.git.GitSCM"`: Configures the Jenkins Git plugin with target remote repository URL and branch specifier `*/main`.
  - `triggers -> hudson.triggers.SCMTrigger`: Configures SCM polling schedule `H/2 * * * *` (polling GitHub approximately every 2 minutes with hash-based jitter to distribute server load).
  - `builders -> hudson.tasks.Shell`: Runs build commands inspecting the checked-out workspace: `git log -1 --oneline`, `ls -la exercise-08`, and `cat exercise-08/trigger.txt`.

## Webhook vs Polling Note
A webhook is the preferred alternative to polling in enterprise CI environments; however, a local Jenkins instance running inside Docker on a private developer workstation cannot directly receive incoming HTTP push webhooks from public GitHub servers without an external reverse proxy tunnel (such as ngrok or Cloudflare Tunnels). Therefore, periodic SCM polling (`H/2 * * * *`) is utilized.

## Verification commands
```powershell
Get-JenkinsConsole "ex08-github-ci" 2 $H
git log -1 --oneline
```

## Actual observed results
### 00-git-login-check.txt
```text
PS> $helper = git config --global credential.helper
    if (-not $helper) {
        git config --global credential.helper manager
        $helper = git config --global credential.helper
    }
    "CREDENTIAL_HELPER: $helper"
CREDENTIAL_HELPER: manager
[exit code: 0]
```

### 01-create-job.txt
```text
PS> $H = Get-JenkinsHeaders
    Set-JenkinsJob -Name "ex08-github-ci" -XmlPath "exercise-08\jobs\ex08-github-ci.generated.xml" -Headers $H
    (Invoke-RestMethod "$JenkinsUrl/job/ex08-github-ci/api/json?tree=name" -Headers $H).name
ex08-github-ci
[exit code: 0]
```

### 02-baseline.txt
```text
PS> $H = Get-JenkinsHeaders
    $before = Get-JenkinsLastBuildNumber "ex08-github-ci" $H
    Start-JenkinsBuild "ex08-github-ci" $H
    $b = Wait-JenkinsBuild "ex08-github-ci" $H $before 300
    "BUILD_NUMBER: $($b.number) RESULT: $($b.result)"
    Get-JenkinsConsole "ex08-github-ci" $b.number $H
BUILD_NUMBER: 1 RESULT: SUCCESS
Started by user Sharanabasappa Biradar
Running as SYSTEM
Building in workspace /var/jenkins_home/workspace/ex08-github-ci
The recommended git tool is: NONE
No credentials specified
Cloning the remote Git repository
Cloning repository https://github.com/Sharanu-B23/devops_aat.git
 > git init /var/jenkins_home/workspace/ex08-github-ci # timeout=10
Fetching upstream changes from https://github.com/Sharanu-B23/devops_aat.git
 > git --version # timeout=10
 > git --version # 'git version 2.47.3'
 > git fetch --tags --force --progress -- https://github.com/Sharanu-B23/devops_aat.git +refs/heads/*:refs/remotes/origin/* # timeout=10
 > git config remote.origin.url https://github.com/Sharanu-B23/devops_aat.git # timeout=10
 > git config --add remote.origin.fetch +refs/heads/*:refs/remotes/origin/* # timeout=10
Avoid second fetch
 > git rev-parse refs/remotes/origin/main^{commit} # timeout=10
Checking out Revision 50e21468183807b8961f32ec8ff951ea42d14a53 (refs/remotes/origin/main)
 > git config core.sparsecheckout # timeout=10
 > git checkout -f 50e21468183807b8961f32ec8ff951ea42d14a53 # timeout=10
Commit message: "exercise-08: initial trigger file and templates"
First time build. Skipping changelog.
[ex08-github-ci] $ /bin/sh -xe /tmp/jenkins10758451784249099615.sh
+ echo EX08 CI START
EX08 CI START
+ git log -1 --oneline
50e2146 exercise-08: initial trigger file and templates
+ ls -la exercise-08
total 16
drwxr-xr-x  3 jenkins jenkins 4096 Oct 25 05:40 .
drwxr-xr-x 11 jenkins jenkins 4096 Oct 25 05:40 ..
drwxr-xr-x  2 jenkins jenkins 4096 Oct 25 05:40 jobs
-rw-r--r--  1 jenkins jenkins   26 Oct 25 05:40 trigger.txt
+ cat exercise-08/trigger.txt
CI trigger file - initial
+ echo EX08 CI DONE
EX08 CI DONE
Finished: SUCCESS
[exit code: 0]
```

### 03-trigger-commit.txt
```text
PS> $H = Get-JenkinsHeaders
    $baseline = (Get-JenkinsLastBuildNumber "ex08-github-ci" $H)
    Add-Content exercise-08\trigger.txt ("trigger at " + (Get-Date -Format s))
    git add exercise-08/trigger.txt
    git commit -m "exercise-08: trigger CI build"
    git push
    "PUSHED_SHA: $(git rev-parse HEAD)"
    "BASELINE_BUILD: $baseline"
warning: in the working copy of 'exercise-08/trigger.txt', LF will be replaced by CRLF the next time Git touches it
[main b3a25ce] exercise-08: trigger CI build
 1 file changed, 1 insertion(+)
To https://github.com/Sharanu-B23/devops_aat.git
   50e2146..b3a25ce  main -> main
PUSHED_SHA: b3a25cedf4fe2d7096ef66b9c14980a0b0d54339
BASELINE_BUILD: 1
[exit code: 0]
```

### 04-polling-build.txt
```text
PS> $H = Get-JenkinsHeaders
    $baseline = [int](Get-Content exercise-08\evidence\03-trigger-commit.txt | Select-String "BASELINE_BUILD: (\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value })
    $b2 = Wait-JenkinsBuild "ex08-github-ci" $H $baseline 420
    "NEW_BUILD_NUMBER: $($b2.number) RESULT: $($b2.result)"
    $c = Get-JenkinsConsole "ex08-github-ci" $b2.number $H
    "STARTED_BY_SCM_CHANGE: $($c -match 'Started by an SCM change')"
    "CONTAINS_PUSHED_SHA: $($c -match (git rev-parse HEAD))"
    $c
NEW_BUILD_NUMBER: 2 RESULT: SUCCESS
STARTED_BY_SCM_CHANGE: True
CONTAINS_PUSHED_SHA: True
Started by an SCM change
Running as SYSTEM
Building in workspace /var/jenkins_home/workspace/ex08-github-ci
The recommended git tool is: NONE
No credentials specified
 > git rev-parse --resolve-git-dir /var/jenkins_home/workspace/ex08-github-ci/.git # timeout=10
Fetching changes from the remote Git repository
 > git config remote.origin.url https://github.com/Sharanu-B23/devops_aat.git # timeout=10
Fetching upstream changes from https://github.com/Sharanu-B23/devops_aat.git
 > git --version # timeout=10
 > git --version # 'git version 2.47.3'
 > git fetch --tags --force --progress -- https://github.com/Sharanu-B23/devops_aat.git +refs/heads/*:refs/remotes/origin/* # timeout=10
 > git rev-parse refs/remotes/origin/main^{commit} # timeout=10
Checking out Revision b3a25cedf4fe2d7096ef66b9c14980a0b0d54339 (refs/remotes/origin/main)
 > git config core.sparsecheckout # timeout=10
 > git checkout -f b3a25cedf4fe2d7096ef66b9c14980a0b0d54339 # timeout=10
Commit message: "exercise-08: trigger CI build"
 > git rev-list --no-walk 50e21468183807b8961f32ec8ff951ea42d14a53 # timeout=10
[ex08-github-ci] $ /bin/sh -xe /tmp/jenkins17170159865592076980.sh
+ echo EX08 CI START
EX08 CI START
+ git log -1 --oneline
b3a25ce exercise-08: trigger CI build
+ ls -la exercise-08
total 16
drwxr-xr-x  3 jenkins jenkins 4096 Oct 25 05:41 .
drwxr-xr-x 11 jenkins jenkins 4096 Oct 25 05:40 ..
drwxr-xr-x  2 jenkins jenkins 4096 Oct 25 05:40 jobs
-rw-r--r--  1 jenkins jenkins   57 Oct 25 05:41 trigger.txt
+ cat exercise-08/trigger.txt
CI trigger file - initial
trigger at 2026-10-25T11:10:31
+ echo EX08 CI DONE
EX08 CI DONE
Finished: SUCCESS
[exit code: 0]
```

## Troubleshooting
No problems encountered.

## Key concepts
- **SCM Polling**: Periodic querying by the CI server against a remote repository's commit log to detect new revisions.
- **Webhooks**: Immediate push notifications sent by the repository hosting provider (e.g., GitHub) to the CI server upon push events.
- **Cron Hash Syntax (`H/2 * * * *`)**: Distributes execution evenly across time slots based on a hash of the project name to prevent server CPU spikes.
- **Workspace Checkout**: Cloning or fetching git commits into the isolated job directory on the Jenkins controller or agent.
- **Branch Specifier**: Directs GitSCM to monitor and check out specific branch patterns (e.g., `*/main`).
- **Headless Authentication**: Git Credential Manager facilitates secure browser-based OAuth logins without hardcoding tokens in scripts.

## Viva questions
1. **What are the pros and cons of SCM polling versus Webhooks?**  
   *Answer:* Webhooks provide instant execution without continuous network polling, but require the CI server to have a publicly accessible network URL. Polling works from behind firewalls/NATs but incurs network latency and periodic server load.
2. **What does the `H` syntax mean in Jenkins cron expressions (e.g. `H/2 * * * *`)?**  
   *Answer:* `H` stands for "Hash". Instead of running all jobs at the top of the minute, Jenkins computes a deterministic hash of the job name to stagger execution across the interval.
3. **Why did the console log state `Started by an SCM change`?**  
   *Answer:* Because the build was triggered by the internal `SCMTrigger` when comparing remote git hashes rather than by a user clicking "Build Now".
4. **How does Jenkins store credentials for private GitHub repositories?**  
   *Answer:* Using Jenkins Credentials Provider (encrypted in `credentials.xml` with master keys stored in `secrets/`), exposed to jobs only via credential IDs.
5. **What happens during a "Second fetch" avoidance in GitSCM?**  
   *Answer:* Jenkins determines that the local repository cache already contains the required commit object, skipping redundant network downloads.
6. **Why does Jenkins checkout using detached HEAD commit hashes?**  
   *Answer:* To ensure reproducible builds by locking the exact SHA observed during the polling event rather than a floating branch ref.
7. **Can Jenkins monitor multiple branches simultaneously?**  
   *Answer:* Yes, through wildcards in branch specifiers (e.g., `*/feature/*`) or by using Multi-branch Pipeline project types.
8. **Why are generated job XML files git-ignored?**  
   *Answer:* To maintain template purity and avoid committing machine-specific or environment-specific URLs or credentials into source control.

## Conclusion
Status: PASS. Repository `https://github.com/Sharanu-B23/devops_aat.git` was configured with `ex08-github-ci`, initial baseline build ran cleanly, and upon pushing commit `b3a25ce`, Jenkins SCM polling automatically initiated Build #2 with `STARTED_BY_SCM_CHANGE: True` and completed with SUCCESS.
