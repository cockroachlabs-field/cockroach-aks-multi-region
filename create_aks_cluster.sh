#!/bin/ksh

# Script to create a 3 region, 9 node cockroach db cluster in Azure AKS. Script takes about 40 minutes to run.


# -- Change these variables to customise the installation

# Variables
vm_type="Standard_DS2_v2"
n_nodes=3
resourcegroup="ajs-aks-demo"
loc1="uksouth"
loc2="northeurope"
loc3="germanywestcentral"
# These CIDR ranges must **not** overlap
vnet1_cidr="10.1.0.0/16"
vnet2_cidr="10.2.0.0/16"
vnet3_cidr="10.3.0.0/16"

vnet1_subnet_prefix="10.1.0.0/24"
vnet2_subnet_prefix="10.2.0.0/24"
vnet3_subnet_prefix="10.3.0.0/24"


# Do not change the variables below

clus1=$resourcegroup"-crdb-"$loc1
clus2=$resourcegroup"-crdb-"$loc2
clus3=$resourcegroup"-crdb-"$loc3
vnet1=$resourcegroup"-crdb-vnet-"$loc1
vnet2=$resourcegroup"-crdb-vnet-"$loc2
vnet3=$resourcegroup"-crdb-vnet-"$loc3
vnet1_subnet_name=$resourcegroup"-crdb-"$loc1"-sub1"
vnet2_subnet_name=$resourcegroup"-crdb-"$loc2"-sub1"
vnet3_subnet_name=$resourcegroup"-crdb-"$loc3"-sub1"
log=create.log
comma="'"


# backup the $HOME/.kube/config
cp $HOME/.kube/config $HOME/.kube/config.orig 

> ./$log

# Output Variables
echo "VM type is: " $vm_type
echo "Number of nodes are: " $n_nodes
echo "Resource Group name is: " $resourcegroup
echo ""
echo "*** Region 1 ***"
echo "Region1 is: " $loc1
echo "VNet1 name is: " $vnet1
echo "VNet1 CIDR is: " $vnet1_cidr
echo "VNet1 subnet name is: "$vnet1_subnet_name
echo "Vnet1 subnet prefix is: "$vnet1_subnet_prefix
echo "Cluster1 name is: " $clus1
echo ""
echo "*** Region 2 ***"
echo "Region2 is: " $loc2
echo "VNet2 name is: " $vnet2
echo "VNet2 CIDR is: " $vnet2_cidr
echo "VNet2 subnet name is: "$vnet2_subnet_name
echo "VNet2 subnet prefix is: "$vnet2_subnet_prefix
echo "Cluster2 name is: " $clus2
echo ""
echo "*** Region 3 ***"
echo "Region3 is: " $loc3
echo "VNet3 name is: " $vnet3
echo "VNet3 CIDR is: " $vnet3_cidr
echo "VNet3 subnet name is: "$vnet3_subnet_name
echo "Vnet3 subnet prefix is: "$vnet3_subnet_prefix
echo "Cluster3 name is: " $clus3

echo "VM type is: " $vm_type >> ./$log
echo "Number of nodes are: " $n_nodes >> ./$log
echo "Resource Group name is: " $resourcegroup >> ./$log
echo "" >> ./$log
echo "*** Region 1 ***" >> ./$log
echo "Region1 is: " $loc1 >> ./$log
echo "VNet1 name is: " $vnet1 >> ./$log
echo "VNet1 CIDR is: " $vnet1_cidr >> ./$log
echo "VNet1 subnet name is: "$vnet1_subnet_name >> ./$log
echo "Vnet1 subnet prefix is: "$vnet1_subnet_prefix >> ./$log
echo "Cluster1 name is: " $clus1 >> ./$log
echo "" >> ./$log
echo "*** Region 2 ***" >> ./$log
echo "Region2 is: " $loc2 >> ./$log
echo "VNet2 name is: " $vnet2 >> ./$log
echo "VNet2 CIDR is: " $vnet2_cidr >> ./$log
echo "VNet2 subnet name is: "$vnet2_subnet_name >> ./$log
echo "VNet2 subnet prefix is: "$vnet2_subnet_prefix >> ./$log
echo "Cluster2 name is: " $clus2 >> ./$log
echo "" >> ./$log
echo "*** Region 3 ***" >> ./$log
echo "Region3 is: " $loc3 >> ./$log
echo "VNet3 name is: " $vnet3 >> ./$log
echo "VNet3 CIDR is: " $vnet3_cidr >> ./$log
echo "VNet3 subnet name is: "$vnet3_subnet_name >> ./$log
echo "Vnet3 subnet prefix is: "$vnet3_subnet_prefix >> ./$log
echo "Cluster3 name is: " $clus3 >> ./$log

