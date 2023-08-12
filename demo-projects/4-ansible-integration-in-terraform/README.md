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
We are going to reuse the playbook created for demo project #3. So copy the whole `ansible` directory from demo project #3 into the root folder of this demo project #4.

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
