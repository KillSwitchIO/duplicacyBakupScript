#!/bin/bash

# Set the IP address of the NFS server and the path to the share
NFS_SERVER=192.168.1.112
NFS_SHARE=/mnt/backup

# Set the path to the Duplicacy executable
DUPLICACY_PATH=/usr/local/bin/duplicacy

# Set the path to the Duplicacy repository
DUPLICACY_REPO=$NFS_SHARE/duplicacy_repo

# Set the name of the backup
BACKUP_NAME=conf_backup_$(date +"%Y%m%d_%H%M%S")

# Check if the NFS share is already mounted, and mount it if not
if ! mount | grep "$NFS_SHARE" > /dev/null; then
  echo "NFS share not mounted, attempting to mount..."
  if ! mount -t nfs "$NFS_SERVER:$NFS_SHARE" "$NFS_SHARE"; then
    echo "Unable to mount NFS share, exiting."
    exit 1
  fi
  echo "NFS share mounted successfully."
else
  echo "NFS share already mounted."
fi

# Change to the Duplicacy repository directory
cd $DUPLICACY_REPO

# Run the backup
$DUPLICACY_PATH backup -threads 4 -storage default -stats -hash -tag $BACKUP_NAME /conf

# Unmount the NFS share
echo "Unmounting NFS share..."
umount "$NFS_SHARE"
