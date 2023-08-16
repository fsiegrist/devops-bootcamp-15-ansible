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
# ...
# Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
# 
# Outputs:
# 
# ec2_public_ip_one = "18.196.55.214"
# ec2_public_ip_three = "3.71.200.215"
# ec2_public_ip_two = "3.67.227.205"
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
# amazon.aws.aws_ec2                                      EC2 inventory source                                                              
# amazon.aws.aws_rds                                      RDS instance inventory source                                                     
# ansible.builtin.advanced_host_list                      Parses a 'host list' with ranges                                                  
# ansible.builtin.auto                                    Loads and executes an inventory plugin specified in a YAML config                 
# ansible.builtin.constructed                             Uses Jinja2 to construct vars and groups based on existing inventory              
# ansible.builtin.generator                               Uses Jinja2 to construct hosts and groups from patterns                           
# ansible.builtin.host_list                               Parses a 'host list' string           
# ...
```

For AWS EC2 instances there is the `amazon.aws.aws_ec2` plugin. To display its documentation, execute
```sh
ansible-doc -t inventory amazon.aws.aws_ec2
# > AMAZON.AWS.AWS_EC2    (/opt/homebrew/Cellar/ansible/8.2.0_1/libexec/lib/python3.11/site-packages/ansible_collections/amazon/aws/plugins/inve>
# 
#         Get inventory hosts from Amazon Web Services EC2. The inventory file is a YAML configuration file and must
#         end with `aws_ec2.{yml|yaml}'. Example: `my_inventory.aws_ec2.yml'.
# ...
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

To configure the plugin, we provide a plugin configuration file which must have a name ending with "aws_ec2.yaml" to be recognized by the aws_ec2 plugin. So let's create a file called `inventory_aws_ec2.yaml` and add the following content:

_ansible/inventory_aws_ec2.yaml_
```yaml
plugin: aws_ec2
regions:
  - eu-central-1
```

Test this plugin configuration using the `ansible-inventory` command used to display or dump the configured inventory as Ansible sees it:
```sh
cd ansible
ansible-inventory -i inventory_aws_ec2.yaml --graph  # --list would dump all the meta information of the EC2 instances
# @all:
#   |--@ungrouped:
#   |--@aws_ec2:
#   |  |--ip-10-0-10-192.eu-central-1.compute.internal
#   |  |--ip-10-0-10-200.eu-central-1.compute.internal
#   |  |--ip-10-0-10-190.eu-central-1.compute.internal
```

Comparing the output with the information displayed in the AWS Management Webconsole shows us, that Ansible sees the private DNS names, since we haven't set public DNS names for our EC2 instances yet. Ansible could connect to the instances using the private DNS names if it was run from a machine inside the VPC of the instances. Because we want to run Ansible from our local machine, we have to adjust the Terraform configuration file to assign public DNS names to the EC2 instances:

_terraform/main.tf_
```conf
resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true  # <-- add this attribute
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}
```

Re-executing the `ansible-inventory` command displays the public DNS names:
```sh
ansible-inventory -i inventory_aws_ec2.yaml --graph
# @all:
#   |--@ungrouped:
#   |--@aws_ec2:
#   |  |--ec2-18-196-55-214.eu-central-1.compute.amazonaws.com
#   |  |--ec2-3-71-200-215.eu-central-1.compute.amazonaws.com
#   |  |--ec2-3-67-227-205.eu-central-1.compute.amazonaws.com
```

Now we are ready to use the plugin in the playbook. In the output of the `ansible-inventory` command we see that the hosts are grouped under a group named `aws_ec2`. So first let's replace all occurrences of `hosts: all` in the ansible playbook 'deploy-docker.yaml' with `hosts: aws_ec2`. Then add the inventory, username and private key file location to the 'ansible.cfg' file:

_ansible/ansible.cfg_
```conf
...
enable_plugins = amazon.aws.aws_ec2
inventory = inventory_aws_ec2.yaml    # <--
remote_user = ec2-user                # <--
private_key_file = ~/.ssh/id_ed25519  # <--
```

