# The Big Cloud-native Faas Lebowski

This is the demo repository for my conference talk *The Big Cloud Native FaaS Lebowski*.

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

## Fission Demo

## Kubeless Demo

## Fn Project Demo

First, we need to install Fn Project in our cluster using the Helm chart.

fn create context fnproject --api-url http://fnproject.api.fn.internal --provider default --registry lreimer
fn us context fnproject

fn init --runtime go hello
fn create app myapp
fn deploy --app myapp
fn invoke myapp hello

fn create trigger --source /hello --type http myapp hello hello-http
http get http://fnproject.lb.fn.internal:90/t/myapp/hello
hey -c 50 -n 1000 http://fnproject.lb.fn.internal:90/t/myapp/hello

## Maintainer

M.-Leander Reimer (@lreimer), <mario-leander.reimer@qaware.de>

## License

This software is provided under the MIT open source license, read the `LICENSE`
file for details.
