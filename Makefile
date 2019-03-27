NAME = big-faas-lebowski
VERSION = 1.0.0
GCP = gcloud
ZONE = europe-west1-b
K8S = kubectl

.PHONY: info

info:
	@echo "The Big Cloud Native FaaS Lebowski"

prepare:
	@$(GCP) config set compute/zone $(ZONE)
	@$(GCP) config set container/use_client_certificate False

cluster:
	@echo "Create GKE Cluster"
	# --[no-]enable-basic-auth --[no-]issue-client-certificate
	@$(GCP) container clusters create $(NAME) --num-nodes=5 --enable-autoscaling --min-nodes=5 --max-nodes=10
	@$(K8S) create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$$(gcloud config get-value core/account)
	@$(K8S) create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
	@$(K8S) apply -f traefik/traefik-rbac.yaml
	@$(K8S) apply -f traefik/traefik-ds.yaml
	@$(K8S) cluster-info

helm-install:
	@echo "Install Helm"
	@curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash

helm-init:
	@echo "Initialize Helm"
	# add a service account within a namespace to segregate tiller
	@$(K8S) --namespace kube-system create sa tiller
	# create a cluster role binding for tiller
	@$(K8S) create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
	@helm init --service-account tiller
	@helm repo update
	# verify that helm is installed in the cluster
	@$(K8S) get deploy,svc tiller-deploy -n kube-system

fission-install:
	@mkdir -p fission && rm -rf fission/fission/ && rm -rf fission/fission-workflow/
	@git clone --depth 1 https://github.com/fission/fission.git fission/fission
	@git clone --depth 1 https://github.com/fission/fission-workflow.git fission/fission-workflow
	@helm install --name fission --namespace fission https://github.com/fission/fission/releases/download/1.1.0/fission-core-1.1.0.tgz
	# @helm install --name fission --namespace fission https://github.com/fission/fission/releases/download/1.1.0/fission-all-1.1.0.tgz

fission-delete:
	@$(K8S) delete crd canaryconfigs.fission.io --ignore-not-found=true
	@$(K8S) delete crd environments.fission.io --ignore-not-found=true
	@$(K8S) delete crd functions.fission.io --ignore-not-found=true
	@$(K8S) delete crd httptriggers.fission.io --ignore-not-found=true
	@$(K8S) delete crd kuberneteswatchtriggers.fission.io --ignore-not-found=true
	@$(K8S) delete crd messagequeuetriggers.fission.io --ignore-not-found=true
	@$(K8S) delete crd packages.fission.io --ignore-not-found=true
	@$(K8S) delete crd recorders.fission.io --ignore-not-found=true
	@$(K8S) delete crd timetriggers.fission.io --ignore-not-found=true
	@$(K8S) delete ns fission --ignore-not-found=true
	@rm -rf fission/fission/
	@rm -rf fission/fission-workflow/

kubeless-install:
	@mkdir -p kubeless && rm -rf kubeless/kubeless/
	@git clone --depth 1 https://github.com/kubeless/kubeless.git kubeless/kubeless
	@$(K8S) create ns kubeless
	@$(K8S) create -f https://github.com/kubeless/kubeless/releases/download/v1.0.3/kubeless-v1.0.3.yaml

kubeless-delete:
	@$(K8S) delete -f https://github.com/kubeless/kubeless/releases/download/v1.0.3/kubeless-v1.0.3.yaml
	@$(K8S) delete crd cronjobtriggers.kubeless.io --ignore-not-found=true
	@$(K8S) delete crd functions.kubeless.io --ignore-not-found=true
	@$(K8S) delete crd httptriggers.kubeless.io --ignore-not-found=true
	@$(K8S) delete ns kubeless
	@rm -rf kubeless/kubeless/

gcloud-login:
	@$(GCP) auth application-default login

access-token:
	@$(GCP) config config-helper --format=json | jq .credential.access_token

dashboard:
	@$(K8S) proxy & 2>&1
	@sleep 3
	@$(GCP) config config-helper --format=json | jq .credential.access_token
	@open http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

clean:
	@$(GCP) container clusters delete $(NAME) --async --quiet
