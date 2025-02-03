#!/bin/sh
set -e
# Start the Docker daemon
dockerd --host=unix:///var/run/docker.sock &
echo "Waiting for Docker to start..."
while ! docker info > /dev/null 2>&1; do sleep 1; done
echo "Docker started successfully"
# Ensure Docker socket has correct permissions
chmod 666 /var/run/docker.sock
# Run installation script
./install_project_requirement.sh
# Change to agent user and start agent
cd /azp
su agent -c "/bin/bash /azp/start.sh"
