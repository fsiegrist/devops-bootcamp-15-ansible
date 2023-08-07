## Demo Project - Ansible & Docker

### Topics of the Demo Project
Run Docker Applications

### Technologies Used
- Ansible
- AWS
- Docker
- Terraform
- Linux

### Project Description
- Create an AWS EC2 Instance with Terraform
- Write Ansible Playbook that installs necessary technologies like Docker and Docker Compose, copies docker-compose file to the server and starts the Docker containers configured inside the docker-compose file


#### Steps to create an AWS EC2 Instance with Terraform
Create a folder called `terraform` and copy the `main.tf` and `terraform.tfvars` files from the demo project #1 of Module 12-Terraform into this folder. Remove the line `user_data = file("entry-script.sh")` from the `resource "aws_instance" "myapp-server"` block in the `main.tf` file. We are going to use Ansible to install Docker. Also adjust the value of the `my_ip` variable in the `terraform.tfvars` file.

Then execute the following commands to provision the EC2 instance:
```sh
cd terraform
terraform init
terraform apply --auto-approve
# ...
# aws_key_pair.ssh-key: Creating...
# aws_vpc.myapp-vpc: Creating...
# aws_key_pair.ssh-key: Creation complete after 0s [id=server-key]
# aws_vpc.myapp-vpc: Creation complete after 2s [id=vpc-0bdb675ef3524714d]
# aws_internet_gateway.myapp-igw: Creating...
# aws_subnet.myapp-subnet-1: Creating...
# aws_default_security_group.default-sg: Creating...
# aws_subnet.myapp-subnet-1: Creation complete after 1s [id=subnet-04f5e68bb8b4b2b7d]
# aws_internet_gateway.myapp-igw: Creation complete after 1s [id=igw-0f187bb714e54d2f6]
# aws_default_route_table.main-rtb: Creating...
# aws_default_route_table.main-rtb: Creation complete after 0s [id=rtb-07cd779b57f1abe05]
# aws_default_security_group.default-sg: Creation complete after 2s [id=sg-0e278e42b6474e6c1]
# aws_instance.myapp-server: Creating...
# aws_instance.myapp-server: Still creating... [10s elapsed]
# aws_instance.myapp-server: Still creating... [20s elapsed]
# aws_instance.myapp-server: Creation complete after 22s [id=i-0d7cf818b3afcac37]
# 
# Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
# 
# Outputs:
# 
# ec2_public_ip = "18.193.113.84"
```

Copy the IP address of the new EC2 instance from the output (18.193.113.84).


#### Steps to write an Ansible Playbook that starts a Docker Container

**Preparations**
- Create an `ansible` folder
- Within that folder create a file called `ansible.cfg` with the following content:
  ```cfg
  [defaults]
  inventory=./hosts
  host_key_checking=False
  ```
- In the same folder create a file called `hosts` with the following content:
  ```
  [docker_server]
  18.193.113.84

  [docker_server:vars]
  ansible_ssh_private_key_file=~/.ssh/id_ed25519
  ansible_user=ec2-user
  ```
- Finally create an empty playbook file called `deploy-docker.yaml`

**Install Docker**\
Check the documentation for the following module:
- [yum](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yum_module.html)

Add the following content to the playbook 'deploy-docker.yaml':
```yaml
- name: Install Docker
  hosts: docker_server
  become: yes
  become_user: root  # could be omitted since it is the default as soon as 'become' is enabled
  tasks:
    - name: Install Docker
      yum:
        name: docker
        update_cache: yes
        state: present
```

