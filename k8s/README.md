# Vagrant Kubernetes 

## Prerequistes

* Vagrant
* Virtualbox
* kubectl (optional)

macOS (with homebrew):

```
brew cask install virtualbox
brew cask install vagrant
brew install kubernetes-cli # optional
```

## Using

In this directory:

```
vagrant up
```

This will create a master (2GB RAM) and two nodes (1GB RAM each).

The dashboard will be available (unauthenticated) at http://10.90.0.10:30001

To copy off the kubectl config needed to remotely manage the cluster:

```
vagrant ssh-config > $HOME/.ssh/vagrant_ssh_config
scp -F $HOME/.ssh/vagrant_ssh_config k8s-master:.kube/config /tmp/admin.conf
KUBECONFIG=/tmp/admin.conf kubectl get all --all-namespaces
```

## Customizing

See Vagrantfile to tweak:

* Kubernetes version (1.7 and 1.6 supported)
* IP addresses
* Number of nodes
* RAM allocations

