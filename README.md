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
34.76.182.176  fission-ui.demo
34.76.182.176  kubeless.demo
34.76.182.176  kubeless-ui.demo
34.76.182.176  openfaas.demo gateway.openfaas.local
```

## Fission Demo

This demo deploys a simple Go function. We use a pool manager size of 5 for the go environment.

```
$ make fission-sources
$ make fission-install
$ kubectl get all -n fission

$ cd fission/
$ fission environment create --name go --image fission/go-env --builder fission/go-builder --poolsize 5

$ kubectl get all -n fission-builder
$ kubectl get all -n fission-function

$ fission fn create --name hello-fission --env go --src hello-fission.go --entrypoint Handler
$ fission pkg info --name <pkg-name>
$ fission function list
$ fission fn test --name hello-fission

$ fission route create --name hello-http --function hello-fission --url /hello-fission --createingress --method GET --host fission.demo

$ http get http://fission.demo/hello-fission
$ hey -c 50 -z 30s http://fission.demo/hello-fission
$ wrk -c 50 -t 4 -d 30s http://fission.demo/hello-fission

$ fission env create --name jvm --image fission/jvm-env --version 2 --keeparchive=true --builder fission/jvm-builder
$ cd fission/examples/jvm
$ mvn clean package
$ fission fn create --name hello-jvm --deploy target/hello-world-1.0-SNAPSHOT-jar-with-dependencies.jar --env jvm --entrypoint io.fission.HelloWorld
$ fission pkg info --name <pkg-name>
$ fission function list
$ fission fn test --name hello-jvm

$ fission route create --name hello-jvm --function hello-jvm --url /hello-jvm --createingress --method GET --host fission.demo
$ http get http://fission.demo/hello-jvm

$ make fission-delete
```

## Kubeless Demo

This demo deploys a simple Go function. We set CPU limits to 100m so that the configured HPA
is working correctly. The functions scales from 5 to 20 replicas.

```
$ make kubeless-sources
$ make kubeless-install
$ kubectl get all -n kubeless
$ kubeless get-server-config

$ cd kubeless/hello-kubeless/
$ kubeless function deploy hello-kubeless --from-file func.go --handler func.Handler --runtime go1.10 --cpu 100m
$ kubeless function call hello-kubeless

$ kubeless trigger http create hello-kubeless --function-name hello-kubeless --path hello-kubeless --gateway traefik --hostname kubeless.demo

$ kubeless autoscale create hello-kubeless --min 5 --max 20 --metric cpu --value 75
$ kubectl scale deployment hello-kubeless --replicas 5

$ http get http://kubeless.demo/hello-kubeless
$ hey -c 50 -z 30s http://kubeless.demo/hello-kubeless
$ wrk -c 50 -t 4 -d 30s http://kubeless.demo/hello-kubeless

$ make kubeless-delete
```

## Nuclio Demo

This demo deploys a simple Go function that scales up to 20 replicas. The ingress used here
is Traefik.

```
$ make nuclio-sources
$ make nuclio-install
$ kubectl get all -n nuclio

$ cd nuclio/
$ ./nuctl create project hello-nuclio -n nuclio
$ ./nuctl deploy hello-nuclio --path hello-nuclio/ --project-name hello-nuclio -n nuclio --max-replicas 20

$ open http://nuclio-ui.demo/
$ http get http://nuclio.demo/hello-nuclio
$ hey -c 50 -z 30s http://nuclio.demo/hello-nuclio
$ wrk -c 50 -t 4 -d 30s http://nuclio.demo/hello-nuclio

$ make nuclio-delete
```

Note: sometimes the CLI times out during deployment of the function. Use the dashboard instead.
In case Nuclio has trouble accessing the Docker registry, make sure you have the correct credentials
set in the Kubernetes secret.

```
$ kubectl get secrets registry-credentials -n nuclio -o 'go-template={{index .data ".dockerconfigjson"}}' | base64 -D
```

## OpenFaas Demo

The OpenFaas demo has been tuned with the help of @alexellis. The function itself has been labeled
to scale from 5 to 20 pods. The gateway component of OpenFaaS has been scaled to 5 replicas. Also
have a look at https://docs.openfaas.com/architecture/performance/

```
$ make openfaas-sources
$ make openfaas-install
$ kubectl get all -n openfaas

$ export OPENFAAS_URL=http://openfaas.demo

$ cd openfaas
$ faas template pull https://github.com/openfaas-incubator/golang-http-template

$ faas build -f stack.yml
$ faas push -f stack.yml
$ faas deploy -f stack.yml

$ kubectl scale deployment gateway --replicas=5 -n openfaas

$ kubectl get all -n openfaas
$ kubectl get all -n openfaas-fn

$ kubectl get svc -n openfaas gateway-external -o wide

$ http get http://<gateway-external-ip>:8080/function/hello-openfaas
$ hey -c 50 -z 30s http://<gateway-external-ip>:8080/function/hello-openfaas
$ wrk -c 50 -t 4 -d 30s http://<gateway-external-ip>:8080/function/hello-openfaas

$ http get http://openfaas.demo/function/hello-openfaas
$ hey -c 50 -z 30s http://openfaas.demo/function/hello-openfaas
$ wrk -c 50 -t 4 -d 30s http://openfaas.demo/function/hello-openfaas

$ make openfaas-delete
```

## Fn Project Demo

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
$ hey -c 50 -z 30s http://fnproject.lb.fn.internal/t/demo/hello-fn
$ wrk -c 50 -t 4 -d 30s http://fnproject.lb.fn.internal/t/demo/hello-fn

$ make fnproject-delete
```

## Maintainer

M.-Leander Reimer (@lreimer), <mario-leander.reimer@qaware.de>

## License

This software is provided under the MIT open source license, read the `LICENSE`
file for details.
