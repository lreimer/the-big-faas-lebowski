# The Big Cloud-native Faas Lebowski

This is the demo repository for my conference talk *The Big Cloud Native FaaS Lebowski*.

Only a few years ago the move towards microservice architecture was the first big disruption in software engineering: instead of running monoliths, systems were now build, composed and run as autonomous services. But this came at the price of added development and infrastructure complexity. Serverless and FaaS seem to be the next disruption, they are the logical evolution trying to address some of the inherent technology complexity we are currently faced when building cloud native apps.

FaaS frameworks are currently popping up like mushrooms: Knative, Kubeless, OpenFn, Fission, OpenFaas or OpenWhisk are just a few to name. But which one of these is safe to pick and use in your next project? Let's find out.

## Preparation

### Step 1: Create Kubernetes cluster

In this first step we are going to create a Kubernetes cluster on GCP. Issue the
following command fire up the infrastructure:
```
$ make prepare cluster
```

### Step 2: Install and Initialize Helm

In this step we are going to install the Helm package manager so we can later easily
install the different FaaS frameworks.

```
$ make helm-install helm-init
```

### Step 3: Prepare Ingress

During clsuter setup an Traefik Ingress has been created. To easily access all the
demo endpoints we are creating a few virtual hostnames in `/etc/hosts`.

First, you need to find out the external IP address of the load balancer. For this, issue the
following command and write down the external IP address for the `traefik-ingress-service`.

```
$ kubectl get svc -n kube-system
```

Now, open your `/etc/hosts` file and enter the following entries. Replace the IP address with
the external IP from the `traefik-ingress-service`.

```
34.76.182.176  traefik-ui.demo
34.76.182.176  fnproject.lb.fn.internal fnproject.api.fn.internal
34.76.182.176  nuclio.demo
34.76.182.176  nuclio-ui.demo
34.76.182.176  fission.demo
34.76.182.176  kubeless.demo
34.76.182.176  openfaas.demo
```

## Fission Demo

## Kubeless Demo

## Nuclio Demo

kubectl get secrets registry-credentials -n nuclio -o 'go-template={{index .data ".dockerconfigjson"}}' | base64 -D

## OpenFaas Demo

## Fn Project Demo

First, we need to install Fn Project in our cluster using the Helm chart. The we are going to create
a simple Go function and deploy it.

```
$ make fnproject-sources
$ make fnproject-install
$ kubectl get all

$ fn create context fnproject --api-url http://fnproject.api.fn.internal --provider default --registry lreimer
$ fn use context fnproject

$ fn init --runtime go hello-fn
$ fn create app demo
$ fn deploy --app demo
$ fn invoke demo hello-fn

$ fn create trigger --source /hello-fn --type http demo hello-fn hello-http
$ http get http://fnproject.lb.fn.internal/t/demo/hello-fn
$ hey -c 50 -n 100 http://fnproject.lb.fn.internal/t/demo/hello-fn

$ make fnproject-delete
```

## Maintainer

M.-Leander Reimer (@lreimer), <mario-leander.reimer@qaware.de>

## License

This software is provided under the MIT open source license, read the `LICENSE`
file for details.
