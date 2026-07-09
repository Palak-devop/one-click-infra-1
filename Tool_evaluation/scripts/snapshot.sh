#!/bin/bash
# Backup script to take snapshots of VictoriaMetrics storage EBS volumes.
# This script should be run on a schedule (e.g. daily cron job) on the Jenkins server or operator machine.

set -e

REGION="ap-south-1"
TAG_KEY="Name"
TAG_VALUES=("vmstorage-ebs-1" "vmstorage-ebs-2")

echo "=========================================================="
echo "Starting EBS Snapshot backup at $(date)"
echo "=========================================================="

for tag_val in "${TAG_VALUES[@]}"; do
  echo "Finding volume with tag $TAG_KEY=$tag_val..."
  
  # Fetch Volume ID
  volume_id=$(aws ec2 describe-volumes \
    --region "$REGION" \
    --filters "Name=tag:$TAG_KEY,Values=$tag_val" \
    --query "Volumes[0].VolumeId" \
    --output text)

  if [ "$volume_id" == "None" ] || [ -z "$volume_id" ]; then
    echo "Warning: Volume with tag $tag_val not found in region $REGION. Skipping."
    continue
  fi

  echo "Found Volume ID: $volume_id. Creating snapshot..."

  # Create Snapshot
  description="Automated VictoriaMetrics Backup - $tag_val - $(date +'%Y-%m-%d-%H%M')"
  snapshot_id=$(aws ec2 create-snapshot \
    --region "$REGION" \
    --volume-id "$volume_id" \
    --description "$description" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=backup-$tag_val},{Key=CreatedBy,Value=BackupScript}]" \
    --query "SnapshotId" \
    --output text)

  echo "Snapshot successfully created: $snapshot_id"
done

echo "=========================================================="
echo "Backup execution finished successfully."
echo "=========================================================="
