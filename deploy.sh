#!/bin/bash

set -euo pipefail

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:?AWS_DEFAULT_REGION is required}"
ECR_REPOSITORY="${ECR_REPOSITORY:?ECR_REPOSITORY is required}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG is required}"

CONTAINER_NAME="${CONTAINER_NAME:-springboot-app}"
HOST_PORT="${HOST_PORT:-8080}"
CONTAINER_PORT="${CONTAINER_PORT:-8080}"

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
FULL_IMAGE_NAME="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

echo "=========================================="
echo "Deploying Spring Boot application"
echo "Image: ${FULL_IMAGE_NAME}"
echo "Container: ${CONTAINER_NAME}"
echo "Port: ${HOST_PORT}:${CONTAINER_PORT}"
echo "=========================================="

echo "Checking AWS IAM Role..."
aws sts get-caller-identity

echo "Logging in to Amazon ECR..."
aws ecr get-login-password \
  --region "${AWS_DEFAULT_REGION}" |
docker login \
  --username AWS \
  --password-stdin "${ECR_REGISTRY}"

echo "Pulling Docker image..."
docker pull "${FULL_IMAGE_NAME}"

if docker ps -a \
  --format '{{.Names}}' |
  grep -Fxq "${CONTAINER_NAME}"; then

  echo "Stopping existing container..."
  docker stop "${CONTAINER_NAME}" || true

  echo "Removing existing container..."
  docker rm "${CONTAINER_NAME}" || true
fi

echo "Starting new container..."

docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  "${FULL_IMAGE_NAME}"

echo "Waiting for container startup..."
sleep 10

if docker ps \
  --format '{{.Names}}' |
  grep -Fxq "${CONTAINER_NAME}"; then

  echo "Deployment successful."
  docker ps --filter "name=${CONTAINER_NAME}"
else
  echo "Deployment failed."
  echo "Container logs:"
  docker logs "${CONTAINER_NAME}" || true
  exit 1
fi
