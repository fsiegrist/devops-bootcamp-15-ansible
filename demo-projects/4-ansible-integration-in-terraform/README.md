## Demo Project - Ansible & Terraform

### Topics of the Demo Project
Ansible Integration in Terraform

### Technologies Used
- Ansible
- Terraform
- AWS
- Docker
- Linux

### Project Description
- Create Ansible Playbook for Terraform integration
- Adjust Terraform configuration to execute Ansible Playbook automatically, so once Terraform provisions a server, it executes an Ansible playbook that configures the server


#### Steps to create an Ansible Playbook for Terraform integration
We are going to reuse the playbook created for demo project #3. So copy the whole `ansible` directory from demo project #3 into the root folder of this demo project #4. Also copy the `docker-compose.yaml` file from demo project #3 into the root folder of this demo project #4.

#### Steps to adjust the Terraform configuration to execute the Ansible Playbook automatically
As we learned in the Terraform module in video #15, Terraform provisioners provide control over commands to be executed on the local or remote machine. There are three different provisioners:
- `file`: copy a file from local machine to remote server
- `remote-exec`: execute commands / a script on a remote server
- `local-exec` execute commands / a script on the local machine

So to execute an Ansible playbook at the end of the Terraform provisioning steps, we can use the `local-exec` provisioner.

Create a direcory called `terraform` and copy the `main.tf` and `terraform.tfvars` files from demo project #3 into this folder. Adjust the `resource "aws_instance" "myapp-server"` block in the Terraform configuration file as follows:

_terraform/main.tf_
```conf
resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    tags = {
        Name = "${var.env_prefix}-server"
    }

    # new block to be added
    # we use a local_exec provisioner because we want to execute the Ansible playbook from the local machine
    provisioner "local-exec" {
        # we define the ansible folder as the working directory because we want Ansible to have access to the ansible.cfg and project-vars files
        working_dir = "../ansible/"
        # we set the inventory, ssh private key and user because the ip address cannot be configured in a hosts file as it is not known before the Terraform configuration file is applied
        command = "ansible-playbook --inventory ${self.public_ip}, --private-key ${var.private_key_location} --user ec2-user deploy-docker.yaml"
    }
}
```

The `--inventory` option allows to provide a hosts file location or a list of ip adresses. If the latter is used, it must be terminated with a comma, otherwise it will be interpreted as a file location.

There are some other small adjustments to be made related to the `--inventory` option:
- If an `--inventory` option is set, it overrides a possibly available hosts file. But for this demo project we don't really need the hosts file and delete it.
- We also remove the line `inventory = ./hosts` from the `ansible.cfg` file. 
- And finally we replace all occurrences of `hosts: docker_server` in the Ansible playbook with `hosts: all`. The `docker_server` reference doesn't exist anymore and since we provide just one ip address with the `--inventory` option, `all` references just this ip address.

Since we provided the private key location as a variable, we have to add the following line to the `terraform.tfvars` file:
```conf
private_key_location = "/Users/fsiegrist/.ssh/id_ed25519"
```
The variable must also be declared in the `main.tf` configuration file:
```conf
variable private_key_location {}
```

**Steps to fix the timing issue**\
There is a timing issue: by the time the local-exec provisioner gets executed, the EC2 instance may not be fully initialized yet. So it might not even be possible for Ansible to ssh into the server.

Ansible has to check whether the EC2 instance is ready before staring its tasks to configure it. Add the following play to the playbook before any other plays:

```yaml
- name: Wait until EC2 instance accepts SSH connections
  hosts: all
  gather_facts: no  # Ansible cannot gather facts without establishing an ssh connection, so we disable this step
  tasks:
    - name: Esure ssh port is open
      wait_for:
        port: 22
        delay: 10
        timeout: 100
        search_regex: OpenSSH
        host: "{{ (ansible_ssh_host|default(ansible_host))|default(inventory_hostname) }}"
      vars:
        ansible_connection: local
        ansible_python_interpreter: /opt/homebrew/bin/python3  # to establish an ssh connection we have to use the python interpreter of the local machine
```

Check the documentation of the [wait_for](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/wait_for_module.html) module.

