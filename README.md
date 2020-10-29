# cockroach-aks-multi-region

Description: Setting up and configuring a multi region cockroach cluster on Azure AKS
Tags: Azure

- Create a set of variables

    ```bash
    vm_type="Standard_DS2_v2"
    n_nodes=3
    rg="crdb-aks-multi-region"
    clus1="crdb-aks-eastus"
    clus2="crdb-aks-westus"
    clus3="crdb-aks-northeurope"
    loc1="eastus"
    loc2="westus"
    loc3="northeurope"
    ```

- Create a Resource Group for the project

    ```bash
    az group create --name $rg --location $loc1
    ```

- Networking configuration

    In order to enable VPC peering between the regions, the CIDR blocks of the VPCs must not overlap. This value cannot change once the cluster has been created, so be sure that your IP ranges do not overlap.

    - Create vnets for all Regions

        ```bash
        az network vnet create -g $rg -n crdb-eastus --address-prefix 20.0.0.0/16 \
            --subnet-name crdb-eastus-sub1 --subnet-prefix 20.0.0.0/24
        ```

        ```bash
        az network vnet create -g $rg -n crdb-westus --address-prefix 30.0.0.0/16 \
            --subnet-name crdb-westus-sub1 --subnet-prefix 30.0.0.0/24
        ```

        ```bash
        az network vnet create -g $rg -n crdb-northeurope --address-prefix 40.0.0.0/16 \
            --subnet-name crdb-northeurope-sub1 --subnet-prefix 40.0.0.0/24
        ```

    - Peer the Vnets

        ```bash
        az network vnet peering create -g $rg -n eastuswestuspeer --vnet-name crdb-eastus \
            --remote-vnet crdb-westus --allow-vnet-access
        ```

        ```bash
        az network vnet peering create -g $rg -n westuseastuspeer --vnet-name crdb-westus \
            --remote-vnet crdb-eastus --allow-vnet-access
        ```

        ```bash
        az network vnet peering create -g $rg -n eastusnortheuropepeer --vnet-name crdb-eastus \
            --remote-vnet crdb-northeurope --allow-vnet-access
        ```

        ```bash
        az network vnet peering create -g $rg -n northeurpoeeastuspeer --vnet-name crdb-northeurope \
            --remote-vnet crdb-eastus --allow-vnet-access
        ```

        ```bash
        az network vnet peering create -g $rg -n westusnortheuropepeer --vnet-name crdb-westus \
            --remote-vnet crdb-northeurope --allow-vnet-access
        ```

        ```bash
        az network vnet peering create -g $rg -n northeuropewestuspeer --vnet-name crdb-northeurope \
            --remote-vnet crdb-westus --allow-vnet-access
        ```

- Create the Kubernetes clusters in each region
    - To get SubnetID

        ```bash
        az network vnet subnet list --resource-group $rg --vnet-name crdb-eastus
        az network vnet subnet list --resource-group $rg --vnet-name crdb-westus
        az network vnet subnet list --resource-group $rg --vnet-name crdb-northeurope
        ```

    - Create K8s Clusters in each region

        ```bash
        az aks create \
        --name $clus1 \
        --resource-group $rg \
        --network-plugin kubenet \
        --zones 1 2 3 \
        --vnet-subnet-id /subscriptions/eebc0b2a-9ff2-499c-9e75-1a32e8fe13b3/resourceGroups/crdb-aks-multi-region/providers/Microsoft.Network/virtualNetworks/crdb-eastus/subnets/crdb-eastus-sub1 \
        --node-count $n_nodes
        ```

        ```bash
        az aks create \
        --name $clus2 \
        --resource-group $rg \
        --network-plugin kubenet \
        --zones 1 2 3 \
        --vnet-subnet-id /subscriptions/eebc0b2a-9ff2-499c-9e75-1a32e8fe13b3/resourceGroups/crdb-aks-multi-region/providers/Microsoft.Network/virtualNetworks/crdb-westus/subnets/crdb-westus-sub1 \
        --node-count $n_nodes 

        ```

        ```bash
        az aks create \
        --name $clus3 \
        --resource-group $rg \
        --network-plugin kubenet \
        --zones 1 2 3 \
        --vnet-subnet-id /subscriptions/eebc0b2a-9ff2-499c-9e75-1a32e8fe13b3/resourceGroups/crdb-aks-multi-region/providers/Microsoft.Network/virtualNetworks/crdb-northeurope/subnets/crdb-northeurope-sub1 \
        --node-count $n_nodes 

        ```

    - To Configure Kubectl context use

        ```bash
        az aks get-credentials --name $clus1 --resource-group $rg
        ```

        ```bash
        az aks get-credentials --name $clus2 --resource-group $rg
        ```

        ```bash
        az aks get-credentials --name $clus3 --resource-group $rg
        ```

        - To switch contexts use

        ```bash
        kubectl config use-context crdb-aks-eastus
        kubectl config use-context crdb-aks-westus
        kubectl config use-context crdb-aks-northeurope
        ```

    - Test Network Connectivity

        ```bash
        #Set Context north EU
        kubectl config use-context crdb-aks-northeurope
        #Create a test pod to ping
        kubectl run network-test --image=alpine --restart=Never -- sleep 999999
        # Get Ip addresss of pod to ping
        kubectl describe pods 
        #Switch to Eastus context
        kubectl config use-context crdb-aks-eastus
        # Create a pod and ping the test pod
        kubectl run -it network-test --image=alpine --restart=Never -- ping <IPaddress>
        ```

    - Set up Load Balancers per Region

        ```bash
        kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/eks/dns-lb-eks.yaml --context crdb-aks-eastus
        ```

        ```bash
        kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/eks/dns-lb-eks.yaml --context crdb-aks-westus
        ```

        ```bash
        kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/eks/dns-lb-eks.yaml --context crdb-aks-northeurope
        ```