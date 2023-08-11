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
Create a folder called `terraform` and copy the `main.tf` and `terraform.tfvars` files from the demo project #1 of Module 12-Terraform into this folder. Remove the line `user_data = file("entry-script.sh")` from the `resource "aws_instance" "myapp-server"` block in the `main.tf` file. We are going to use Ansible to install Docker. Also replace the AMI name filter `"amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"` in the `data "aws_ami" "latest-amazon-linux-image"` block with `"al2023-ami-*-kernel-6.1-x86_64"` to get the newer image containing a Python version compatible with the ssl requirements of the Ansible module 'community.docker.docker_login'. Finally adjust the value of the `my_ip` variable in the `terraform.tfvars` file.

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
# ec2_public_ip = "3.76.251.81"
```

Copy the IP address of the new EC2 instance from the output (3.76.251.81).


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
  3.76.251.81

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
# [WARNING]: Platform linux on host 3.76.251.81 is using the discovered Python interpreter at
# /usr/bin/python3.9, but future installation of another Python interpreter could change the
# meaning of that path. See https://docs.ansible.com/ansible-
# core/2.15/reference_appendices/interpreter_discovery.html for more information.
# ok: [3.76.251.81]
# 
# TASK [Install Docker] **************************************************************************
# changed: [3.76.251.81]
# 
# PLAY RECAP *************************************************************************************
# 3.76.251.81              : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

To get rid of the WARNING, either
- add `interpreter_python = /usr/bin/python3.9` to the `ansible.cfg` file
- or `ansible_python_interpreter=/usr/bin/python3.9` to the [docker_server:vars] section of the hosts file
- or 
  ```yaml
  vars:
    ansible_python_interpreter: /usr/bin/python3.9
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
- [pipe lookup](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/pipe_lookup.html)

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
# fatal: [3.76.251.81]: FAILED! => {"changed": false, "dest": "/usr/local/bin/docker-compose", "elapsed": 0, "gid": 0, "group": "root", "mode": "0755", "msg": "Request failed", "owner": "root", "response": "HTTP Error 404: Not Found", "size": 60470973, "state": "file", "status_code": 404, "uid": 0, "url": "https://github.com/docker/compose/releases/latest/download/docker-compose-Darwin-arm64"}
# ...
```

As we can see, the pipe-lookups were executed on my local machine (an M2 Mac) and thus resultet in the URL `https://github.com/docker/compose/releases/latest/download/docker-compose-Darwin-arm64` instead of `https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64` as required for the EC2 instance.

The documentation says:
```
Lookup plugins are an Ansible-specific extension to the [Jinja2](https://palletsprojects.com/p/jinja/) templating language. You can use lookup plugins to access data from outside sources (files, databases, key/value stores, APIs, and other services) within your playbooks. Like all templating, lookups execute and are evaluated on the Ansible control machine.
```

So we cannot make use of the pipe-lookup here and have to use the `shell` module to detect the architecture of the remote machine:
```yaml
- name: Install Docker Compose
  hosts: docker_server
  become: yes
  tasks:
    - name: Get architecture of remote machine
      shell: echo `uname -s`-`uname -m`
      register: remote_arch
    - name: Download and install Docker Compose
      get_url:
        url: https://github.com/docker/compose/releases/latest/download/docker-compose-{{ remote_arch.stdout }}
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

**Install required Python modules**\
Instead of executing Docker commands using the `command` module it is more convenient to make use of the modules provided by the [community.docker](https://docs.ansible.com/ansible/latest/collections/community/docker/index.html) collection.

However, because the modules of this collection internally use the Python docker module to execute Docker commands, we first have to make sure this Python module is installed on the remote machine. And because we want to start the containers using docker-compose, the Python docker-compose module needs to be installed too.

Check the documentation for the [pip](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/pip_module.html) module and add the following play to the 'deploy-docker.yaml' playbook:

```yaml
- name: Install pip3
  hosts: docker_server
  become: yes
  tasks:
    - name: Ensure pip3 is installed
      yum:
        name: python3-pip
        update_cache: yes
        state: present

- name: Install required Python modules
  hosts: docker_server
  tasks:
    - name: Install Python modules 'docker' and 'docker-compose'
      pip:
        name:
          - docker
          - docker-compose
```

If these modules are already installed on the remote machine, this step would not be necessary.

**Copy docker-compose file to server**\
We are going to reuse the docker-compose file of the 'bootcamp-java-mysql' project of the devops bootcamp module #07 (Docker). A slightly adjusted version looks like this:

```yaml
version: '3.9'
services:
  java-app:
    image: fsiegrist/fesi-repo:bootcamp-java-mysql-project-1.0
    environment:
      - DB_SERVER=mysql
      - DB_USER=user
      - DB_PWD=password
      - DB_NAME=my-db
    ports:
      - 8080:8080
    depends_on:
      - mysql
    restart: always
    container_name: bootcamp-java-mysql

  mysql:
    image: mysql:8.0.32
    ports:
      - 3306:3306
    environment:
      - MYSQL_ROOT_PASSWORD=secret-root-password
      - MYSQL_USER=user
      - MYSQL_PASSWORD=password
      - MYSQL_DATABASE=my-db
    volumes:
      - mysql-data:/var/lib/mysql
    container_name: mysql

  phpmyadmin:
    image: phpmyadmin:5.2.1
    ports:
      - 8081:80
    environment:
      - PMA_HOST=mysql # defines the host name of the MySQL server
                       # (= service name for containers running in the same Docker network)
      - PMA_PORT=3306
      - MYSQL_ROOT_PASSWORD=secret-root-password
    depends_on:
      - mysql
    restart: always
    container_name: phpmyadmin

