# Container Utilities

This repository contains a set of utilities for containers.

## container-backup

This is a script to automatically backup and restore data from from restic backups.

- can backup data to restic
- can restore backup if volume not present

Example in Kuberntes:

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
      containers:
        - image: my-application
          name: my-application
          volumeMounts:
            - mountPath: /data
              name: pod-volume
        - name: backup
          image: restic/restic:latest
          command: ["sh", "-c"]
          args:
            - "wget -O /tmp/container-backup.sh https://raw.githubusercontent.com/devopsplaybook-io/container-utils/init/container-backup.sh && chmod +x /tmp/container-backup.sh && /tmp/container-backup.sh"
          volumeMounts:
            - mountPath: /data
              name: pod-volume
          env:
            - name: BACKUP_FOLDER
              value: "/data"
            - name: BACKUP_RESTIC_REPO
              value: "... ..."
            - name: RESTIC_PASSWORD
              value: "... ..."
            - name: BACKUP_DO_PROCESS
              value: "Y"
            - name: BACKUP_DO_START_DELAY
              value: "10800"
            - name: BACKUP_DO_LOOP_FREQUENCY
              value: "10800"
      initContainers:
        - name: init
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
              value: "... ..."
            - name: RESTIC_PASSWORD
              value: "... ..."
            - name: BACKUP_DO_RESTORE
              value: "Y"
      volumes:
        - name: pod-volume
          emptyDir: {}
```
