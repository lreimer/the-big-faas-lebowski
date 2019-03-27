NAME = big-faas-lebowski
VERSION = 1.0.0
GCP = gcloud
K8S = kubectl

.PHONY: info

info:
	@echo "The Big Cloud Native FaaS Lebowski"

prepare:
	@$(GCP) config set compute/zone europe-west1-b
	@$(GCP) config set container/use_client_certificate False

cluster:
	@echo "Create GKE Cluster"
	@$(GCP) container clusters create $(NAME) --num-nodes=5 --enable-autoscaling --min-nodes=5 --max-nodes=10
	@$(K8S) create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$$(gcloud config get-value core/account)
	@$(K8S) create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
	@$(K8S) cluster-info

install-helm:
	@echo "Install Helm"
	@curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash

init-helm:
	@echo "Initialize Helm"
	# add a service account within a namespace to segregate tiller
	@$(K8S) --namespace kube-system apply sa tiller
	# create a cluster role binding for tiller
	@$(K8S) apply clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
	@helm init --service-account tiller
	@helm repo update
	# verify that helm is installed in the cluster
	@$(K8S) get deploy,svc tiller-deploy -n kube-system

access-token:
	@$(GCP) config config-helper --format=json | jq .credential.access_token

dashboard:
	@$(K8S) proxy & 2>&1
	@sleep 3
	@$(GCP) config config-helper --format=json | jq .credential.access_token
	@open http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

clean:
	@$(GCP) container clusters delete $(NAME) --async --quiet