volumes:
  mysql-data:
```

As you see, the Docker image of the application we want to run is `fsiegrist/fesi-repo:bootcamp-java-mysql-project-1.0`. Make sure this image is available in the private repository `fsiegrist/fesi-repo` on Docker-Hub. 

If it's not, go to the 'bootcamp-java-mysql' project in module #07, adjust the version in `build.gradle` and `Dockerfile`, make sure the host and port in `index.html` is 'localhost:8080', build the application using Gradle, build an amd64 image and push it to the repository using the following commands:
```sh
docker buildx create --use
docker login
docker buildx build --platform linux/amd64 -t fsiegrist/fesi-repo:bootcamp-java-mysql-project-1.0 --push .
```

Check the documentation for the following modules:
- [community.docker.docker_image](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_image_module.html)
- [community.docker.docker_login](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_login_module.html)
- [community.docker.docker_compose](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_compose_module.html)

Add the following play to the 'deploy-docker.yaml' playbook:
```yaml
- name: Start Docker containers
  hosts: docker_server
  # use a variables file holding the password for Docker login
  vars_files:
    - project-vars
  tasks:
    - name: Copy docker-compose.yaml
      copy:
        src: ../docker-compose.yaml
        dest: /home/ec2-user/docker-compose.yaml
    - name: Make sure a Docker login against the private registry on Docker Hub is established
      community.docker.docker_login:
        registry_url: https://index.docker.io/v1  # could be omitted, as Docker-Hub is the default registry if nothing is specified
        username: fsiegrist
        password: "{{ docker_password }}"
        state: present
    - name: Start containers from docker-compose file
      docker_compose:
        project_src: /home/ec2-user
        state: present
```

Add a file called `project-vars` with the following content to the `ansible` directory (replace '*******' with your Docker-Hub private registry password):
```yaml
docker_password: *******
```

If you don't want to store the password in a file, you can let Ansible prompt for user input during the playbook execution by replacing this

```yaml
  # use a variables file holding the password for Docker login
  vars_files:
    - project-vars
```

with this

```yaml
# prompt for user input during ansible playbook execution
  vars_prompt:
    - name: docker_password
      prompt: Enter the password for the private reigstry on Docker-Hub
```

See [playbook prompts](https://docs.ansible.com/ansible/latest/user_guide/playbooks_prompts.html).

Now we can run the whole playbook:

```sh
ansible-playbook deploy-docker.yaml

# PLAY [Install Docker] **************************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [3.76.251.81]
# 
# TASK [Ensure Docker is installed] **************************************************************
# ok: [3.76.251.81]
# 
# PLAY [Install Docker Compose] ******************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [3.76.251.81]
# 
# TASK [Get architecture of remote machine] ******************************************************
# changed: [3.76.251.81]
# 
# TASK [Download and install Docker Compose] *****************************************************
# ok: [3.76.251.81]
# 
# PLAY [Start Docker] ****************************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [3.76.251.81]
# 
# TASK [Ensure Docker daemon is started] *********************************************************
# ok: [3.76.251.81]
# 
# PLAY [Add ec2-user to docker group] ************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [3.76.251.81]
# 
# TASK [Add ec2-user to docker group] ************************************************************
# ok: [3.76.251.81]
# 
# TASK [Reset ssh connection to allow user changes to affect 'current login user'] ***************
# 
# PLAY [Install pip3] ****************************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [3.76.251.81]
# 
# TASK [Ensure pip3 is installed] ****************************************************************
# ok: [3.76.251.81]
# 
# PLAY [Install required Python modules] *********************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [3.76.251.81]
# 
# TASK [Install Python modules 'docker' and 'docker-compose'] ************************************
# ok: [3.76.251.81]
# 
# PLAY [Start Docker containers] *****************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [3.76.251.81]
# 
# TASK [Copy docker-compose.yaml] ****************************************************************
# ok: [3.76.251.81]
# 
# TASK [Make sure a Docker login against the private registry on Docker Hub is established] ******
# ok: [3.76.251.81]
# 
# TASK [Start containers from docker-compose file] ***********************************************
# changed: [3.76.251.81]
# 
# PLAY RECAP *************************************************************************************
# 3.76.251.81                : ok=17   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

To check whether the three containers are running, ssh into the server and do a `docker ps`:

```sh
ssh ec2-user@3.76.251.81
[ec2-user@ip-10-0-10-235 ~]$ docker ps
# CONTAINER ID   IMAGE                                                 COMMAND                  CREATED         STATUS         PORTS                                                  NAMES
# 75b7801f6ad4   fsiegrist/fesi-repo:bootcamp-java-mysql-project-1.0   "java -jar /opt/boot…"   6 minutes ago   Up 5 minutes   0.0.0.0:8080->8080/tcp, :::8080->8080/tcp              bootcamp-java-mysql
# c5f2c2996ee5   phpmyadmin:5.2.1                                      "/docker-entrypoint.…"   6 minutes ago   Up 6 minutes   0.0.0.0:8081->80/tcp, :::8081->80/tcp                  phpmyadmin
# c996607eb6d4   mysql:8.0.32                                          "docker-entrypoint.s…"   6 minutes ago   Up 6 minutes   0.0.0.0:3306->3306/tcp, :::3306->3306/tcp, 33060/tcp   mysql
```

You can also open the browser and navigate to [http://3.76.251.81:8080](http://3.76.251.81:8080/) to see the running application.
