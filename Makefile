NAME = faas-lebowski
VERSION = 1.0.0
GCP = gcloud
ZONE = europe-west1-b
K8S = kubectl

DOCKER_USERNAME ?= lreimer
DOCKER_PASSWORD ?=

.PHONY: info

info:
	@echo "The Big Cloud Native FaaS Lebowski"

prepare:
	@$(GCP) config set compute/zone $(ZONE)
	@$(GCP) config set container/use_client_certificate False

cluster:
	@echo "Create GKE Cluster"
	# --[no-]enable-basic-auth --[no-]issue-client-certificate

	@$(GCP) container clusters create $(NAME) --num-nodes=5 --enable-autoscaling --min-nodes=5 --max-nodes=10 --machine-type=n1-standard-4 --enable-stackdriver-kubernetes --enable-ip-alias --enable-autorepair --scopes cloud-platform --addons HorizontalPodAutoscaling,HttpLoadBalancing --cluster-version "1.14"
	@$(K8S) create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$$(gcloud config get-value core/account)
	@$(K8S) apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
	@$(K8S) apply -f traefik/traefik-rbac.yaml
	@$(K8S) apply -f traefik/traefik-ds.yaml
	@$(K8S) apply -f traefik/traefik-ui.yaml
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

fission-sources:
	@mkdir -p fission && rm -rf fission/fission/ && rm -rf fission/fission-workflow/ && rm -rf fission/fission-ui/
	@git clone --depth 1 https://github.com/fission/fission.git fission/fission
	@git clone --depth 1 https://github.com/fission/fission-workflow.git fission/fission-workflow
	@git clone --depth 1 https://github.com/fission/fission-ui.git fission/fission-ui

fission-install:
	# we could also use the fission-all Helm chart
	@helm install --name fission --namespace fission https://github.com/fission/fission/releases/download/1.3.0/fission-core-1.3.0.tgz
	@$(K8S) apply -f fission/fission-ui/docker/fission-ui.yaml
	@$(K8S) apply -f fission/fission-ui.yaml

fission-delete:
	@helm delete --purge fission
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
	@$(K8S) delete ns fission-builder --ignore-not-found=true

kubeless-sources:
	@mkdir -p kubeless && rm -rf kubeless/kubeless/ && rm -rf kubeless/kubeless-ui
	@git clone --depth 1 https://github.com/kubeless/kubeless.git kubeless/kubeless
	@git clone --depth 1 https://github.com/kubeless/kubeless-ui.git kubeless/kubeless-ui

kubeless-install:
	@$(K8S) create ns kubeless
	@$(K8S) create -f https://github.com/kubeless/kubeless/releases/download/v1.0.4/kubeless-v1.0.4.yaml
	@$(K8S) create -f https://raw.githubusercontent.com/kubeless/kubeless-ui/master/k8s.yaml
	@$(K8S) apply -f kubeless/kubeless-ui.yaml

kubeless-delete:
	@$(K8S) delete -f https://github.com/kubeless/kubeless/releases/download/v1.0.4/kubeless-v1.0.4.yaml --ignore-not-found=true
	@$(K8S) delete crd cronjobtriggers.kubeless.io --ignore-not-found=true
	@$(K8S) delete crd functions.kubeless.io --ignore-not-found=true
	@$(K8S) delete crd httptriggers.kubeless.io --ignore-not-found=true
	@$(K8S) delete ns kubeless

fnproject-sources:
	@mkdir -p fnproject && rm -rf fnproject/fn/ && rm -rf fnproject/fn-helm
	@git clone --depth 1 https://github.com/fnproject/fn.git fnproject/fn
	@git clone --depth 1 https://github.com/fnproject/fn-helm.git fnproject/fn-helm

fnproject-install:
	@curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh
	@helm install --name cert-manager --namespace kube-system --set ingressShim.defaultIssuerName=letsencrypt-staging --set ingressShim.defaultIssuerKind=ClusterIssuer stable/cert-manager --version v0.3.0
	@cd fnproject/fn-helm && helm dep build fn && helm install --name fnproject -f ../values.yaml fn

