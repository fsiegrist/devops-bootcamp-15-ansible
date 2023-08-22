## Demo Project - Ansible Integration in Jenkins

### Topics of the Demo Project
Run Ansible from Jenkins pipeline

### Technologies Used
- Ansible
- Jenkins
- DigitalOcean
- AWS
- Boto3
- Docker
- Java
- Maven
- Linux
- Git

### Project Description
- Create and configure a dedicated server for Jenkins
- Create and configure a dedicated server for Ansible Control Node
- Create 2 EC2 instances to be managed by Ansible
- Write Ansible Playbook, which configures 2 EC2 instances
- Add ssh key file credentials in Jenkins for Ansible Control Node server and Ansible Managed Node servers
- Configure Jenkins to execute the Ansible Playbook on remote Ansible Control Node server as part of the CI/CD pipeline
- So the Jenkinsfile configuration will do the following:
  - a. Connect to the remote Ansible Control Node server
  - b. Copy Ansible playbook and configuration files to the remote Ansible Control Node server
  - c. Copy the ssh keys for the Ansible Managed Node servers to the Ansible Control Node server 
  - d. Install Ansible, Python3 and Boto3 on the Ansible Control Node server
  - e. With everything installed and copied to the remote Ansible Control Node server, execute the
  playbook remotely on that Control Node that will configure the 2 EC2 Managed Nodes


#### Steps to create and configure a dedicated server for Jenkins
We're gonna reuse the same Jenkins server we already used in a couple of other demo projects (the one we created in module 8 on a DigitalOcean droplet).

