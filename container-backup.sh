#!/bin/sh


message() { 
  echo "($(date '+%Y-%m-%d %H:%M:%S')) $1"
}


# == CHECKS ENVIRONMENT ==

if [ "${BACKUP_FOLDER}" = "" ]; then
  message "ERROR - Missing Envrionment Variable: BACKUP_FOLDER"
  exit 1
fi
if [ "${RESTIC_PASSWORD}" = "" ]; then
  message "ERROR - Missing Envrionment Variable: RESTIC_PASSWORD"
  exit 1
fi
if [ "${BACKUP_RESTIC_REPO}" = "" ]; then
  message "ERROR - Backup Folder Doesn't Exist: BACKUP_RESTIC_REPO"
  exit 1
fi
if [ ! -d ${BACKUP_FOLDER} ]; then
  message "ERROR - Backup Folder Doesn't Exist: BACKUP_FOLDER"
  exit 1
fi

if ! type "restic" > /dev/null; then
  message "ERROR - Restic command not found"
  exit 1
fi

export GOMAXPROCS=1

# == CHECKS REPO INIT ==

restic snapshots --repo ${BACKUP_RESTIC_REPO} > /dev/null 2>&1
if [ $? -eq 0 ]; then
  message "Repository is initialized"
  message "Known snapshots..."
  restic snapshots --repo ${BACKUP_RESTIC_REPO}
else
  message "Repository is not initialized"
  restic init -r ${BACKUP_RESTIC_REPO}
fi


# == RESTORE IF EMPTY ==

if [ -z "$(ls -A "${BACKUP_FOLDER}")" ]; then
  message "Directory is empty"
  message "Restoring last snapshot"
  restic -r ${BACKUP_RESTIC_REPO} restore latest --target ${BACKUP_FOLDER} || true
  message "Snapshot Restored"
else
  message "Directory is not empty"  
fi



# == DO BACKUP ==

if [ "${BACKUP_DO_PROCESS}" != "Y" ]; then
  message "Not Processing Backup"
  exit 0
fi

if [ "${BACKUP_DO_START_DELAY}" != "" ]; then
  message "First Backup in ${BACKUP_DO_START_DELAY}s"
  sleep ${BACKUP_DO_START_DELAY}
fi

while true; do
  cd ${BACKUP_FOLDER}
  message "Starting backup"
  restic -r ${BACKUP_RESTIC_REPO} backup . || true
  message "Finished backup"
  if [ "${BACKUP_DO_LOOP_FREQUENCY}" = "" ]; then
    exit 0
  fi
  message "Next Backup in ${BACKUP_DO_LOOP_FREQUENCY}s"
  sleep ${BACKUP_DO_LOOP_FREQUENCY}
done