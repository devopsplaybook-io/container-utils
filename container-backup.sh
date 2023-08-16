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


# == CHECKS REPO INIT ==

restic snapshots --repo ${BACKUP_RESTIC_REPO}
if [ $? -eq 0 ]; then
  message "Repository is initialized"
else
  message "Repository is not initialized"
  restic init -r ${BACKUP_RESTIC_REPO}
fi


# == CHECKS BACKUP_FOLDER ==

if [ -z "$(ls -A "${BACKUP_FOLDER}")" ]; then
  message "Directory is empty"
else
  message "Directory is not empty"
fi


# == DO BACKUP ==

if [ "${BACKUP_DO_PROCESS}" = "" ]; then
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
  restic -r ${BACKUP_RESTIC_REPO} backup .
  message "Finished backup"
  if [ "${BACKUP_DO_LOOP_FREQUENCY}" = "" ]; then
    exit 0
  fi
  message "Next Backup in ${BACKUP_DO_LOOP_FREQUENCY}s"
  sleep ${BACKUP_DO_LOOP_FREQUENCY}
done