# create a resource group & k8s identity
az group create --name $resourcegroup --location $loc1 --output tsv >> ./$log
id=$(az identity create --resource-group $resourcegroup --name ajs-k8s-id --output tsv --query "id")
echo "ID is: "$id >> ./$log

# create 3 vnets
az network vnet create -g $resourcegroup -n $vnet1 --address-prefix $vnet1_cidr --subnet-name $vnet1_subnet_name --subnet-prefix $vnet1_subnet_prefix --location $loc1 --output tsv >> ./$log
az network vnet create -g $resourcegroup -n $vnet2 --address-prefix $vnet2_cidr --subnet-name $vnet2_subnet_name --subnet-prefix $vnet2_subnet_prefix --location $loc2 --output tsv >> ./$log
az network vnet create -g $resourcegroup -n $vnet3 --address-prefix $vnet3_cidr --subnet-name $vnet3_subnet_name --subnet-prefix $vnet3_subnet_prefix --location $loc3 --output tsv >> ./$log

# peer the 3 vnets
az network vnet peering create -g $resourcegroup -n $loc1-$loc2-peer --vnet-name $vnet1 --remote-vnet $vnet2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --output tsv >> ./$log
az network vnet peering create -g $resourcegroup -n $loc1-$loc3-peer --vnet-name $vnet1 --remote-vnet $vnet3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --output tsv >> ./$log

az network vnet peering create -g $resourcegroup -n $loc2-$loc1-peer --vnet-name $vnet2 --remote-vnet $vnet1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --output tsv >> ./$log
az network vnet peering create -g $resourcegroup -n $loc2-$loc3-peer --vnet-name $vnet2 --remote-vnet $vnet3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --output tsv >> ./$log

az network vnet peering create -g $resourcegroup -n $loc3-$loc1-peer --vnet-name $vnet3 --remote-vnet $vnet1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --output tsv >> ./$log
az network vnet peering create -g $resourcegroup -n $loc3-$loc2-peer --vnet-name $vnet3 --remote-vnet $vnet2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --output tsv >> ./$log

subnet1_id=$(az network vnet subnet list --resource-group $resourcegroup --vnet-name $vnet1 --output tsv --query "[?name=='"$vnet1_subnet_name"'].id")
echo "Subnet1 id is: " $subnet1_id >> ./$log
subnet2_id=$(az network vnet subnet list --resource-group $resourcegroup --vnet-name $vnet2 --output tsv --query "[?name=='"$vnet2_subnet_name"'].id")
echo "Subnet2 id is: " $subnet2_id >> ./$log
subnet3_id=$(az network vnet subnet list --resource-group $resourcegroup --vnet-name $vnet3 --output tsv --query "[?name=='"$vnet3_subnet_name"'].id")
echo "Subnet3 id is: " $subnet3_id >> ./$log

# create the k8s clusters
az aks create --name $clus1 --resource-group $resourcegroup --network-plugin azure --zones 1 2 3 --vnet-subnet-id $subnet1_id --node-count $n_nodes --assign-identity $id --location $loc1 --output tsv >> ./$log
echo "k8s1 created"

