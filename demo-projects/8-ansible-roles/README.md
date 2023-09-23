## Demo Project - Ansible Roles

### Topics of the Demo Project
Structure Playbooks with Ansible Roles

### Technologies Used
- Ansible
- Docker
- Terraform
- AWS
- Linux

### Project Description
- Create an AWS EC2 Instance with Terraform
- Break up large Ansible Playbooks into smaller manageable files using Ansible Roles

#### Steps to create an AWS EC2 Instance with Terraform
Create a folder called `terraform` and copy the `main.tf` and `terraform.tfvars` files from the [demo project 3](../3-run-docker-applications/terraform/) into this folder. Because we are going to use a dynamic inventory we have to enable DNS hostnames, so adjust the "aws_vpc.myapp-vpc" resource block as follows:
```conf
resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true   # <--
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}
```
Also adjust the value of the `my_ip` variable in the `terraform.tfvars` file, if necessary.

Then execute the following commands to provision the EC2 instance:
```sh
cd terraform
terraform init
terraform apply --auto-approve
# ...
# aws_key_pair.ssh-key: Creating...
# aws_vpc.myapp-vpc: Creating...
# aws_key_pair.ssh-key: Creation complete after 0s [id=server-key]
# aws_vpc.myapp-vpc: Still creating... [10s elapsed]
# aws_vpc.myapp-vpc: Creation complete after 11s [id=vpc-06db5f4f18bf67935]
# aws_internet_gateway.myapp-igw: Creating...
# aws_subnet.myapp-subnet-1: Creating...
# aws_default_security_group.default-sg: Creating...
# aws_internet_gateway.myapp-igw: Creation complete after 1s [id=igw-0a95341b6cbcf6a7c]
# aws_default_route_table.main-rtb: Creating...
# aws_subnet.myapp-subnet-1: Creation complete after 1s [id=subnet-0655c717ed2af9782]
# aws_default_route_table.main-rtb: Creation complete after 0s [id=rtb-02ce4ad26960d0a16]
# aws_default_security_group.default-sg: Creation complete after 2s [id=sg-07333fc3c632135cb]
# aws_instance.myapp-server: Creating...
# aws_instance.myapp-server: Still creating... [10s elapsed]
# aws_instance.myapp-server: Still creating... [20s elapsed]
# aws_instance.myapp-server: Still creating... [30s elapsed]
# aws_instance.myapp-server: Creation complete after 32s [id=i-03b0d772272c1fcef]
# 
# Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
# 
# Outputs:
# 
# ec2_public_ip = "52.59.163.201"
```

Copy the IP address of the new EC2 instance from the output (52.59.163.201).


#### Steps to break up large Ansible Playbooks into smaller manageable files using Ansible Roles
We are going to break up the following [playbook](./ansible/deploy-docker-original.yaml) into smaller files using roles:

_ansible/deploy-docker-original.yaml_
```yaml
- name: Install Docker and Docker Compose. Start Docker. Install pip3.
  hosts: aws_ec2
  become: yes
  tasks:
    - name: Ensure Docker is installed
      yum:
        name: docker
        update_cache: yes
        state: present
    - name: Get architecture of remote machine
      shell: echo `uname -s`-`uname -m`
      register: remote_arch
    - name: Download and install Docker Compose
      get_url:
        url: https://github.com/docker/compose/releases/latest/download/docker-compose-{{ remote_arch.stdout }}
        dest: /usr/local/bin/docker-compose
        mode: +x
    - name: Ensure Docker daemon is started
      systemd:
        name: docker
        state: started
    - name: Ensure pip3 is installed
      yum:
        name: python3-pip
        update_cache: yes
        state: present


- name: Create new Linux user fesi.
  hosts: aws_ec2
  become: yes
  tasks: 
    - name: Create new user fesi
      user:
        name: fesi
        groups: adm,docker
    - name: Create ansible tmp directory
      file:
        path: /home/fesi/.ansible/tmp
        state: directory
        mode: '0777'


- name: Start Docker containers (as user fesi).
  hosts: aws_ec2
  become: yes
  become_user: fesi
  vars_files:
    - project-vars
  tasks:
    - name: Install Python modules 'docker' and 'docker-compose'
      pip:
        name:
          - docker
          - docker-compose
    - name: Copy docker-compose.yaml
      copy:
        src: ../docker-compose.yaml
        dest: /home/fesi/docker-compose.yaml
    - name: Make sure a Docker login against the private registry on Docker Hub is established
      community.docker.docker_login:
        registry_url: https://index.docker.io/v1
        username: fsiegrist
        password: "{{ docker_password }}"
        state: present
    - name: Start containers from docker-compose file
      community.docker.docker_compose:
        project_src: /home/fesi
        state: present
```

