# AKS - Multi Region cockroachDB

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
        --network-plugin azure \
        --zones 1 2 3 \
        --vnet-subnet-id /subscriptions/eebc0b2a-9ff2-499c-9e75-1a32e8fe13b3/resourceGroups/crdb-aks-multi-region/providers/Microsoft.Network/virtualNetworks/crdb-eastus/subnets/crdb-eastus-sub1 \
        --node-count $n_nodes
        ```

        ```bash
        az aks create \
        --name $clus2 \
        --resource-group $rg \
        --network-plugin azure \
        --zones 1 2 3 \
        --vnet-subnet-id /subscriptions/eebc0b2a-9ff2-499c-9e75-1a32e8fe13b3/resourceGroups/crdb-aks-multi-region/providers/Microsoft.Network/virtualNetworks/crdb-westus/subnets/crdb-westus-sub1 \
        --node-count $n_nodes 

        ```

        ```bash
        az aks create \
        --name $clus3 \
        --resource-group $rg \
        --network-plugin azure \
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
        kubectl run -it network-test --image=alpine --restart=Never -- ping 40.0.0.4
        ```

    - Download and Configue the Scripts to deploy cockroachdb
        1. Create a directory and download the required script and configuration files into it:   

            ```bash
            mkdir multiregion
            ```

            ```bash
            cd multiregion
            ```

            ```bash
            curl -OOOOOOOOO \
            https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/{README.md,client-secure.yaml,cluster-init-secure.yaml,cockroachdb-statefulset-secure.yaml,dns-lb.yaml,example-app-secure.yaml,external-name-svc.yaml,setup.py,teardown.py}
            ```

        2. Retrieve the `kubectl` "contexts" for your clusters: 

            ```bash
            kubectl config get-contexts
            ```

            At the top of the `setup.py` script, fill in the `contexts` map with the zones of your clusters and their "context" names, e.g.:

            > `context = { 'us-east1-b': 'gke_cockroach-shared_us-east1-b_cockroachdb1', 'us-west1-a': 'gke_cockroach-shared_us-west1-a_cockroachdb2', 'us-central1-a': 'gke_cockroach-shared_us-central1-a_cockroachdb3',
            }`

        3. In the `setup.py` script, fill in the `regions` map with the zones and corresponding regions of your clusters, for example:

            > `$ regions = { 'us-east1-b': 'us-east1', 'us-west1-a': 'us-west1', 'us-central1-a': 'us-central1',
            }`

            Setting `regions` is optional, but recommended, because it improves CockroachDB's ability to diversify data placement if you use more than one zone in the same region. If you aren't specifying regions, just leave the map empty.

        4. If you haven't already, [install CockroachDB locally and add it to your `PATH`](https://www.cockroachlabs.com/docs/v20.1/install-cockroachdb). The `cockroach` binary will be used to generate certificates.

            If the `cockroach` binary is not on your `PATH`, in the `setup.py` script, set the `cockroach_path` variable to the path to the binary.

        5. Optionally, to optimize your deployment for better performance, review [CockroachDB Performance on Kubernetes](https://www.cockroachlabs.com/docs/v20.1/kubernetes-performance) and make the desired modifications to the `cockroachdb-statefulset-secure.yaml` file.
        6. Run the `setup.py` script: 

            ```bash
            python setup.py
            ```

            As the script creates various resources and creates and initializes the CockroachDB cluster, you'll see a lot of output, eventually ending with `job "cluster-init-secure" created`.

        7. Confirm that the CockroachDB pods in each cluster say `1/1` in the `READY` column, indicating that they've successfully joined the cluster:    

            ```bash
            kubectl get pods --selector app=cockroachdb --all-namespaces --context <cluster-context-1>
            ```

            > `NAMESPACE NAME READY STATUS RESTARTS AGE
            us-east1-b cockroachdb-0 1/1 Running 0 14m
            us-east1-b cockroachdb-1 1/1 Running 0 14m
            us-east1-b cockroachdb-2 1/1 Running 0 14m`

            ```bash
            kubectl get pods --selector app=cockroachdb --all-namespaces --context <cluster-context-2>
            ```

            > `NAMESPACE NAME READY STATUS RESTARTS AGE
            us-central1-a cockroachdb-0 1/1 Running 0 14m
            us-central1-a cockroachdb-1 1/1 Running 0 14m
            us-central1-a cockroachdb-2 1/1 Running 0 14m`

            ```bash
            kubectl get pods --selector app=cockroachdb --all-namespaces --context <cluster-context-3>
            ```

            > `NAMESPACE NAME READY STATUS RESTARTS AGE
            us-west1-a cockroachdb-0 1/1 Running 0 14m
            us-west1-a cockroachdb-1 1/1 Running 0 14m
            us-west1-a cockroachdb-2 1/1 Running 0 14m`

            If you notice that only one of the Kubernetes clusters' pods are marked as `READY`, you likely also need to configure a network firewall rule that will allow the pods in the different clusters to talk to each other. You can run the following command to create a firewall rule allowing traffic on port 26257 (the port used by CockroachDB for inter-node traffic) within your private GCE network. It will not allow any traffic in from outside your private network:

            ```bash
            az network nsg create --name cockroach-internal \
            --resource-group $rg
            ```

            ```bash
            az network nsg rule create -g $rg --nsg-name cockroach-internal -n SQLports --priority 100 \
            --source-address-prefixes 20.0.0.0/24 30.0.0.0/24 40.0.0.0/24 --source-port-ranges 26257 \
            --destination-address-prefixes '*' --destination-port-ranges 26257 --access Allow \
            --protocol Tcp --description "Allow internal cockroach Traffic"
            ```

            ```bash
            az network vnet subnet update -g $rg -n crdb-eastus-sub1 --vnet-name crdb-eastus --network-security-group cockroach-internal

            az network vnet subnet update -g $rg -n crdb-westus-sub1 --vnet-name crdb-westus --network-security-group cockroach-internal

            az network vnet subnet update -g $rg -n crdb-northeurope-sub1 --vnet-name crdb-northeurope --network-security-group cockroach-internal
            ```