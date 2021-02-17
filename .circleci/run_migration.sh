cat .circleci/migrate_db.yml.tmpl | \
  sed 's/\$IMAGE_TAG'"/$IMAGE_TAG/g" | \
  sed 's/\$JOB'"/$JOB/g" | \
  sed 's/\$APP_ENV'"/$APP_ENV/g" | \
  kubectl apply -f -

echo job: $JOB
pod=$(kubectl get pods --selector=job-name=$JOB --output=jsonpath='{.items[*].metadata.name}')
echo pod: $pod

kubectl wait --for=condition=Ready --timeout=60s pod/$pod
kubectl logs -f $pod
kubectl wait --for=condition=complete --timeout=60s job/$JOB
kubectl delete job $JOB