Now let's execute the ansible playbook using the dynamic inventory plugin:
```sh
cd ansible
ansible-playbook deploy-docker.yaml
# PLAY [Wait until EC2 instance accepts SSH connections] ****************************************************************************************
# 
# TASK [Ensure ssh port is open] ****************************************************************************************************************
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Install Docker] *************************************************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# 
# TASK [Ensure Docker is installed] *************************************************************************************************************
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Install Docker Compose] *****************************************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# TASK [Get architecture of remote machine] *****************************************************************************************************
# changed: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# 
# TASK [Download and install Docker Compose] ****************************************************************************************************
# changed: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Start Docker] ***************************************************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# TASK [Ensure Docker daemon is started] ********************************************************************************************************
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Add ec2-user to docker group] ***********************************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# 
# TASK [Add ec2-user to docker group] ***********************************************************************************************************
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# 
# TASK [Reset ssh connection to allow user changes to affect 'current login user'] **************************************************************
# 
# TASK [Reset ssh connection to allow user changes to affect 'current login user'] **************************************************************
# 
# TASK [Reset ssh connection to allow user changes to affect 'current login user'] **************************************************************
# 
# PLAY [Install pip3] ***************************************************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# 
# TASK [Ensure pip3 is installed] ***************************************************************************************************************
# changed: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# changed: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Install required Python modules] ********************************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# TASK [Install Python modules 'docker' and 'docker-compose'] ***********************************************************************************
# changed: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Start Docker containers] ****************************************************************************************************************
# 
# TASK [Gathering Facts] ************************************************************************************************************************
# ok: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# ok: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# TASK [Copy docker-compose.yaml] ***************************************************************************************************************
# changed: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# changed: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# 
# TASK [Make sure a Docker login against the private registry on Docker Hub is established] *****************************************************
# changed: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# changed: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# 
# TASK [Start containers from docker-compose file] **********************************************************************************************
# changed: [ec2-3-67-227-205.eu-central-1.compute.amazonaws.com]
# changed: [ec2-18-196-55-214.eu-central-1.compute.amazonaws.com]
# changed: [ec2-3-71-200-215.eu-central-1.compute.amazonaws.com]
# 
# PLAY RECAP ************************************************************************************************************************************
# ec2-18-196-55-214.eu-central-1.compute.amazonaws.com : ok=18   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
# ec2-3-67-227-205.eu-central-1.compute.amazonaws.com : ok=18   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
# ec2-3-71-200-215.eu-central-1.compute.amazonaws.com : ok=18   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

If we add a fourth server and run the playbook again, we don't have to change anything in the ansible configuration. The dynamic inventory plugin will see the fourth server and let the playbook configure it too.

#### Optional: Using filters
If we want to target only specific servers (e.g. only the running servers with the 'Name' tag starting with 'dev-server' and instance type 't2.micro'), we can use filters in the configuration of the aws_ec2 plugin (the possible filters are listed on an AWS documentation page referenced in the documentation of the aws_ec2 plugin):

_ansible/inventory_aws_ec2.yaml_
```yaml
plugin: aws_ec2
regions:
  - eu-central-1
filters:
  tag:Name: dev-server*
  instance-state-name: running
  instance-type: t2.micro
```

Display the inventory:
```sh
ansible-inventory --graph
# @all:
#   |--@ungrouped:
#   |--@aws_ec2:
#   |  |--ec2-18-196-55-214.eu-central-1.compute.amazonaws.com
#   |  |--ec2-3-67-227-205.eu-central-1.compute.amazonaws.com
```

#### Optional: Using dynamic groups
It is also possible to dynamically create inventory groups based on any attribute of the instances. (The attributes can be displayed using the `--list` option of the `ansible-inventory` command.) As an example, use the following plugin configuration file:

_ansible/inventory_aws_ec2.yaml_
```yaml
plugin: aws_ec2
regions:
  - eu-central-1
keyed_groups:
  - key: tags
    prefix: tag
  - key: instance_type
    prefix: instance_type
```

Display the inventory groups:
```sh
ansible-inventory --graph
# @all:
#   |--@ungrouped:
#   |--@aws_ec2:
#   |  |--ec2-18-196-55-214.eu-central-1.compute.amazonaws.com
#   |  |--ec2-3-71-200-215.eu-central-1.compute.amazonaws.com
#   |  |--ec2-3-67-227-205.eu-central-1.compute.amazonaws.com
#   |--@tag_Name_dev_server_one:
#   |  |--ec2-18-196-55-214.eu-central-1.compute.amazonaws.com
#   |--@instance_type_t2_micro:
#   |  |--ec2-18-196-55-214.eu-central-1.compute.amazonaws.com
#   |  |--ec2-3-67-227-205.eu-central-1.compute.amazonaws.com
#   |--@tag_Name_dev_server_three:
#   |  |--ec2-3-71-200-215.eu-central-1.compute.amazonaws.com
#   |--@instance_type_t2_small:
#   |  |--ec2-3-71-200-215.eu-central-1.compute.amazonaws.com
#   |--@tag_Name_dev_server_two:
#   |  |--ec2-3-67-227-205.eu-central-1.compute.amazonaws.com
```

These groups can now be referenced in the playbook to apply different configurations on different groups.

Don't forget to destroy all instances when you're done:
```sh
terraform destroy --auto-approve
```

### Links to documentation pages
- [Dynamic Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html)
- [Inventory Plugins](https://docs.ansible.com/ansible/latest/plugins/inventory.html#inventory-plugins)
- [EC2 Inventory](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Ansible Inventory Command](https://docs.ansible.com/ansible/latest/cli/ansible-inventory.html)