#### Steps to create and configure a dedicated server for Ansible Control Node
- Login to your [DigitalOcean account](https://cloud.digitalocean.com/login) and create a new Droplet (Frankfurt, Ubuntu 22.04, Shared CPU Basic, Regular Disk Type SSD, 2GB / 2CPU / 60GB SSD) and give it the hostname 'ansible-control-node'.
- SSH into the new Droplet (IP 104.248.19.107) and
  - install Ansible
  - install pip3 if not yet installed
  - install Python modules 'boto3' and 'botocore' if not yet installed
  - configure AWS credentials

```sh
ssh root@104.248.19.107

# install Ansible
apt update
apt install ansible

# install pip3 if not yet installed
pip3
# Command 'pip3' not found, but can be installed with:
# apt install python3-pip
apt install python3-pip

# install Python modules 'boto3' and 'botocore' if not yet installed
pip3 install boto3 botocore

# configure AWS credentials: create ~/.aws directory
pwd
# /root
mkdir .aws

exit

# copy the aws credentials to the newly created directory
scp ~/.aws/credentials root@104.248.19.107:/root/.aws/credentials
```

Now the ansible control node is ready to use a dynamic inventory of available AWS EC2 instances.

#### Steps to create 2 EC2 instances to be managed by Ansible
- Login to your [AWS Management Console](https://aws.amazon.com/de/console/) and create two new EC2 instances (Amazon Linux 2023 AMI, t2.micro, create a new RSA key-pair called 'ansible-jenkins', existing default security group of default VPC). The 'ansible-jenkins.pem' file with the private key needed by Ansible to connect to the instances is downloaded automatically. Make sure the used security group allows for ssh connections from any IP address (or from the Ansible Control Node's IP address, if this is a stable address.)

#### Steps to write an Ansible Playbook, which configures 2 EC2 Instances
Switch to the sample application 'java-maven-app' and create a new branch 'feature/ansible'. Create a new folder called 'ansible' in the root directory of the project. Add the following three files to this 'ansible' folder:

_ansible.cfg_ (see ansible.cfg from demo project #5)
```config
[defaults]
host_key_checking = False
interpreter_python = /usr/bin/python3

enable_plugins = amazon.aws.aws_ec2
inventory = inventory_aws_ec2.yaml

remote_user = ec2-user
private_key_file = ~/ssh-key.pem  # the private key to connect to the EC2 instances
```

*inventory_aws_ec2.yaml* (see inventory_aws_ec2.yaml from demo project #5)
```yaml
plugin: aws_ec2
regions:
  - eu-central-1
```

_my-playbook.yaml_ (see deploy-docker.yaml from demo project #5)
```yaml
- name: Install Docker
  hosts: aws_ec2
  become: yes
  tasks:
    - name: Ensure Docker is installed
      yum:
        name: docker
        update_cache: yes
        state: present

- name: Install Docker Compose
  hosts: aws_ec2
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

- name: Start Docker
  hosts: aws_ec2
  become: yes
  tasks:
    - name: Ensure Docker daemon is started
      systemd:
        name: docker
        state: started

- name: Add ec2-user to docker group
  hosts: aws_ec2
  become: yes
  tasks:
    - name: Add ec2-user to docker group
      user:
        name: ec2-user
        groups: docker
        append: yes
    - name: Reset ssh connection to allow user changes to affect 'current login user'
      meta: reset_connection

- name: Install pip3
  hosts: aws_ec2
  become: yes
  tasks:
    - name: Ensure pip3 is installed
      yum:
        name: python3-pip
        update_cache: yes
        state: present

- name: Install required Python modules
  hosts: aws_ec2
  tasks:
    - name: Install Python modules 'docker' and 'docker-compose'
      pip:
        name:
          - docker
          - docker-compose
```

In the Jenkins pipeline we are going to copy these files to the Ansible Control Node and execute the playbook from there.

#### Steps to add ssh key file credentials in Jenkins for Control Node server and Managed Node servers
In order to enable Jenkins to ssh into the Ansible Control Node, we need to configure the according credentials in Jenkins. And since Ansible is going to connect to the EC2 instances using the private key located at `~/ssh-key.pem` on the Control Node (see _ansible.cfg_), this private key file must be copied to the Control Node too and must therefore also be available on the Jenkins server.

The Jenkins plugin `sshagent` requires the private key to be in the legacy PEM format. Our private key file is in the newer ED25519 format. So we have to convert it before we can use it in Jenkins. To do that, execute the following commands:

```sh
cp ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.backup
ssh-keygen -p -f ~/.ssh/id_ed25519 -m pem -P "" -N ""
```

Login to the Jenkins management console, navigate to 'Dashboard' > 'Manage Jenkins' > 'Manage Credentials' > '(global)', press "+ Add Credentials", select the kind "SSH Username with private key", enter the ID "ansible-server-key", enter the Username "root", select "Private Key" > "Enter directly", press "Add" and paste the value of the converted `id_ed25519` file into the text area. Press "Create".

Now we have to make the private key for connecting to the EC2 instances available in Jenkins too. So again navigate to 'Dashboard' > 'Manage Jenkins' > 'Manage Credentials' > '(global)', press "+ Add Credentials", select the kind "SSH Username with private key", enter the ID "ansible-ec2-server-key", enter the Username "ec2-user", select "Private Key" > "Enter directly", press "Add" and paste the value of the downloaded `ansible-jenkins.pem` file into the text area. Press "Create".


#### Steps to configure Jenkins to execute the Ansible Playbook on remote Ansible Control Node server
Copying files from Jenkins to the Ansible control node can be done using the already installed `sshagent` plugin. But in order to run the playbook on the control node, we have to execute a command (`ansible-playbook my-playbook.yaml`) on the control node. This can be done using the Jenkins plugin "SSH Pipline Steps" (see the [documentation](https://plugins.jenkins.io/ssh-steps/)). To install that plugin navigate to 'Dashboard' > 'Manage Jenkins' > 'Manage Plugins' > 'Available plugins', type "ssh pipeline steps", check the plugin and install it.

Now we are ready to write the pipeline. Switch back to the sample application 'java-maven-app', open the Jenkinsfile and replace its content with the following:
```groovy
#!/usr/bin/env groovy

pipeline {
    agent any
    environment {
        ANSIBLE_SERVER = "104.248.19.107"
    }
    stages {
        stage("copy files to ansible server") {
            steps {
                script {
                    echo "copying all neccessary files to ansible control node"
                    sshagent(['ansible-server-key']) {
                        sh "scp -o StrictHostKeyChecking=no ansible/* root@${ANSIBLE_SERVER}:/root"

                        withCredentials([sshUserPrivateKey(credentialsId: 'ansible-ec2-server-key', keyFileVariable: 'keyfile', usernameVariable: 'user')]) {
                            sh 'scp $keyfile root@$ANSIBLE_SERVER:/root/ssh-key.pem'
                        }
                    }
                }
            }
        }
        stage("execute ansible playbook") {
            steps {
                script {
                    echo "calling ansible playbook to configure ec2 instances"
                    def remote = [:]
                    remote.name = "ansible-server"
                    remote.host = ANSIBLE_SERVER
                    remote.allowAnyHosts = true

                    withCredentials([sshUserPrivateKey(credentialsId: 'ansible-server-key', keyFileVariable: 'keyfile', usernameVariable: 'user')]){
                        remote.user = user
                        remote.identityFile = keyfile
                        // sshScript remote: remote, script: "prepare-ansible-server.sh"
                        sshCommand remote: remote, command: "ansible-playbook my-playbook.yaml"
                    }

                    // or using sshagent
                    // sshagent(['ansible-server-key']) {
                    //     sh 'ssh root@$ANSIBLE_SERVER "ansible-playbook my-playbook.yaml"'
                    // }
                }
            }
        }
    }   
}
```

As an optional step, we added the execution of a script called 'prepare-ansible-server.sh' before running the playbook. This script contains the commands to install the necessary tools on the Ansible control node. This may be useful, if a new control node instance is often created and we don't want to always install the required tools manually. If you want to use that optional step, add the following script to the root of the project:

_prepare-ansible-server.sh_
```sh
#!/usr/bin/env bash

apt update
apt install ansible -y
apt install python3-pip -y
pip3 install boto3 botocore
```

To make this work, we would also have to add a step to copy the AWS credentials to the new instance. So this is just meant to demonstrate, how it would be possible to execute whole scripts on the remote server.

Now it's time to run the pipeline. Commit the new files and changes in the sample application 'java-maven-app' to the new branch 'feature/ansible' and push it to the Git repository. If the multibranch pipeline in Jenkins is still configured to run pipeline builds automatically when changes are pushed, a new pipeline for the branch will be created and started.