Run the playbook created so far:
```sh
cd ansible
ansible-playbook deploy-docker.yaml
# PLAY [Install Docker] **************************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# [WARNING]: Platform linux on host 18.193.113.84 is using the discovered Python interpreter at
# /usr/bin/python3.7, but future installation of another Python interpreter could change the
# meaning of that path. See https://docs.ansible.com/ansible-
# core/2.15/reference_appendices/interpreter_discovery.html for more information.
# ok: [18.193.113.84]
# 
# TASK [Install Docker] **************************************************************************
# changed: [18.193.113.84]
# 
# PLAY RECAP *************************************************************************************
# 18.193.113.84              : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

To get rid of the WARNING, either
- add `interpreter_python = /usr/bin/python3.7` to the `ansible.cfg` file
- or `ansible_python_interpreter=/usr/bin/python3.7` to the [docker_server:vars] section of the hosts file
- or 
  ```yaml
  vars:
    ansible_python_interpreter: /usr/bin/python3.7
  ```
  to each task in the playbook.

The last option only makes sense to force the usage of python 2 if a module is used, which is only available for python 2.

**Install Docker-Compose**\
To install docker-compose on an EC2 instance we would have to execute the following commands:
```sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

Check the documentation of 
- [lookups](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_lookups.html)
- [lookup plugins](https://docs.ansible.com/ansible/latest/plugins/lookup.html)

Add the following content to the playbook 'deploy-docker.yaml':
```yaml
- name: Intall Docker Compose
  hosts: docker_server
  tasks:
    - name: Ensure Docker is installed
      get_url:
        url: https://github.com/docker/compose/releases/latest/download/docker-compose-{{ lookup('pipe', 'uname -s') }}-{{ lookup('pipe', 'uname -m') }}
        dest: /usr/local/bin/docker-compose
        mode: +x
```

Lookup plugins are an Ansible specific extension to the Jinja2 templating language. They allow Ansible to access data from outside sources. Pipe is such a lookup plugin which calculates the output of a shell command and pipes it to theleft side of your lookup.

Execute the following commands to list all lookup plugins and the documentation of the pipe lookup:
```sh
ansible-doc -t lookup -l
ansible-doc -t lookup pipe
```

Run the playbook again:
```sh
ansible-playbook deploy-docker.yaml
# ...
# TASK [Intall Docker Compose] *******************************************************************
# fatal: [18.193.113.84]: FAILED! => {"changed": false, "dest": "/usr/local/bin/docker-compose", "elapsed": 0, "gid": 0, "group": "root", "mode": "0755", "msg": "Request failed", "owner": "root", "response": "HTTP Error 404: Not Found", "size": 60470973, "state": "file", "status_code": 404, "uid": 0, "url": "https://github.com/docker/compose/releases/latest/download/docker-compose-Darwin-arm64"}
# ...
```

As we can see, the pipe-lookups were executed on my local machine (an M2 Mac) and thus resultet in the URL `https://github.com/docker/compose/releases/latest/download/docker-compose-Darwin-arm64` instead of `https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64` as required for the EC2 instance.

The documentation says:
```
Lookup plugins are an Ansible-specific extension to the Jinja2 templating language. You can use lookup plugins to access data from outside sources (files, databases, key/value stores, APIs, and other services) within your playbooks. Like all templating, lookups execute and are evaluated on the Ansible control machine.
```

So we cannot make use of the pipe-lookup here and have to hardcode the URL:
```yaml
- name: Intall Docker Compose
  hosts: docker_server
  become: yes
  tasks:
    - name: Intall Docker Compose
      get_url:
        url: https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64
        dest: /usr/local/bin/docker-compose
        mode: +x
```

**Start docker daemon**\
Check the documentation for the following module:
- [systemd](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/systemd_service_module.html).

Add the following content to the playbook 'deploy-docker.yaml':
```yaml
- name: Start Docker
  hosts: docker_server
  become: yes
  tasks:
    - name: Ensure Docker daemon is started
      systemd:
        name: docker
        state: started
```

**Add ec2-user to the docker group**\
Check the documentation for the following modules:
- [user](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html)
- [meta](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/meta_module.html)

Add the following content to the playbook 'deploy-docker.yaml':
```yaml
- name: Add ec2-user to docker group
  hosts: docker_server
  become: yes
  tasks:
    - name: Add ec2-user to docker group
      user:
        name: ec2-user
        groups: docker
        append: yes
    - name: Reset ssh connection to allow user changes to affect 'current login user'
      meta: reset_connection
```