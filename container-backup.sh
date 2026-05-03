#!/bin/sh



message() { 
  echo "($(date '+%Y-%m-%d %H:%M:%S')) $1"
}



# == CHECKS ENVIRONMENT ==

if [ "${BACKUP_FOLDER}" = "" ]; then
  message "ERROR - Missing Environment Variable: BACKUP_FOLDER"
  exit 1
fi
if [ "${RESTIC_PASSWORD}" = "" ]; then
  message "ERROR - Missing Environment Variable: RESTIC_PASSWORD"
  exit 1
fi
if [ "${BACKUP_RESTIC_REPO}" = "" ]; then
  message "ERROR - Missing Environment Variable: BACKUP_RESTIC_REPO"
  exit 1
fi
if [ ! -d "${BACKUP_FOLDER}" ]; then
  message "ERROR - Backup Folder Doesn't Exist: BACKUP_FOLDER"
  exit 1
fi

if ! type "restic" > /dev/null; then
  message "ERROR - Restic command not found"
  exit 1
fi



# == CHECKS REPO INIT ==

restic snapshots --repo "${BACKUP_RESTIC_REPO}" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  message "Repository is initialized"
  message "Known snapshots..."
  restic snapshots --repo "${BACKUP_RESTIC_REPO}"
else
  message "Repository is not initialized"
  restic init -r "${BACKUP_RESTIC_REPO}"
fi



# == RESTORE IF EMPTY ==

if [ -z "$(ls -A "${BACKUP_FOLDER}")" ]; then
  message "Directory is empty"
  message "Restoring last snapshot"
  nice -n 10 restic -r "${BACKUP_RESTIC_REPO}" restore latest --target "${BACKUP_FOLDER}" || true
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
  sleep "${BACKUP_DO_START_DELAY}"
fi

if [ "${BACKUP_CLEANUP_KEEP_COUNT}" = "" ]; then
  BACKUP_CLEANUP_KEEP_COUNT=1
fi

while true; do
  cd "${BACKUP_FOLDER}"
  message "Removing stale locks"
  restic unlock -r "${BACKUP_RESTIC_REPO}" || true
  message "Starting backup"
  restic backup \
    -r "${BACKUP_RESTIC_REPO}" \
    --group-by paths \
    . || true
  message "Finished backup"
  if [ "${BACKUP_DO_CLEANUP}" = "Y" ]; then
    if [ "${BACKUP_CLEANUP_AGE_DAYS}" = "" ]; then
      message "Skipping cleanup: BACKUP_CLEANUP_AGE_DAYS is not set"
    else
      message "Starting cleanup (keep last ${BACKUP_CLEANUP_KEEP_COUNT}, remove older than ${BACKUP_CLEANUP_AGE_DAYS} days)"
      restic forget \
        -r "${BACKUP_RESTIC_REPO}" \
        --group-by paths \
        --keep-last "${BACKUP_CLEANUP_KEEP_COUNT}" \
        --keep-within "${BACKUP_CLEANUP_AGE_DAYS}d" \
        --prune || true
      message "Finished cleanup"
    fi
  fi
  if [ "${BACKUP_DO_LOOP_FREQUENCY}" = "" ]; then
    exit 0
  fi
  message "Next Backup in ${BACKUP_DO_LOOP_FREQUENCY}s"
  sleep "${BACKUP_DO_LOOP_FREQUENCY}"
done
