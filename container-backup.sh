#!/bin/sh


# == CHECKS ENVIRONMENT ==

if [ "${BACKUP_FOLDER}" = "" ]; then
  echo "ERROR - Missing Envrionment Variable: BACKUP_FOLDER"
  exit 1
fi
if [ "${RESTIC_PASSWORD}" = "" ]; then
  echo "ERROR - Missing Envrionment Variable: RESTIC_PASSWORD"
  exit 1
fi
if [ "${BACKUP_RESTIC_REPO}" = "" ]; then
  echo "ERROR - Backup Folder Doesn't Exist: BACKUP_RESTIC_REPO"
  exit 1
fi
if [ ! -d ${BACKUP_FOLDER} ]; then
  echo "ERROR - Backup Folder Doesn't Exist: BACKUP_FOLDER"
  exit 1
fi

if ! type "restic" > /dev/null; then
  echo "ERROR - Restic command not found"
  exit 1
fi


# == CHECKS REPO INIT ==

restic snapshots --repo ${BACKUP_RESTIC_REPO}
if [ $? -eq 0 ]; then
  echo "Repository is initialized"
else
  echo "Repository is not initialized"
  restic init -r ${BACKUP_RESTIC_REPO}
fi


# == CHECKS BACKUP_FOLDER ==

if [ -z "$(ls -A "${BACKUP_FOLDER}")" ]; then
  echo "Directory is empty"
else
  echo "Directory is not empty"
fi


# == DO BACKUP ==

if [ "${BACKUP_DO_PROCESS}" = "" ]; then
  echo "Not Processing Backup"
  exit 0
fi

while true; do
  cd ${BACKUP_FOLDER}
  restic -r ${BACKUP_RESTIC_REPO} backup .
  echo "Next Backup in ${BACKUP_DO_LOOP_FREQUENCY}s"
  if [ "${BACKUP_DO_LOOP_FREQUENCY}" = "" ]; then
    exit 0
  fi
  sleep ${BACKUP_DO_LOOP_FREQUENCY}
done