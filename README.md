# telegraf-controller-fleet-demo

This is a quick no cost demo that you can easily adapt for long term use in your environment.

Central to the demo are open source [Telegraf](https://github.com/influxdata/telegraf) agents for collecting metrics.  The [Telegraf](https://github.com/influxdata/telegraf) project provides 400+ community-tested plugins  for collecting metrics from infrastructure, applications, and devices.  InfluxData reports millions of [Telegraf](https://github.com/influxdata/telegraf) agent deployments enabling connecting any data source to any destination.

This demo introduces you to using the [InfluxDB Cloud Serverless](https://www.influxdata.com/products/influxdb-cloud/serverless/) free plan. This is an always free service that easily enables collection of metrics from unlimited agents providing off-instance storage of metrics, and includes customizable dashboarding capabilities. The free plan supports storage of 30 days of data.

The demo also uses the free tier of the commercial [Telegraf Controller](https://www.influxdata.com/lp/telegraf-controller/).  Though Telegraf Controller is not strictly required, it is included to highlight how it can both ease in configuring your Telegraf agents, and ease in management of your agent fleet as it grows over time.

Last, for sample infrastructure any Linux host will do. In case a user either may not have a Linux host, or may just want a lab environment I use an instance of Oracle OCI's "Always Free" Arm-based Ampere A1 cores and 12 GB RAM. I built this demo because it addressed a need I had to proactively monitor to prevent a host from becoming unresponsive due to memory pressure. 

This is part of a continuing series of projects that I am sharing to help others. This falls into the `always-free` category to help remove cost and licensing barriers for both individuals and organizations to build out their running of proof of concepts.  And part of my continuing series of `hands-on` `demos` and `workshops` because I know in learning and being confident as a technologist, there is no substitute for actual building and doing. 

CAVEATS:
> **Unofficial community demo. Not affiliated with, endorsed by, or supported by InfluxData.**
> "InfluxDB", "Telegraf" and "Telegraf Controller" are trademarks of their owners.
> Telegraf Controller is proprietary software governed by InfluxData's EULA and is
> **not included** in this repository; you must read and accept that EULA yourself.
>
> **Security warnings - read before running anything:**
> - The agent container mounts `/var/run/docker.sock`. This is **root-equivalent access to the host**; `:ro` does not restrict the Docker API.
> - The agent also mounts the whole host filesystem (`/:/hostfs:ro`) and uses `--network host`.
> - The agent executes whatever its remote configuration says (e.g. `inputs.exec`). Anyone who can edit the Controller config can run commands on the host.
> - The Controller listens on loopback only. Reach it through an SSH tunnel; never expose ports 8888/8000.
> - Scripts and configs are drafts, tested on one host only. Use a disposable VM first.

## What and why

This is a small, reproducible demo of monitoring one low-resource Linux host with Telegraf agents whose configuration is managed centrally by Telegraf Controller, with metrics stored in the InfluxDB Cloud Serverless free plan.

Target host in the original use case: an Oracle Cloud (OCI) Ampere A1 instance (aarch64, 2 vCPU, 12 GB RAM) running a Docker workload container. The goal is to see memory pressure, swap, disk fill and container memory early, at very low cost in RAM and CPU.

Telegraf Controller is NOT included in this repo. It is a separate product distributed by InfluxData under InfluxData's EULA. This repo only contains scripts that run the official image. You must read and accept the EULA yourself.

## Architecture

```
  Your laptop                         Linux host (YOUR_HOST)
  -----------                         -------------------------------------
  browser  --ssh -L 8888-->  127.0.0.1:8888  telegraf-controller (docker)
                                      127.0.0.1:8000        ^   ^
                                           ^  heartbeat     |   | config
                                           |                |   |
                                      telegraf-agent (docker, --network host)
                                        reads: /hostfs (ro), docker.sock
                                        runs:  psi-lineprotocol.sh
                                           |
                                           | HTTPS (outputs.influxdb_v2)
                                           v
                              InfluxDB Cloud Serverless (free plan)
                              us-east-1, org YOUR_ORG,
                              bucket YOUR_BUCKET (30-day retention)
```

The Controller listens on 127.0.0.1 only. You reach its UI through an SSH
tunnel. The agent runs with host networking so it can reach the Controller on
127.0.0.1 and report host-level network stats.

## Prerequisites

- Linux host (x86_64 or aarch64) with Docker Engine running as a root daemon. Snap Docker and rootless Docker are not supported. `openssl` is needed by `make-env.sh` and `run-controller.sh`. The `docker compose` plugin is NOT required.
- An InfluxDB Cloud Serverless free account, with a bucket and two API tokens (write-only and read-only). See the companion docs for permissions.
- SSH access to the host.
- Willingness to read and accept the Telegraf Controller EULA.

## Quick start

Use either the scripts below or `compose.yaml`, not both on one host: they use
the same container names and ports.

1. Copy the repo to the host (for example to `~/telegraf-controller-fleet-demo`).
2. Check the host: `./scripts/preflight.sh`. It is read-only. It fails on snap
   or rootless Docker, an unreachable Docker daemon, an unsupported CPU, or a
   missing `/var/run/docker.sock`, and warns about the docker group, PSI,
   openssl and busy ports 8888 and 8000.
3. Run the Controller. Read the EULA and accept it yourself:
   `ACCEPT_EULA=accept ./scripts/run-controller.sh`
   (the script refuses to start with any other value and prints the EULA URL).
4. From your laptop open a tunnel: `ssh -N -L 8888:127.0.0.1:8888 <host>`
   and browse to http://localhost:8888 . Create the owner account in the
   browser. Do not put owner credentials in environment variables.
5. In the Controller UI: create an API token using the "Telegraf Agent"
   preset (Configurations read, Heartbeat write). Create an agent entry and a
   configuration; paste the contents of `telegraf/host-agent.toml`.
6. On the host create `.env` (mode 600). Either copy `.env.example` and edit
   it, or run `ssh -t <host> "~/telegraf-controller-fleet-demo/scripts/make-env.sh"`.
   `make-env.sh` asks for the two tokens with hidden input, so secrets never
   appear in shell history, then asks for the InfluxDB URL, org and bucket, the
   Controller config ID and agent ID, the host name tag and the container name
   glob. It generates `SESSION_SECRET` and detects `DOCKER_GID` itself, and
   leaves `ACCEPT_EULA` empty for you to set.
7. Start the agent: `./scripts/run-telegraf.sh`
8. Verify: `./scripts/check-health.sh`, then query the bucket in the
   InfluxDB Cloud UI.
9. Before committing anything: `./scripts/redaction-check.sh`.

A `compose.yaml` is provided for people with the compose plugin. It is
UNTESTED. It reads the same `.env`; set `ACCEPT_EULA=accept` there first.

## Security note on the Docker socket

The agent mounts `/var/run/docker.sock` for the docker input. Mounting it
`:ro` does NOT restrict the Docker API; any process with the socket can start
privileged containers. Treat this as root-equivalent access to the host. The
agent also mounts the host root filesystem read-only at `/hostfs`. If this is
unacceptable, remove the docker input and the socket mount.

## Free plan limits and write-cap arithmetic

See `docs/free-tier-limits.md`. Summary: writes are capped at 5 MB per 5
minutes. Measured: one 30 s cycle is 40 points and 9,639 bytes of line
protocol, so about 96 kB per 5 minutes, about 1.9 percent of the cap. This
depends on series count.

## Measured resource use

Measured 2026-10-30 on an Ampere A1 host (aarch64, 2 vCPU, 11.9 GB RAM):

| Item | Measured |
|---|---|
| telegraf-controller memory | 184.8 to 201.4 MiB (of a 512 MiB limit) |
| telegraf-controller CPU | 0.05 to 0.06 percent |
| telegraf-agent memory  | about 35 MiB of anonymous (heap) memory, plus about 300 MB of file cache for the Telegraf binary that counts against the container limit. A 256 MiB limit caused OOM kills at startup; use 512 MiB or more. |
| telegraf-agent CPU | 0.06 percent |
| Host memory available | about 7.3 GB of 11.9 GB, swap 0 |
| Image size on disk | controller 332 MB, telegraf 758 MB |
| Restarts | 0, controller healthy |

## Pitfalls we hit

1. `perdevice` and `total` were removed from `[[inputs.docker]]`. Telegraf
   1.40.2 refuses a config that sets them (error: configuration specified
   the fields ["perdevice" "total"], but they were not used).
2. `HOST_PROC` must be `/hostfs/proc`, not `/proc`. With `/proc` the disk
   input produced no `disk` points (it only saw the container's own mounts).
   Set `HOST_ETC=/hostfs/etc`, `HOST_PROC=/hostfs/proc`,
   `HOST_SYS=/hostfs/sys` and `HOST_MOUNT_PREFIX=/hostfs`, with the host root
   mounted read-only at `/hostfs`.
3. Set `[agent] hostname` explicitly. Otherwise the `host` tag is the
   container ID.
4. Windows cmd.exe quoting: in `ssh host 'VAR=x cmd'` single quotes are not
   quote characters in cmd.exe, so the remote shell gets one mangled word
   ("No such file or directory"). Use double quotes and `env`:
   `ssh host "env VAR=x cmd"` (works in cmd.exe and PowerShell).
5. The `:ro` flag on the Docker socket mount does not restrict the Docker
   API. It is root-equivalent access (see the security note above).
6. Harmless noise: `id: cannot find name for group ID 132` in agent logs (the
   docker group id inside the container), and an `inputs.exec` command
   DeprecationWarning even when the array syntax is already used.

7. Controller Agents page showed Status "Undefined" and "No configurations"
   although heartbeats arrived. Cause: the `[[outputs.heartbeat]]` block had
   no `include` setting, so only the hostname was sent. Fix (applied
   2026-11-01, Status then showed OK): in the Controller, edit the
   configuration, set `include = ["hostname", "statistics", "configs", "logs",
   "status"]` and add `[outputs.heartbeat.status]` with `default = "ok"` (see
   `telegraf/host-agent.toml`), save, wait about 2 minutes (the agent polls its
   config every minute and heartbeats every minute; restart the agent
   container if the status does not change), reload the Agents page.
   `default = "ok"` reports OK whenever the agent is alive; add CEL `warn` and
   `fail` expressions for real health rules.
8. The Controller Agents page shows the OS hostname (`host1` on our host,
   because the agent uses host networking), not the `host` tag `YOUR_HOST`
   set in the config. Both are expected.

## Known unknowns

- Organization value for Serverless: whether `organization` should be the
  org name or the org ID for this account is unverified.
- PSI (pressure stall information) is collected through `inputs.exec` running
  `scripts/psi-lineprotocol.sh`; no native Telegraf input is assumed.
- EULA: terms are not summarized here. Read them at
  https://docs.influxdata.com/telegraf/controller/reference/eula/
- Inactivity policy: whether the free plan deletes or suspends idle
  accounts, and after how long, is unverified.
- The `instance_id = "&{agent_id}"` templating and how the agent
  authenticates its config fetch against the Controller are unverified.

## Docs

- Get started: https://docs.influxdata.com/telegraf/controller/get-started/
- Docker install: https://docs.influxdata.com/telegraf/controller/install/docker/
- Create agents: https://docs.influxdata.com/telegraf/controller/agents/create/
- Use configs: https://docs.influxdata.com/telegraf/controller/configs/use/
- Docker Hub image: https://hub.docker.com/r/influxdata/telegraf-controller

## Contents

- `scripts/` preflight (read-only host check), run-controller, run-telegraf,
  check-health (shows whichever containers are running), make-env (hidden-input
  creation of `.env`; run with `ssh -t`), psi-lineprotocol, redaction-check
- `telegraf/host-agent.toml` config to paste into the Controller
- `compose.yaml` UNTESTED compose equivalent (reads the same `.env`)
- `docs/critical-metrics.md`, `docs/free-tier-limits.md`

## License

MIT for the files in this repo (see LICENSE). Telegraf Controller is not
included and is governed by InfluxData's EULA. Accept the EULA yourself; do
not redistribute the Controller binary or image. This project is unofficial
and is not endorsed by InfluxData.
