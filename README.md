# Container Utilities

A collection of lightweight shell utilities designed to run alongside applications in containers.

## Table of Contents

- [container-backup](#container-backup)
  - [Features](#features)
  - [How It Works](#how-it-works)
  - [Environment Variables](#environment-variables)
  - [Usage: Local](#usage-local)
  - [Usage: Kubernetes](#usage-kubernetes)

---

## container-backup

A POSIX shell script that uses [restic](https://restic.net/) to automatically back up a data directory, restore it when empty, and optionally prune old snapshots to reclaim space.

It is designed to run as a **sidecar** (continuous backup loop) and/or an **init container** (one-shot restore on startup) inside a Kubernetes pod, but also works standalone on any host with `restic` installed.

### Features

- Initializes the restic repository on first run
- Restores the latest snapshot automatically when the target directory is empty (ideal for `emptyDir` volumes or fresh PVCs)
- Periodic backup loop with configurable start delay and frequency
- Optional retention policy: forget snapshots older than N days while always keeping at least K recent snapshots
- Optional pruning to reclaim storage space in the restic repository

### How It Works

On every run, the script performs the following steps:

1. **Validate environment** — fails fast if required variables are missing or the backup folder does not exist.
2. **Initialize repository** — runs `restic init` if the repo is not yet initialized.
3. **Restore if empty** — if `BACKUP_FOLDER` is empty, restores the `latest` snapshot into it.
4. **Backup loop** (only when `BACKUP_DO_PROCESS=Y`):
   - Wait `BACKUP_DO_START_DELAY` seconds (if set)
   - Run `restic backup` on the folder
   - Optionally run `restic forget --prune` for retention (if `BACKUP_DO_CLEANUP=Y`)
   - Sleep `BACKUP_DO_LOOP_FREQUENCY` seconds and repeat (or exit if the variable is unset)

### Environment Variables

| Variable                    | Required                 | Default   | Description                                                                                                                                                             |
| --------------------------- | ------------------------ | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BACKUP_FOLDER`             | Yes                      | —         | Absolute path of the directory to back up / restore into.                                                                                                               |
| `BACKUP_RESTIC_REPO`        | Yes                      | —         | Restic repository URI (e.g. `s3:s3.amazonaws.com/my-bucket/my-app`).                                                                                                    |
| `RESTIC_PASSWORD`           | Yes                      | —         | Password used to encrypt the restic repository.                                                                                                                         |
| `BACKUP_DO_PROCESS`         | No                       | _(unset)_ | Set to `Y` to enable the backup loop. When unset or any other value, the script only performs validation + restore-if-empty, then exits. Useful for init-container use. |
| `BACKUP_DO_START_DELAY`     | No                       | _(none)_  | Seconds to wait before the first backup (after restore).                                                                                                                |
| `BACKUP_DO_LOOP_FREQUENCY`  | No                       | _(none)_  | Seconds between consecutive backups. If unset, the script runs a single backup and exits.                                                                               |
| `BACKUP_DO_CLEANUP`         | No                       | _(unset)_ | Set to `Y` to enable retention / pruning after each backup.                                                                                                             |
| `BACKUP_CLEANUP_AGE_DAYS`   | If `BACKUP_DO_CLEANUP=Y` | —         | Snapshots older than this many days are eligible for deletion.                                                                                                          |
| `BACKUP_CLEANUP_KEEP_COUNT` | No                       | `1`       | Minimum number of most-recent snapshots to keep, regardless of age.                                                                                                     |

Restic also honors its native variables such as `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `B2_ACCOUNT_ID`, etc., depending on the chosen backend. See the [restic documentation](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html) for the full list.

### Usage: Local

```bash
#!/bin/bash
export BACKUP_FOLDER="./data"
export BACKUP_RESTIC_REPO="s3:s3.amazonaws.com/my-bucket/my-app"
export RESTIC_PASSWORD="change-me"
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="ap-east-1"

export BACKUP_DO_PROCESS="Y"
export BACKUP_DO_START_DELAY="60"
export BACKUP_DO_LOOP_FREQUENCY="10800"

export BACKUP_DO_CLEANUP="Y"
export BACKUP_CLEANUP_AGE_DAYS="30"
export BACKUP_CLEANUP_KEEP_COUNT="3"

./container-backup.sh
```

### Usage: Kubernetes

The script can be used in two complementary ways inside the same pod:

- **initContainer** — restores the latest snapshot into an empty volume before the main container starts.
- **sidecar container** — runs the continuous backup loop alongside the main container.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-application
  labels:
    app: my-application
spec:
  selector:
    matchLabels:
      app: my-application
  template:
    metadata:
      labels:
        app: my-application
    spec:
      initContainers:
        - name: restore
          image: restic/restic:latest
          command: ["sh", "-c"]
          args:
            - "wget -O /tmp/container-backup.sh https://raw.githubusercontent.com/devopsplaybook-io/container-utils/main/container-backup.sh && chmod +x /tmp/container-backup.sh && /tmp/container-backup.sh"
          volumeMounts:
            - mountPath: /data
              name: pod-volume
          env:
            - name: BACKUP_FOLDER
              value: "/data"
            - name: BACKUP_RESTIC_REPO
              valueFrom:
                secretKeyRef: { name: backup-secrets, key: repo }
            - name: RESTIC_PASSWORD
              valueFrom:
                secretKeyRef: { name: backup-secrets, key: password }
            # BACKUP_DO_PROCESS is intentionally unset so the script only
            # performs restore-if-empty and then exits.
      containers:
        - name: my-application
          image: my-application
          volumeMounts:
            - mountPath: /data
              name: pod-volume
        - name: backup
          image: restic/restic:latest
          command: ["sh", "-c"]
          args:
            - "wget -O /tmp/container-backup.sh https://raw.githubusercontent.com/devopsplaybook-io/container-utils/main/container-backup.sh && chmod +x /tmp/container-backup.sh && /tmp/container-backup.sh"
          volumeMounts:
            - mountPath: /data
              name: pod-volume
          env:
            - name: BACKUP_FOLDER
              value: "/data"
            - name: BACKUP_RESTIC_REPO
              valueFrom:
                secretKeyRef: { name: backup-secrets, key: repo }
            - name: RESTIC_PASSWORD
              valueFrom:
                secretKeyRef: { name: backup-secrets, key: password }
            - name: BACKUP_DO_PROCESS
              value: "Y"
            - name: BACKUP_DO_START_DELAY
              value: "10800"
            - name: BACKUP_DO_LOOP_FREQUENCY
              value: "10800"
            - name: BACKUP_DO_CLEANUP
              value: "Y"
            - name: BACKUP_CLEANUP_AGE_DAYS
              value: "30"
            - name: BACKUP_CLEANUP_KEEP_COUNT
              value: "3"
      volumes:
        - name: pod-volume
          emptyDir: {}
```

> **Tip:** Always store `RESTIC_PASSWORD` and cloud credentials in a `Secret`, never as plaintext `value:` entries.
