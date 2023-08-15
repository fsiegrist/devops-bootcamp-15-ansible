## Demo Project - Configure Dynamic Inventory

### Topics of the Demo Project
Configure dynamic inventory for EC2 servers

### Technologies Used
- Ansible
- Terraform
- AWS

### Project Description
- Create three EC2 instances with Terraform
- Write Ansible AWS EC2 Plugin to dynamically set inventory of EC2 servers that Ansible should manage, instead of hard-coding server addresses in Ansible inventory file

#### Steps to create three EC2 instances with Terraform
Create a `terraform` directory in the root folder of this demo project #5. Copy the `main.tf` and `terraform.tfvars` files from the `terraform` folder of demo project #3 into the newly created `terraform` folder of this demo project #5. Rename the `resource "aws_instance" "myapp-server"` in the `main.tf` configuration file to `myapp-server-one` and adjust the tag name and the output (of the public ip) accordingly. Copy the whole resource and output twice and rename `one` to `two` and `three` respectively. In the third EC2 instance replace the `instance_type` value `var.instance_type` with `"t2.small"`.

Apply the Terraform configuration:
```sh
cd terraform
terraform init
terraform apply --auto-approve
```

#### Steps to write an Ansible AWS EC2 plugin to dynamically set inventory of EC2 servers
We are going to reuse the playbook created for demo project #4. So copy the whole `ansible` directory from demo project #4 into the root folder of this demo project #5. Also copy the `docker-compose.yaml` file from demo project #4 into the root folder of this demo project #5.

Since we do no longer use a provisioner in the Terraform configuration file which executes the ansible-playbook command providing the ip address of the EC2 instance via the `--inventory` option, we need some functionality that connects to our AWS account and gets the required server information. There are two possibilities to implement this functionality (see the [dynamic inventory doc](https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html)):
- inventory scripts, written in Python
- inventory plugins, written in yaml

It is recommended to use the [inventory plugins](https://docs.ansible.com/ansible/latest/plugins/inventory.html#inventory-plugins), as they can make use of all the Ansible features such as state management.

To get a list of available inventory plugins for each specific infrastructure provider, execute
```sh
ansible-doc -t inventory -l
```

For AWS EC2 instances there is the `amazon.aws.aws_ec2` plugin. To display its documentation, execute
```sh
ansible-doc -t inventory amazon.aws.aws_ec2
```
or check the [EC2 inventory plugin documentation](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html).

The plugin requires the boto3 and botocore libraries to be installed on the local machine. If you haven't installed them yet, do so executing
```sh
pip install boto3
```

To enable the plugin, add the following line to the file `ansible/ansible.cfg`:
```conf
enable_plugins = amazon.aws.aws_ec2
```





Links to documentation pages:
- [Dynamic Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html)
- [Inventory Plugins](https://docs.ansible.com/ansible/latest/plugins/inventory.html#inventory-plugins)
- [EC2 Inventory](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Ansible Inventory Command](https://docs.ansible.com/ansible/latest/cli/ansible-inventory.html)