It contains three plays that
- install Docker and Docker Compose, start Docker, install pip3 (as root user)
- create a new Linux user 'fesi' and a temp directory used by Ansible to store files in the fesi user's home directory (as root user)
- install Python Docker modules, copy the docker-compose file into the fesi user's home directory, login on Docker Hub, and start the Docker containers from the docker-compose file (as fesi user).

The [ansible.cfg](./ansible/ansible.cfg) file looks like this:
```conf
[defaults]
host_key_checking = False
interpreter_python = /usr/bin/python3.9
enable_plugins = amazon.aws.aws_ec2  # <-- needed for dynamic inventory
inventory = inventory_aws_ec2.yaml   # <-- dynamic inventory config
remote_user = ec2-user
private_key_file = ~/.ssh/id_ed25519
allow_world_readable_tmpfiles = True # <-- needed to share files between ec2-user and fesi user
```

Ansible modules are executed on the remote machine by first substituting the parameters into the module file, then copying the file to the remote machine, and finally executing it there. Everything is fine if the module file is executed without using `become`, when the `become_user` is root, or when the connection to the remote machine is made as root. In these cases Ansible creates the module file with permissions that only allow reading by the user and root, or only allow reading by the unprivileged user being switched to.

However, when both the connection user and the become_user are unprivileged (this is the case in the third play, when Ansible connects as `ec2-user` and then becomes `fesi` to execute the tasks of the play), the module file is written as the user that Ansible connects as (`ec2-user`), but the file needs to be readable by the user Ansible is set to become (`fesi`). The details of how Ansible solves this can vary based on platform.

