# Critical metrics

Thresholds below are STARTING POINTS for a 12 GB host, not tuned values. Tune
them after you have a week of baseline data. Alert delivery (email, chat,
pager) is NOT implemented: until it is, these thresholds are only visual
guides on dashboards or manual checks.

## Verified against a real run

Verified against a real run on 2026-10-30 (Telegraf 1.40.2, aarch64, 2 vCPU,
11.9 GB RAM): every measurement and field named below was seen in one
`telegraf --test` cycle of the shipped `telegraf/host-agent.toml`. Arrival of
the points in the Cloud bucket was not yet confirmed at that time.

## Host and container health

| Metric (measurement.field) | What it tells you | Warn | Critical |
|---|---|---|---|
| mem.available | RAM the kernel can hand out without swapping | < 1 GB | < 500 MB |
| mem.available_percent | Same, as a percentage | < 10 | < 5 |
| mem.used_percent | Share of RAM in use | > 85 | > 95 |
| swap.used | Swap in use; sustained use means memory shortage | > 500 MB | (tune) |
| swap.used_percent | Same, as a percentage | > 10 | (tune) |
| pressure.avg60 (resource=memory, kind=some) | Share of time some task stalled waiting for memory | > 10 | - |
| pressure.avg60 (resource=memory, kind=full) | Share of time all tasks stalled on memory | - | > 1 |
| pressure.avg60 (resource=io, kind=some) | Share of time some task stalled on IO | > 20 | (tune) |
| pressure.avg60 (resource=cpu, kind=some) | Share of time some task stalled waiting for CPU | > 20 | (tune) |
| disk.used_percent (path=/) | Root filesystem fill | > 85 | > 92 |
| disk.inodes_used_percent | Inode exhaustion | > 80 | > 90 |
| system.load5 | Run-queue pressure (compare to system.n_cpus) | > 2 x n_cpus | (tune) |
| cpu.usage_idle | Idle CPU share | < 20 | < 5 |
| cpu.usage_iowait | CPU time waiting on disk | > 20 | (tune) |
| processes.zombies | Zombie processes | > 0 sustained | (tune) |
| docker_container_mem.usage (container YOUR_WORKLOAD) | Memory used by the container | > 3 GB | (tune) |
| docker_container_mem.usage_percent | Usage versus the container limit | > 80 | > 95 |
| docker_container_status.restart_count | Container restarts | any increase | (tune) |
| docker_container_status.oomkilled | Container killed for memory | - | true |
| docker.n_containers_running | Containers expected to be up | below expected | 0 |
| any point from the host tag | Pipeline liveness | - | no points for 3 minutes |
| Controller agent status | Agent heartbeat | - | agent silent, per the Controller reporting rule |

Other useful context fields: diskio.read_bytes, diskio.write_bytes,
diskio.io_time, docker_container_cpu.usage_percent,
docker_container_blkio.io_service_bytes_recursive_read and
io_service_bytes_recursive_write, processes.total, processes.running,
processes.blocked.

## Pipeline self-metrics (verify write volume)

Use these to check that the agent is healthy and to measure how much it
writes against the free-plan cap.

| Metric (measurement.field) | What it tells you | Warn | Critical |
|---|---|---|---|
| internal_agent.metrics_written | Points written by the agent | - | flat for 3 minutes |
| internal_agent.metrics_dropped | Points dropped | > 0 | sustained increase |
| internal_agent.write_errors | Failed output writes | > 0 | sustained increase |
| internal_agent.gather_errors | Failed input collections | > 0 | sustained increase |
| internal_write.metrics_written (tag output=influxdb_v2) | Points sent to Cloud | - | flat for 3 minutes |
| internal_write.metrics_dropped (tag output) | Points dropped by an output | > 0 | sustained increase |
| internal_write.write_errors (tag output) | Output write errors | > 0 | sustained increase |
| internal_write.buffer_size vs buffer_limit | Backlog when Cloud is unreachable | > 50% of limit | > 90% of limit |
| internal_write.write_time_ns | Time spent writing | (tune) | (tune) |

The `output=heartbeat` series of internal_write covers the Controller
heartbeat output; `output=influxdb_v2` covers the Cloud bucket.

## Notes

- Thresholds are starting points; none has been tuned against a baseline.
- Alert delivery is not implemented. Whether alerting is available on the
  free plan is unverified.
