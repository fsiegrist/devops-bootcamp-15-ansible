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
- SSH into the new Droplet and
  - install Ansible: `apt update; apt install ansible`
  - install pip3 if not yet installed: `pip3; apt install python3-pip`
  - install Python modules 'boto3' and 'botocore' if not yet installed: `pip3 install boto3 botocore`
  - configure AWS credentials: `cd ~; mkdir .aws; cd .aws; vim credentials` and copy the content of your local `~/.aws/credentials` file

Now the ansible control node is ready to use a dynamic inventory of available AWS EC2 instances.

#### Steps to create 2 EC2 instances to be managed by Ansible
- Login to your [AWS Management Console](https://aws.amazon.com/de/console/) and create two new EC2 instances (Amazon Linux 2023 AMI, t2.micro, create a new ED25519 key-pair called ansible-jenkins, existing default security group of default VPC). Download the 'ansible-jenkins.pem' file with the private key needed by Ansible to connect to the instances.

#### Steps to write an Ansible Playbook, which configures 2 EC2 Instances


#### Steps to add ssh key file credentials in Jenkins for Control Node server and Managed Node servers


#### Steps to configure Jenkins to execute the Ansible Playbook on remote Ansible Control Node server