Now apply the Terraform configuration file:
```sh
cd terraform
terraform init
terraform apply --auto-approve
# ...
# Plan: 7 to add, 0 to change, 0 to destroy.
# 
# Changes to Outputs:
#   + ec2_public_ip = (known after apply)
# aws_key_pair.ssh-key: Creating...
# aws_vpc.myapp-vpc: Creating...
# aws_key_pair.ssh-key: Creation complete after 0s [id=server-key]
# aws_vpc.myapp-vpc: Creation complete after 1s [id=vpc-0154298e127eaf317]
# aws_internet_gateway.myapp-igw: Creating...
# aws_subnet.myapp-subnet-1: Creating...
# aws_default_security_group.default-sg: Creating...
# aws_internet_gateway.myapp-igw: Creation complete after 0s [id=igw-040cc46df15ccc927]
# aws_default_route_table.main-rtb: Creating...
# aws_subnet.myapp-subnet-1: Creation complete after 0s [id=subnet-0ba2bea98ffc6dc77]
# aws_default_route_table.main-rtb: Creation complete after 1s [id=rtb-0dbc83b804e969c4d]
# aws_default_security_group.default-sg: Creation complete after 2s [id=sg-022aac444a3f70289]
# aws_instance.myapp-server: Creating...
# aws_instance.myapp-server: Still creating... [10s elapsed]
# aws_instance.myapp-server: Still creating... [20s elapsed]
# aws_instance.myapp-server: Still creating... [30s elapsed]
# aws_instance.myapp-server: Provisioning with 'local-exec'...
# aws_instance.myapp-server (local-exec): Executing: ["/bin/sh" "-c" "ansible-playbook --inventory 3.123.24.206, --private-key /Users/fsiegrist/.ssh/id_ed25519 --user ec2-user deploy-docker.yaml"]
# 
# aws_instance.myapp-server (local-exec): PLAY [Wait until EC2 instance accepts SSH connections] *************************
# 
# aws_instance.myapp-server (local-exec): TASK [Ensure ssh port is open] *************************************************
# aws_instance.myapp-server: Still creating... [40s elapsed]
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): PLAY [Install Docker] **********************************************************
# 
# aws_instance.myapp-server (local-exec): TASK [Gathering Facts] *********************************************************
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Ensure Docker is installed] **********************************************
# aws_instance.myapp-server: Still creating... [50s elapsed]
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): PLAY [Install Docker Compose] **************************************************
# 
# aws_instance.myapp-server (local-exec): TASK [Gathering Facts] *********************************************************
# aws_instance.myapp-server: Still creating... [1m0s elapsed]
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Get architecture of remote machine] **************************************
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Download and install Docker Compose] *************************************
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): PLAY [Start Docker] ************************************************************
# 
# aws_instance.myapp-server (local-exec): TASK [Gathering Facts] *********************************************************
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Ensure Docker daemon is started] *****************************************
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): PLAY [Add ec2-user to docker group] ********************************************
# 
# aws_instance.myapp-server (local-exec): TASK [Gathering Facts] *********************************************************
# aws_instance.myapp-server: Still creating... [1m10s elapsed]
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Add ec2-user to docker group] ********************************************
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Reset ssh connection to allow user changes to affect 'current login user'] ***
# 
# aws_instance.myapp-server (local-exec): PLAY [Install pip3] ************************************************************
# 
# aws_instance.myapp-server (local-exec): TASK [Gathering Facts] *********************************************************
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Ensure pip3 is installed] ************************************************
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): PLAY [Install required Python modules] *****************************************
# 
# aws_instance.myapp-server (local-exec): TASK [Gathering Facts] *********************************************************
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Install Python modules 'docker' and 'docker-compose'] ********************
# aws_instance.myapp-server: Still creating... [1m20s elapsed]
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): PLAY [Start Docker containers] *************************************************
# 
# aws_instance.myapp-server (local-exec): TASK [Gathering Facts] *********************************************************
# aws_instance.myapp-server (local-exec): ok: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Copy docker-compose.yaml] ************************************************
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Make sure a Docker login against the private registry on Docker Hub is established] ***
# aws_instance.myapp-server: Still creating... [1m30s elapsed]
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): TASK [Start containers from docker-compose file] *******************************
# aws_instance.myapp-server: Still creating... [1m40s elapsed]
# aws_instance.myapp-server: Still creating... [1m50s elapsed]
# aws_instance.myapp-server: Still creating... [2m0s elapsed]
# aws_instance.myapp-server: Still creating... [2m10s elapsed]
# aws_instance.myapp-server (local-exec): changed: [3.123.24.206]
# 
# aws_instance.myapp-server (local-exec): PLAY RECAP *********************************************************************
# aws_instance.myapp-server (local-exec): 3.123.24.206               : ok=18   changed=10   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
# 
# aws_instance.myapp-server: Creation complete after 2m17s [id=i-0e5a125af3d7b1ebc]
# 
# Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
# 
# Outputs:
# 
# ec2_public_ip = "3.123.24.206"
```

Don't forget to cleanup when you're done:
```sh
terraform destroy --auto-approve
```

### Optional: Using the Terraform null_resource
Instead of defining the local-exec provisioner directly inside the `resource "aws_instance" "myapp-server"` block, we could also define a separate resource of type "null_resource" and add it there. This would look like this:

```conf
resource "null_resource" "configure-server" {
    triggers = {
        trigger = aws_instance.myapp-server.public_ip  # trigger the resource "creation" whenever the public_ip changes
    }

    provisioner "local-exec" {
        working_dir = "../ansible/"
        command = "ansible-playbook --inventory ${aws_instance.myapp-server.public_ip}, --private-key ${var.private_key_location} --user ec2-user deploy-docker.yaml"
    }
}
```

Note that the reference to `self.public_ip` had to be adjusted to `aws_instance.myapp-server.public_ip`.

Check the documentation of the [null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource).
