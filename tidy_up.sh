az group delete --name ajs-aks-demo --yes --verbose
cp $HOME/.kube/config.orig $HOME/.kube/config
rm -rf multiregion
