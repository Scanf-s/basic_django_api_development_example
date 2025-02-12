echo "✋ Health check for $BACKEND_IMAGE"

# BACKEND_IMAGE로 실행한 컨테이너가 잘 올라갔는지 확인
export BACKEND_CONTAINER_NAME=$(docker ps --filter "ancestor=$BACKEND_IMAGE" --format "{{.Names}}")
if [ -n "$BACKEND_CONTAINER_NAME" ]; then
  echo "✅ $BACKEND_CONTAINER_NAME is running"
else
  echo "❌ $BACKEND_IMAGE is not running... Rollback"

  docker compose -f docker-compose.yml down
  docker pull $ECR_REGISTRY/$ECR_REPOSITORY:stable
  export BACKEND_IMAGE="$ECR_REGISTRY/$ECR_REPOSITORY:stable"
  docker compose -f docker-compose.yml up -d

  echo "🍥 Rollback Done"
  exit 1
fi

# BACKEND_CONTAINER_NAME로 실행한 컨테이너가 잘 올라갔는지 확인
iteration=0
export CONTAINER_STATUS=$(docker inspect -f '{{.State.Health.Status}}' $BACKEND_CONTAINER_NAME)
while [ $iteration -lt 5 ] && [ "$CONTAINER_STATUS" != "healthy" ]; do
  sleep 5
  export CONTAINER_STATUS=$(docker inspect -f '{{.State.Health.Status}}' $BACKEND_CONTAINER_NAME)
  iteration=$((iteration + 1))
done

if [ "$CONTAINER_STATUS" == "healthy" ]; then
  echo "✅ $BACKEND_CONTAINER_NAME is healthy"
  echo "Create stable image for backup"

  docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:stable
  docker push $ECR_REGISTRY/$ECR_REPOSITORY:stable

  echo "✅ Done"
else
  echo "❌ $BACKEND_CONTAINER_NAME is not healthy... Rollback"

  docker compose -f docker-compose.yml down
  docker pull $ECR_REGISTRY/$ECR_REPOSITORY:stable
  export BACKEND_IMAGE="$ECR_REGISTRY/$ECR_REPOSITORY:stable"
  docker compose -f docker-compose.yml up -d

  echo "🍥 Rollback Done"
  exit 1
fi
