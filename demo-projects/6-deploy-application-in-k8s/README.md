## Demo Project - Automate Kubernetes Deployment

### Topics of the Demo Project
Automate Kubernetes Deployment

### Technologies Used
- Ansible
- Terraform
- Kubernetes
- AWS EKS
- Python
- Linux

### Project Description
- Create EKS cluster with Terraform
- Write Ansible Play to deploy application in a new K8s namespace


#### Steps to create an EKS cluster with Terraform
Create a folder called `terraform` and copy the `eks-cluster.tf`, the `vpc.tf` and the `terraform.tfvars` files from the demo project #3 of Module 12-Terraform into this folder.

Then execute the following commands to provision the AWS EKS cluster:
```sh
cd terraform
terraform init
terraform apply --auto-approve
# ...
# Plan: 55 to add, 0 to change, 0 to destroy.
# ...
# module.eks.aws_eks_cluster.this[0]: Creation complete after 8m52s [id=myapp-eks-cluster]
# ...
# module.eks.module.eks_managed_node_group["dev"].aws_eks_node_group.this[0]: Creation complete after 1m59s [id=myapp-eks-cluster:dev-2023081821024258520000000f]
# 
# Apply complete! Resources: 55 added, 0 changed, 0 destroyed.
```

#### Steps to write an Ansible play to deploy an application in a new K8s namespace
**Step 1:** Create a new namespace in the EKS cluster\
Create a folder called `ansible` and a playbook file called `deploy-to-k8s.yaml` within that folder. For configuring k8s components we use the ansible module `kubernetes.core.k8s`. Check its [documentation](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_module.html) first.

The documentation lists the following requirements needed to use the module:
- python >= 3.6
- kubernetes >= 12.0.0
- PyYAML >= 3.11
- jsonpatch

So let's check these requirements:
```sh
python3 -V
# Python 3.11.4

python3 -c "import kubernetes"
# Traceback (most recent call last):
#   File "<string>", line 1, in <module>
# ModuleNotFoundError: No module named 'kubernetes'

pip install kubernetes  # see https://pypi.org/project/kubernetes/
# ...
# Successfully installed ... kubernetes-27.2.0 ...
pip list | grep kubernetes
# kubernetes         27.2.0

python3 -c "import yaml"  # see https://pyyaml.org/wiki/PyYAMLDocumentation
pip list | grep PyYAML
# PyYAML             6.0.1

python3 -c "import jsonpatch"
# Traceback (most recent call last):
#   File "<string>", line 1, in <module>
# ModuleNotFoundError: No module named 'jsonpatch'

pip install jsonpatch  # see https://pypi.org/project/jsonpatch/
# ...
# Successfully installed jsonpatch-1.33 ...
pip list | grep jsonpatch
# jsonpatch          1.33
```

Now add the following content to the playbook:
```yaml
- name: Deploy application to k8s in new namespace
  hosts: localhost  # <-- sic!
  tasks:
    - name: Create a k8s namespace
      kubernetes.core.k8s:
        kubeconfig: ~/.kube/config  # <-- sic! (could be omitted because it's the default location, or could be set via an Ansible environment variable named K8S_AUTH_KUBECONFIG)
        api_version: v1
        kind: Namespace
        name: ns-myapp
        state: present
```

The k8s module use the settings in the kubeconfig to directly connect to the k8s cluster and execute kubectl commands there. That's why we don't have to configure the IP address of the k8s cluster in an inventory. To create a kubeconfig file in `~/.kube`, execute the following aws cli commands:

```sh
# make sure your aws configuration is set to the region of the EKS cluster
aws configure list
#       Name                    Value             Type    Location
#       ----                    -----             ----    --------
#    profile                <not set>             None    None
# access_key     ****************BDVT shared-credentials-file    
# secret_key     ****************eXn0 shared-credentials-file    
#     region             eu-central-1      config-file    ~/.aws/config

# make sure there is no old ~/.kube/config file
rm ~/.kube/config
# or rename it to a backup
mv ~/.kube/config ~/.kube/config.backup

# now create a new ~/.kube/config file
aws eks update-kubeconfig --name myapp-eks-cluster
# Added new context arn:aws:eks:eu-central-1:369076538622:cluster/myapp-eks-cluster to ~/.kube/config

# check the connection
kubectl cluster-info
# Kubernetes control plane is running at https://270D50B8942EEAF943C6008C9D1F8AB6.sk1.eu-central-1.eks.amazonaws.com
# CoreDNS is running at https://270D50B8942EEAF943C6008C9D1F8AB6.sk1.eu-central-1.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Now run the playbook:
```sh
cd ansible
ansible-playbook deploy-to-k8s.yaml
# PLAY [Deploy application to k8s in new namespace] *********************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [localhost]
# 
# TASK [Create a k8s namespace] *****************************************************************************************************************
# changed: [localhost]
# 
# PLAY RECAP ************************************************************************************************************************************
# localhost                  : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

Check whether the namespace was created:
```sh
kubectl get ns
# NAME              STATUS   AGE
# default           Active   11m
# kube-node-lease   Active   11m
# kube-public       Active   11m
# kube-system       Active   11m
# ns-myapp          Active   108s  <--
```

**Step 2:** Deploy an application in the new namespace\
Create a `k8s` folder in the root directory of this demo project and copy the file `nginx.yaml` from the demo project #1 of Module 11 (Kubernetes-AWS-EKS) into this folder. It contains a simple deployment and service for running nginx in a Kubernetes cluster.

Then add the following task to the ansible playbook:
```yaml
    - name: Deploy nginx application
      kubernetes.core.k8s:
        src: ../k8s/nginx.yaml
        state: present
        kubeconfig: ~/.kube/config
        namespace: ns-myapp
```

Run the playbook:
```sh
ansible-playbook deploy-to-k8s.yaml
# PLAY [Deploy application to k8s in new namespace] *********************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [localhost]
# 
# TASK [Create a k8s namespace] *****************************************************************************************************************
# ok: [localhost]
# 
# TASK [Deploy nginx application] ***************************************************************************************************************
# changed: [localhost]
# 
# PLAY RECAP ************************************************************************************************************************************
# localhost                  : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

Check that the components are available:
```sh
kubectl get pod -n ns-myapp
# NAME                    READY   STATUS    RESTARTS   AGE
# nginx-55f598f8d-4wbtf   1/1     Running   0          25s

kubectl get svc -n ns-myapp
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP                                                                 PORT(S)        AGE
# nginx   LoadBalancer   172.20.47.155   ab9795411453644c4b1f3cf46d5f6a05-841880191.eu-central-1.elb.amazonaws.com   80:31780/TCP   41s
```

Open the browser and navigate to 'http://ab9795411453644c4b1f3cf46d5f6a05-841880191.eu-central-1.elb.amazonaws.com' to see the application.

To undeploy the compopnents, change the state `present` in the playbook to `absent`.

Don't forget to destroy the cluster using terraform when you're done.