az aks create --name $clus2 --resource-group $resourcegroup --network-plugin azure --zones 1 2 3 --vnet-subnet-id $subnet2_id --node-count $n_nodes --assign-identity $id --location $loc2 --output tsv >> ./$log
echo "k8s2 created"

az aks create --name $clus3 --resource-group $resourcegroup --network-plugin azure --zones 1 2 3 --vnet-subnet-id $subnet3_id --node-count $n_nodes --assign-identity $id --location $loc3 --output tsv >> ./$log
echo "k8s3 created"

# get contexts
az aks get-credentials --name $clus1 --resource-group $resourcegroup
az aks get-credentials --name $clus2 --resource-group $resourcegroup
az aks get-credentials --name $clus3 --resource-group $resourcegroup

if [ -d ./multiregion ]; then rm -rf ./multiregion; fi

mkdir multiregion

cd multiregion

# download config files
curl -OOOOOOOOO  https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/{README.md,client-secure.yaml,cluster-init-secure.yaml,cockroachdb-statefulset-secure.yaml,dns-lb.yaml,example-app-secure.yaml,external-name-svc.yaml,setup.py,teardown.py}
curl -O https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/eks/configmap.yaml


# set the region and contexts in the setup.py file.
cat setup.py | sed 's/^contexts = {/contexts = { '''$comma$loc1$comma''': '''$comma$clus1$comma''', '''$comma$loc2$comma''': '''$comma$clus2$comma''', '''$comma$loc3$comma''': '''$comma$clus3$comma'''/' > setup_ajs.py
mv setup_ajs.py setup_tmp.py
cat setup_tmp.py | sed 's/^regions = {/regions = { '''$comma$loc1$comma''': '''$comma$loc1$comma''', '''$comma$loc2$comma''': '''$comma$loc2$comma''', '''$comma$loc3$comma''': '''$comma$loc3$comma'''/' > setup_ajs.py
rm setup_tmp.py

echo "Start setup.py"
echo "Start setup.py" >> ./$log

# Run the setupscript ***USING PYTHON 2***
python2 ./setup_ajs.py >> ./$log

echo "Completed setup.py"
echo "Completed setup.py" >> ./$log

# get the LB external IP addresses
lb1_ipX=$(kubectl get services --context $clus1 --all-namespaces | grep kube-dns-lb | awk "{ print \$5 }")
lb2_ipX=$(kubectl get services --context $clus2 --all-namespaces | grep kube-dns-lb | awk "{ print \$5 }")
lb3_ipX=$(kubectl get services --context $clus3 --all-namespaces | grep kube-dns-lb | awk "{ print \$5 }")

# get the LB internal IP addresses
lb1_ipI=$(kubectl get services --context $clus1 --all-namespaces | grep kube-dns-lb | awk "{ print \$4 }")
lb2_ipI=$(kubectl get services --context $clus2 --all-namespaces | grep kube-dns-lb | awk "{ print \$4 }")
lb3_ipI=$(kubectl get services --context $clus3 --all-namespaces | grep kube-dns-lb | awk "{ print \$4 }")

# get the cockroach service internal IP address
lb1_ipC=$(kubectl get services --context $clus1 -n $loc1 | grep cockroachdb-public | grep ClusterIP | awk "{ print \$3 }")
lb2_ipC=$(kubectl get services --context $clus2 -n $loc2 | grep cockroachdb-public | grep ClusterIP | awk "{ print \$3 }")
lb3_ipC=$(kubectl get services --context $clus3 -n $loc3 | grep cockroachdb-public | grep ClusterIP | awk "{ print \$3 }")

echo "cluster 1 DNS ips" >> ./$log
echo "lb1_ipX is: " $lb1_ipX >> ./$log
echo "lb1_ipI is: " $lb1_ipI >> ./$log
echo "lb1_ipC is: " $lb1_ipC >> ./$log


echo "cluster 2 DNS ips" >> ./$log
echo "lb2_ipX is: " $lb2_ipX >> ./$log
echo "lb2_ipI is: " $lb2_ipI >> ./$log
echo "lb2_ipC is: " $lb2_ipC >> ./$log

echo "cluster 3 DNS ips" >> ./$log
echo "lb3_ipX is: " $lb3_ipX >> ./$log
echo "lb3_ipI is: " $lb3_ipI >> ./$log
echo "lb3_ipC is: " $lb3_ipC >> ./$log

echo "Got LB IPs"
echo "Got LB IPs" >> ./$log

# Create the updated configmap.yaml file for the coredns-custom
# 1: get the header
head -7 configmap.yaml | sed 's/coredns/coredns-custom/' | sed 's/Corefile/cockroachdns.server/' > configmap_header.yaml

# 2: Get the template
head -32 configmap.yaml | tail -9 | sed 's/force_tcp//' > configmap_template.yaml

# 3: Create the 3 regions for the file
cat configmap_template.yaml | sed 's/<cluster-namespace-2>/'$loc1'/' | sed 's/<ip1> <ip2> <ip3>/'$lb1_ipC' '$lb1_ipI' '$lb1_ipX'/' > configmap_lb1.yaml
cat configmap_template.yaml | sed 's/<cluster-namespace-2>/'$loc2'/' | sed 's/<ip1> <ip2> <ip3>/'$lb2_ipC' '$lb2_ipI' '$lb2_ipX'/' > configmap_lb2.yaml
cat configmap_template.yaml | sed 's/<cluster-namespace-2>/'$loc3'/' | sed 's/<ip1> <ip2> <ip3>/'$lb3_ipC' '$lb3_ipI' '$lb3_ipX'/' > configmap_lb3.yaml

# 4: Create the new configmap.yaml file
cat configmap_header.yaml > configmap_ajs1.yaml
cat configmap_lb2.yaml >> configmap_ajs1.yaml
cat configmap_lb3.yaml >> configmap_ajs1.yaml

cat configmap_header.yaml > configmap_ajs2.yaml
cat configmap_lb1.yaml >> configmap_ajs2.yaml
cat configmap_lb3.yaml >> configmap_ajs2.yaml

cat configmap_header.yaml > configmap_ajs3.yaml
cat configmap_lb1.yaml >> configmap_ajs3.yaml
cat configmap_lb2.yaml >> configmap_ajs3.yaml

# backup the existing configmaps
kubectl -n kube-system get configmap coredns -o yaml --context $clus1 > configmap1.yaml
kubectl -n kube-system get configmap coredns -o yaml --context $clus2 > configmap2.yaml
kubectl -n kube-system get configmap coredns -o yaml --context $clus3 > configmap3.yaml

# create custom coredns contexts, delete existing coredns pods to get new DNS settings
echo "Applying configmap to "$clus1 >> ./$log
echo "**** configmap contents ****" >> ./$log
cat configmap_ajs1.yaml >> ./$log
kubectl apply -f configmap_ajs1.yaml --context $clus1 && kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $clus1
sleep 3


echo "Applying configmap to "$clus2
echo "**** configmap contents ****" >> ./$log
cat configmap_ajs2.yaml >> ./$log
kubectl apply -f configmap_ajs2.yaml --context $clus2 && kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $clus3
sleep 3

echo "Applying configmap to "$clus3
echo "**** configmap contents ****" >> ./$log
cat configmap_ajs3.yaml >> ./$log
kubectl apply -f configmap_ajs3.yaml --context $clus3 && kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $clus3
sleep 3

echo "Applied Configmaps"
echo "Applied Configmaps" >> ./$log

# Create secure clients
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $loc1 --context $clus1
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $loc2 --context $clus2
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $loc3 --context $clus3

echo "Created secure clients"
echo "Created Secure clients" >> ./$log

# Port forward the admin UI 
nohup kubectl port-forward cockroachdb-0 8080 --context $clus1 --namespace $loc1 > /dev/null &
nohup kubectl port-forward cockroachdb-0 26257 --context $clus1 --namespace $loc1 > /dev/null &

echo "Applied port forwarding"
echo "Applied port forwarding" >> ./$log

echo "Complete!"