fnproject-delete:
	@helm delete --purge fnproject

openfaas-sources:
	@mkdir -p openfaas && rm -rf openfaas/faas/ && rm -rf openfaas/faas-netes/
	@git clone --depth 1 https://github.com/openfaas/faas.git openfaas/faas
	@git clone --depth 1 https://github.com/openfaas/faas-netes.git openfaas/faas-netes

openfaas-install:
	@$(K8S) apply -f openfaas/faas-netes/namespaces.yml
	@helm repo add openfaas https://openfaas.github.io/faas-netes/
	@$(K8S) -n openfaas create secret generic basic-auth --from-literal=basic-auth-user=admin --from-literal=basic-auth-password=openfaas
	@helm upgrade openfaas --install openfaas/openfaas --namespace openfaas --set basic_auth=true --set functionNamespace=openfaas-fn --set serviceType=LoadBalancer --set ingress.enabled=true
	@$(K8S) apply -f openfaas/openfaas-gateway.yaml
	export OPENFAAS_URL=http://openfaas.demo
	@faas-cli login --password openfaas

openfaas-delete:
	@helm delete --purge openfaas
	@$(K8S) delete namespace/openfaas
	@$(K8S) delete namespace/openfaas-fn

nuclio-sources:
	@mkdir -p nuclio && rm -rf nuclio/nuclio/ && rm -rf nuclio/templates/
	@git clone --depth 1 https://github.com/nuclio/nuclio.git nuclio/nuclio/
	@git clone --depth 1 https://github.com/nuclio/nuclio-templates.git nuclio/templates/
	@curl -sL https://github.com/nuclio/nuclio/releases/download/1.1.12/nuctl-1.1.12-darwin-amd64 -o nuclio/nuctl && chmod +x nuclio/nuctl

nuclio-install:
	@$(K8S) create namespace nuclio

	@echo "Remember to set DOCKER_USERNAME and DOCKER_PASSWORD env variables."
	@$(K8S) create secret docker-registry registry-credentials --namespace nuclio --docker-username $$DOCKER_USERNAME --docker-password $$DOCKER_PASSWORD --docker-server registry.hub.docker.com --docker-email ignored@nuclio.io

	@$(K8S) create configmap --namespace nuclio nuclio-registry --from-literal=registry_url=registry.hub.docker.com/lreimer
	@$(K8S) apply -f nuclio/nuclio/hack/k8s/resources/nuclio-rbac.yaml
	@$(K8S) apply -f nuclio/nuclio/hack/gke/resources/nuclio.yaml
	@$(K8S) apply -f nuclio/nuclio-dashboard.yaml
	@$(K8S) -n nuclio get all

nuclio-delete:
	@$(K8S) delete -f nuclio/nuclio/hack/gke/resources/nuclio.yaml --ignore-not-found=true
	@$(K8S) delete -f nuclio/nuclio/hack/k8s/resources/nuclio-rbac.yaml --ignore-not-found=true
	@$(K8S) delete namespace nuclio --ignore-not-found=true

knative-gloo:
	@glooctl install gateway
	@glooctl install knative --install-knative --install-eventing --install-monitoring
	@$(K8S) apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.8.0/release.yaml

	@$(K8S) get pods --namespace gloo-system
	@$(K8S) get pods --namespace knative-serving
	@$(K8S) get pods --namespace knative-eventing
	@$(K8S) get pods --namespace knative-monitoring
	@$(K8S) get pods --namespace tekton-pipelines

	@$(K8S) get svc -n gloo-system
	@$(K8S) edit cm config-domain --namespace knative-serving

gcloud-login:
	@$(GCP) auth application-default login

access-token:
	@$(GCP) config config-helper --format=json | jq .credential.access_token

dashboard:
	@$(K8S) proxy & 2>&1
	@sleep 3
	@$(GCP) config config-helper --format=json | jq .credential.access_token
	@open http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

destroy:
	@$(GCP) container clusters delete $(NAME) --async --quiet
