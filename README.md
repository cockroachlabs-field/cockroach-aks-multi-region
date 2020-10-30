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
        az network vnet create -g $rg -n crdb-$loc1 --address-prefix 20.0.0.0/16 \
            --subnet-name crdb-$loc1-sub1 --subnet-prefix 20.0.0.0/24
        ```

        ```bash
        az network vnet create -g $rg -n crdb-$loc2 --address-prefix 30.0.0.0/16 \
            --subnet-name crdb-$loc2-sub1 --subnet-prefix 30.0.0.0/24
        ```

        ```bash
        az network vnet create -g $rg -n crdb-$loc3 --address-prefix 40.0.0.0/24 \
            --subnet-name crdb-$loc3-sub1 --subnet-prefix 40.0.0.0/24
        ```

    - Peer the Vnets

        ```bash
        az network vnet peering create -g $rg -n $loc1-$loc2-peer --vnet-name crdb-$loc1 \
            --remote-vnet crdb-$loc2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc2-$loc3-peer --vnet-name crdb-$loc2 \
            --remote-vnet crdb-$loc3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc1-$loc3-peer --vnet-name crdb-$loc1 \
            --remote-vnet crdb-$loc3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc2-$loc1-peer --vnet-name crdb-$loc2 \
            --remote-vnet crdb-$loc1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc3-$loc2-peer --vnet-name crdb-$loc3 \
            --remote-vnet crdb-$loc2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc3-$loc1-peer --vnet-name crdb-$loc3 \
            --remote-vnet crdb-$loc1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

- Create the Kubernetes clusters in each region
    - To get SubnetID

        ```bash
        loc1subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc1 | jq -r '.[].id')
        loc2subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc2 | jq -r '.[].id')
        loc3subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc3 | jq -r '.[].id')
        ```

    - Create K8s Clusters in each region

        ```bash
        az aks create \
        --name $clus1 \
        --resource-group $rg \
        --network-plugin azure \
        --zones 1 2 3 \
        --vnet-subnet-id $loc1subid \
        --node-count $n_nodes
        ```

        ```bash
        az aks create \
        --name $clus2 \
        --resource-group $rg \
        --network-plugin azure \
        --zones 1 2 3 \
        --vnet-subnet-id $loc2subid \
        --node-count $n_nodes

        ```

        ```bash
        az aks create \
        --name $clus3 \
        --resource-group $rg \
        --network-plugin azure \
        --zones 1 2 3 \
        --vnet-subnet-id $loc3subid \
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

    7. Add Core DNS
            
        Each Kubernetes cluster has a [CoreDNS](https://coredns.io/) service that responds to DNS requests for pods in its region. CoreDNS can also forward DNS requests to pods in other regions.

        To enable traffic forwarding to CockroachDB pods in all 3 regions, you need to [modify the ConfigMap](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#coredns-configmap-options) for the CoreDNS Corefile in each region.

        1. Download and open our ConfigMap template `[configmap.yaml](https://github.com/cockroachdb/cockroach/blob/master/cloud/kubernetes/multiregion/eks/configmap.yaml)`: 

            ```bash
            curl -O https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/eks/configmap.yaml
            ```

        2. After [obtaining the IP addresses of the ingress load balancers in all 3 regions aks clusters, you can use this information to define a separate ConfigMap for each region. Each unique ConfigMap lists the forwarding addresses for the pods in the 2 other regions

            For each region, modify `configmap.yaml` by replacing:

            - `region2` and `region3` with the namespaces in which the CockroachDB pods will run in the other 2 regions.
            - `ip1`, `ip2`, and `ip3` with the IP addresses of the Network Load Balancers in the region, which you looked up in the previous step.

            You will end up with 3 different ConfigMaps. Give each ConfigMap a unique filename like `configmap-1.yaml`. An example of which can be found in this repository

        3. For each region, first back up the existing ConfigMap:  

            ```bash
            kubectl -n kube-system get configmap coredns -o yaml > <configmap-backup-name>
            ```

            Then apply the new ConfigMap:

            ```bash
            kubectl apply -f <configmap-name> --context <cluster-context>
            ```

        4. For each region, check that your CoreDNS settings were applied: 

            ```bash
            kubectl get -n kube-system cm/coredns --export -o yaml --context <cluster-context>
            ```

        8. Confirm that the CockroachDB pods in each cluster say `1/1` in the `READY` column - This could take a couple of minutes to propergate, indicating that they've successfully joined the cluster:    

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


        9. Create secure clients

        ```bash
        kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $loc1
        ```

        ```bash
        kubectl exec -it cockroachdb-client-secure -n $loc1 -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public
        ```

        10. Port forward the admin ui

        ```bash
        kubectl port-forward cockroachdb-0 8080 --context $clus1 --namespace $loc1
        ```