A possible solution mentioned [here](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_privilege_escalation.html#risks-of-becoming-an-unprivileged-user) is, to let both users be member of a common group and specify this group via the attribute `ansible_common_remote_group`. As both users, ec2-user and fesi, belong to the group `adm`, I configured `ansible_common_remote_group = adm`. Unfortunately this didn't solve the problem. So I decided to set `allow_world_readable_tmpfiles = True` which finally worked but is considered insecure.

Now let's break up the above playbook using Ansible roles. We leave the first play as it is. It is specific for EC2 servers and might not be reusable. But the second and third play are independent from the server type and are good canidates for roles. Adjust the playbook as [follows](./ansible/deploy-docker-with-roles.yaml):

_ansible/deploy-docker-with-roles.yaml_
```yaml
- name: Install Docker and Docker Compose. Start Docker. Install pip3.
  hosts: aws_ec2
  become: yes
  tasks:
    - name: Ensure Docker is installed
      ...


- name: Create new Linux user fesi.
  hosts: aws_ec2
  become: yes
  vars:
    user_groups: adm,docker
  roles: 
    - create_user  # <--


- name: Start Docker containers (as user fesi).
  hosts: aws_ec2
  become: yes
  become_user: fesi
  vars_files:
    - project-vars
  roles:
    - install_python_docker_modules  # <-- we put this task in its own role as it can be used independently from the tasks to start the containers
    - start_containers  # <--
```

Now let's create the directory and file structure for the three roles referenced in the playbook:

```txt
ansible/
  roles/
    create_user/
      defaults/
        main.yaml
      tasks/
        main.yaml
    install_python_docker_modules/
      tasks/
        main.yaml
    start_containers/
      defaults/
        main.yaml
      files/
        docker-compose.yaml
      tasks/
        main.yaml
      vars/
        main.yaml
```

Then move the tasks from the original playbook to the `main.yaml` file in the `tasks` folder of the respective role:

_ansible/roles/create_user/tasks/main.yaml_
```yaml
- name: Create new user fesi
  user:
    name: fesi
    groups: "{{ user_groups }}"  # <-- replace the hardcoded "groups: adm,docker" of the original playbook with a variable; the variable is defined in the new playbook -> user_groups: adm,docker (in the vars section)
- name: Create ansible tmp directory
  file:
    path: /home/fesi/.ansible/tmp
    state: directory
    mode: '0777'
```

_ansible/roles/install_python_docker_modules/tasks/main.yaml_
```yaml
- name: Install Python modules 'docker' and 'docker-compose'
  pip:
    name:
      - docker
      - docker-compose
```

_ansible/roles/start_containers/tasks/main.yaml_
```yaml
- name: Copy docker-compose.yaml
  copy:
    src: docker-compose.yaml  # <-- Ansible is looking up static files in the 'files' subdirectory of a role
    dest: /home/fesi/docker-compose.yaml
- name: Make sure a Docker login against the private registry on Docker Hub is established
  community.docker.docker_login:
    registry_url: "{{ docker_registry }}"  # <-- introduce a variable for the docker registry (default defined in defaults/main.yaml, overwritten in vars/main.yaml)
    username: "{{ docker_username }}"      # <-- introduce a variable for the docker username (default defined in defaults/main.yaml, overwritten in vars/main.yaml)
    password: "{{ docker_password }}"      # <-- still use the variable for the docker password (defined in project-vars)
    state: present
- name: Start containers from docker-compose file
  community.docker.docker_compose:
    project_src: /home/fesi
    state: present
```

Define the variables of the `start_containers` role:

_ansible/roles/start_containers/defaults/main.yaml_
```yaml
docker_registry: https://aws_account_id.dkr.ecr.region.amazonaws.com.
docker_username: AWS
```

_ansible/roles/start_containers/vars/main.yaml_
```yaml
docker_registry: https://index.docker.io/v1/
docker_username: fsiegrist
```

Add the `docker-compose.yaml` file to the _ansible/roles/start_containers/files/_ directory.

That's it. Now we're ready to execute the new Ansible playbook using roles:

```sh
cd ansible
ansible-playbook docker-deploy-with-roles.yaml
#
# PLAY [Install Docker and Docker Compose. Start Docker. Install pip3.] *********************************************************
# 
# TASK [Gathering Facts] ********************************************************************************************************
# ok: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [Ensure Docker is installed] *********************************************************************************************
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [Get architecture of remote machine] *************************************************************************************
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [Download and install Docker Compose] ************************************************************************************
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [Ensure Docker daemon is started] ****************************************************************************************
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [Ensure pip3 is installed] ***********************************************************************************************
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Create new Linux user fesi.] ********************************************************************************************
# 
# TASK [Gathering Facts] ********************************************************************************************************
# ok: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [create_user : Create new user fesi] *************************************************************************************
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [create_user : Create ansible tmp directory] *****************************************************************************
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Start Docker containers (as user fesi).] ********************************************************************************
# 
# TASK [Gathering Facts] ********************************************************************************************************
# [WARNING]: Using world-readable permissions for temporary files Ansible needs to create when becoming an unprivileged user.
# This may be insecure. For information on securing this, see https://docs.ansible.com/ansible-
# core/2.15/user_guide/become.html#risks-of-becoming-an-unprivileged-user
# ok: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [install_python_docker_modules : Install Python modules 'docker' and 'docker-compose'] ***********************************
# [WARNING]: Using world-readable permissions for temporary files Ansible needs to create when becoming an unprivileged user.
# ...
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [start_containers : Copy docker-compose.yaml] ****************************************************************************
# [WARNING]: Using world-readable permissions for temporary files Ansible needs to create when becoming an unprivileged user.
# ...
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [start_containers : Make sure a Docker login against the private registry on Docker Hub is established] ******************
# [WARNING]: Using world-readable permissions for temporary files Ansible needs to create when becoming an unprivileged user.
# ...
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# TASK [start_containers : Start containers from docker-compose file] ***********************************************************
# [WARNING]: Using world-readable permissions for temporary files Ansible needs to create when becoming an unprivileged user.
# ...
# changed: [ec2-52-59-163-201.eu-central-1.compute.amazonaws.com]
# 
# PLAY RECAP ********************************************************************************************************************
# ec2-52-59-163-201.eu-central-1.compute.amazonaws.com : ok=14   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

You see that the output contains the role-name if a task was part of a role. Further you see WARNINGs concerning the usage of the `allow_world_readable_tmpfiles` attribute because this is a security issue. They are emitted for all tasks executed as user fesi.

Don't forget to cleanup the EC2 instance (using `terraform destroy`) when you're done.
