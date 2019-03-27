# The Big Cloud-native Faas Lebowski

This is the demo repository for my conference talk *The Big Cloud Native FaaS Lebowski*.

## Demo

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
$ make install-helm
$ make init-helm
```

## Maintainer

M.-Leander Reimer (@lreimer), <mario-leander.reimer@qaware.de>

## License

This software is provided under the MIT open source license, read the `LICENSE`
file for details.
