## Notes on the videos for Module 15 "Configuration Management with Ansible"
<br />

<details>
<summary>Video: 1 - Introduction to Ansible</summary>
<br />

Ansible is a tool to automate IT tasks, such as configure systems, deploy software or orchestrate more advanced IT tasks. Use Cases for Ansible are repetitive tasks like updates, backups, create users & assign permissions, system reboots, etc. When you need the same configuration on many servers, Ansible lets you update all the servers at the same time.

Ansible advantages:
- instead of ssh into all remote server, execute tasks from your own machine
- configuration/installation/deployment steps in a single yaml file
- re-use same the file multiple times for different environments
- more reliable and less error prone
- supporting all infrastructure from OS to cloud providers

Ansible is agentless. It connects to remote servers using simple SSH, no special agent is required.

### Ansible Modules
A module is a reusable, standalone script (in yaml format) that Ansible runs on your behalf. Modules are fine granular, performing one small specific task like creating or copying a file, installing an nginx server, starting an nginx server, starting a Docker container, creating a cloud instance, etc. Ansible provides hundreds of Modules for all sorts of tasks. Modules get pushed to the target server, do their work and get removed again.

### Ansible Playbooks
A Playbook groups multiple modules together, which get executed in order from top to bottom. With a Playbook, you can orchestrate steps of any manual ordered process.

A playbook consists of one or more "plays" in an ordered list. Each play executes part of the overall goal of the playbook. A play runs one or more tasks. Each task calls an Ansible module.

Example:
```yaml
# play for webservers
- name: install and start nginx server # description of the play
  hosts: webservers # defines where the following tasks should get executed
  remote_user: root # defines with which user the tasks should be executed

  tasks:
    - name: create directory for nginx # description of the task
      file:                            # module name
        path: /path/to/nginx/dir       # arguments
        state: directory

    - name: install nginx latest version
      yum:
        name: nginx
        state: latest

    - name: start nginx
      service:
        name: nginx
        state: started

# play for databases
- name: rename table, set owner and truncate it
  hosts: databases
  remote_user: root
  vars: # define variables
    tablename: foo

  tasks:
    - name: rename table bar to {{ tablename }}
      postgresql_table:
        table: bar
        rename: {{ tablename }}

    - name: set owner to some user
      postgresql_table:
        table: {{ tablename }}
        owner: someuser

    - name: truncate table {{ tablename }}
      postgresql_table:
        table: {{ tablename }}
        truncate: yes
```

The `hosts` attribute defines a target name which is mapped to hostnames or IP addresses in the Ansible inventory list, containing all the machines involved in task executions:

```yaml
[webservers]
web1.myserver.com # hostnames
web2.myserver.com

[databases]
10.24.0.7 # or IP addresses
10.24.0.8
```

### Ansible for Docker
With Ansible you can create alternative to Dockerfile, which is more powerful. It lets you manage both the Docker container and its host. I also allows you to reproduce the application not only in a Docker container but across many other environments like a Vagrant container, a clound instance, a bare metal machine, etc. 

### Ansible Tower
Ansible Tower is a web-based solution from RedHat that makes Ansible more easy to use. It simplifies tasks like
- centrally store automation tasks
- across teams
- configure permissions
- manage inventory

### Alternatives
Alternatives for Ansible are Puppet and Chef. But they use Ruby as their configuration language which needs more efford to learn than yaml. And the are not agentless, so you have to install the tool on each server you want to manage, and you need to manage updates of these tools on each server. These may be reasons why Ansible has become more widely accepted.

</details>

*****

<details>
<summary>Video: 2 - Install Ansible</summary>
<br />

You can install Ansible either on your local machine or on a remote server. The machine that runs Ansible is called the "Control Node". It manages the target servers. Windows is not supported for the control node.

To install Ansible on a Mac, just execute

```sh
brew update
brew install ansible
```

Ansible is written in Python. So Python must be installed as a prerequisite. If Python is already installed, Ansilbe may be installed using Python's package manager pip:

```python
pip install ansible
```

See also: [Installation Guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

</details>

*****

<details>
<summary>Video: 3 - Setup Managed Server to Configure with Ansible</summary>
<br />

In order to have two servers we can configure using Ansible, we create two Droplets on DigitalOcean. So login to your DigitalOcean account and create two Droplets (Ubuntu, Frankfurt, Shared CPU, Regular, 2GB / 1CPU). Use the SSH key created in previous modules. Optionally set the hostnames to 'ubuntu-ansible-1' and 'ubuntu-ansible-2'.

On Linux servers Ansible requires Python to be installed. This is already the case on DigitalOcean Droplets. (On Windows servers PowerShell is required.)

</details>

*****

<details>
<summary>Video: 4 - Ansible Inventory and Ansible ad-hoc commands</summary>
<br />

The Ansible Inventory is a file containing data about the remote hosts and how to connect to them:
- Host IP-address or Host DNS-name
- SSH Private Key
- SSH User

```yaml
209.38.196.102 ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_user=root
209.38.196.11  ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_user=root
```

### Grouping Hosts
To address multiple servers, the hosts may be grouped based on their functionality or geo location etc. SSH key and user can be defined for whole groups:

```yaml
[droplets]
209.38.196.102
209.38.196.11

[droplets:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_user=root
```

You can create groups that track
- where: datacenter, region
- what: database servers, web servers, etc.
- when: which stage e.g. dev, test, prod

Hosts may be added to more than one group.

### Ad-hoc Commands
Ad-hoc commands are not stored for future uses. They are just a fast way to interact with the managed hosts.

```sh
# format
ansible [pattern] -i [inventory-file] -m [module] -a "[module options]"

# examples
ansible 209.38.196.102 -i ~/.ansible/hosts -m ping 
ansible droplets -i ~/.ansible/hosts -m ping 
ansible all -i ~/.ansible/hosts -m ping # "all" is an implicit group containing every host
```

</details>

*****

<details>
<summary>Video: 5 - Configure AWS EC2 server with Ansible</summary>
<br />

Login to you AWS Management Console account and create two EC2 instances. Add an inbound rule to the used security group allowing SSH connections from your local machine's IP address. As soon as both instances have been fully initialized, manually ssh into both instances to add their fingerprints to the known_hosts file. Then add an 'ec2' group with their public hostnames to the ansible inventory file:

```yaml
[ec2]
ec2-18-192-42-239.eu-central-1.compute.amazonaws.com
ec2-18-184-157-86.eu-central-1.compute.amazonaws.com

[ec2:vars]
ansible_ssh_private_key_file=~/.ssh/ec2-key-pair.pem
ansible_user=ec2-user
```

Now execute the ping command to test the configuration:
```sh
ansible ec2 -i ~/.ansible/hosts -m ping
# [WARNING]: Platform linux on host ec2-18-184-157-86.eu-central-1.compute.amazonaws.com is using the discovered Python interpreter at /usr/bin/python3.9, but future installation of another Python interpreter could change the meaning of that path. 
# See https://docs.ansible.com/ansible-core/2.15/reference_appendices/interpreter_discovery.html for more information.
# ec2-18-184-157-86.eu-central-1.compute.amazonaws.com | SUCCESS => {
#     "ansible_facts": {
#         "discovered_interpreter_python": "/usr/bin/python3.9"
#     },
#     "changed": false,
 #    "ping": "pong"
# }
# ...
```

To get rid of the warning message we open the referenced [documentation page](https://docs.ansible.com/ansible-core/2.15/reference_appendices/interpreter_discovery.html) and learn:

To control the discovery behavior:
- for individual hosts and groups, use the ansible_python_interpreter inventory variable
- globally, use the interpreter_python key in the [defaults] section of ansible.cfg

So we add the following line to the [ec2:vars] section of the Ansible inventory file:
```yaml
ansible_python_interpreter=/usr/bin/python3.9
```

Don't forget to terminate the EC2 instances when you have finished these tasks.

</details>

*****

<details>
<summary>Video: 6 - Managing Host Key Checking and SSH keys</summary>
<br />

When ssh-ing into a server for the first time, Ansible asks us, whether we want to accept the connection or not:
```sh
# The authenticity of host '209.38.196.102 (209.38.196.102)' can't be established.
# ED25519 key fingerprint is SHA256:3kgtPoGZ/6t9OOM0RQ47hxiStqFtkPwmTl8aVqHMhHI.
# This key is not known by any other names
# Are you sure you want to continue connecting (yes/no/[fingerprint])? 
```

To suppress this interactive part, we have two options:
- for long living servers, we can add the server's fingerprint to the `~/.ssh/known_hosts` file by manually ssh-ing into into it once; if the server doesn't know our public key yet, two steps are necessary: first, add the server's fingerprint to our `~/.ssh/known_hosts` file by executing `ssh-keyscan -H <server-ip> >> ~/.ssh/known_hosts` and second, add our public key to the server's `~/.ssh/authorized_keys` file by executing `ssh-copy-id root@<server-ip>`
- for ephemeral servers that are dynamically created and destroyed after a short time, it is also possible to disable the whole host key checking; this is done in the ansible configuration file; default locations for this file are `/etc/ansible/ansible.cfg` and `~/.ansible.cfg`; add the following content to `~/.ansible.cfg`:
  ```yaml
  [defaults]
  host_key_checking=False
  ```
  see [config documentation](https://docs.ansible.com/ansible-core/2.15/reference_appendices/config.html)

</details>

*****

<details>
<summary>Video: 7 - Introduction to Playbooks</summary>
<br />

Ansible is an Infrastructure-As-Code tool, so Ansible configuration files are treated like code and saved in a source control system e.g. Git.

Create a project folder called 'ansible' containing a 'hosts' file and a project specific configuration file:

_ansible/hosts_
```yaml
[webserver]
209.38.196.102
209.38.196.11

[webserver:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_user=root
```
_ansible/ansible.cfg_
```cfg
[defaults]
inventory=./hosts
host_key_checking=False
```

### A Simple Playbook
A Playbook can have multiple "plays". A play is a group of ordered "tasks". Plays and tasks run in order from top to bottom.

Create a file called simple-playbook.yaml with the following content:\
_ansible/simple-playbook.yaml_
```yaml
- name: Configure nginx web server
  hosts: webserver
  tasks:
    - name: Install nginx server
      apt:
        name: nginx
        state: latest
    - name: Start nginx server
      service:
        name: nginx
        state: started
```

Execute the playbook with the following command:
```sh
ansible-playbook simple-playbook.yaml

# PLAY [Configure nginx web server] ****************************************************************************************
# 
# TASK [Gathering Facts] ***************************************************************************************************
# ok: [209.38.196.11]
# ok: [209.38.196.102]
# 
# TASK [Install nginx server] **********************************************************************************************
# changed: [209.38.196.11]
# changed: [209.38.196.102]
# 
# TASK [Start nginx server] ************************************************************************************************
# ok: [209.38.196.102]
# ok: [209.38.196.11]
# 
# PLAY RECAP ***************************************************************************************************************
# 209.38.196.102             : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
# 209.38.196.11              : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

The task "Gathering Facts" is part of the "Gather Facts" module of Ansible, which is automatically called by playbooks to gather useful variables about remote hosts, that you can use in the playbooks. So Ansible provides many facts about the system automatically. (If you want to suppress this step for a play, you can add `gather_facts: no` before the `tasks`.)

The "RECAP" play is also called automatically to display a summary of the things that have been done on the remote servers.

### Installing a Specific Version
If you want to install a specific package version of nginx, you can adjust the task like this:
```yaml
    - name: Install nginx server
      apt:
        name: nginx=1.18.0-0ubuntu1 # <-- wildcards are also supported, e.g. 1.18.*
        state: present              # <--
```

### Ansible Idempotency
Most Ansible modules check whether the desired state has already been achieved. If so, they exit without performing any actions.

Execute the previous playbook again to see that no changes will be applied.

### Cleanup
To stop and uninstall nginx, execute the following playbook:
```yaml
- name: Configure nginx web server
  hosts: webserver
  tasks:
    - name: Stop nginx server
      service:
        name: nginx
        state: stopped
    - name: Uninstall nginx server
      apt:
        name: nginx=1.18.*
        state: absent
```

</details>

*****

<details>
<summary>Video: 8 - Ansible Modules</summary>
<br />

Modules (also referred to as "task plugins") are the main building blocks of Ansible playbooks. Ansible executes a module usually on the remote server and collects return values.

Reference the [complete module index](https://docs.ansible.com/ansible/latest/collections/index_module.html) or the [module index grouped by category](https://docs.ansible.com/ansible/2.9/modules/modules_by_category.html), where you find descriptions on how to use the module and which parameters you can configure with what values.

</details>

*****

<details>
<summary>Video: 9 - Collections in Ansible</summary>
<br />

Until Ansible version 2.9 all modules were included in a single repository and packaged together with the Ansible core in one `ansible` package. As Ansible grew and thousands of modules have been added, in Ansible 2.10 and later the modules and plugins have been separated from the core and moved to various "collections" in different repositories. When installing Ansible now, two packages get installed: `ansible-base` containing the core functionality and `ansible` containing all the modules and plugins.

Collections are a packaging format for bundling and distributing Ansible content like playbooks, modules, plugins, etc. E.g. a Docker collection may contain playbooks, modules and plugins needed to work with Docker containers.

In the built-in collection [ansible.builtin](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html#plugins-in-ansible-builtin) you'll find the `apt` module, the `service` module or the `gather_facts` we used or mentioned in a previous video.

Collections, which are not built-in can be installed from [Ansible Galaxy](https://galaxy.ansible.com/) which is an online hub for finding and sharing Ansible community content (comparable to Terrform registry, PyPI etc.).

It also provides a CLI utility to list and install collections:
```sh
ansible-galaxy collection list
ansible-galaxy collection install amazon.aws
```

When using modules of the built-in collection, it is not necessary to specify the fully qualified name (`<namespace>.<collection>.<module>`), e.g. `apt` instead of `ansible.builtin.apt`. 

 If you have a large Ansible project with lots of playbooks, modules and plugins, you can also [create your own collection](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections.html) bundling all these components and making it easier to share it with other developers or teams.

</details>

*****

<details>
<summary>Video: 10, 11, 12 - Project: Deploy Nodejs application</summary>
<br />

In the first demo project we are going to deploy a Nodejs application on a DigitalOcean droplet using Ansible. This includes the following steps:
- create a droplet on DigitalOcean
- write an Ansible playbook to
  - install node and npm on the droplet
  - copy the nodejs artifact and unpack it
  - create an application specific Linux user
  - start the application with this user
  - verify that the application is running successfully

See [demo project 1](./demo-projects/1-nodejs-application-deployment/).

</details>

*****

<details>
<summary>Video: 13 - Ansible Variables - make your Playbook customizable</summary>
<br />

Variables can be used to parameterize your Playbook to make it customizable so we can use the same Ansbile script for different environments, by substituting some dynamic values.

See the [documentation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html).

### Registered Variables
With "register" you can create variables from the output of an Ansible task. This variable can be used in any later task in your Play.

```yaml
  tasks:
    - name: Ensure app is running
      shell: ps aux | grep node
      register: app_status # register the return value of the shell module into a variable
    - name: Print out the result
      debug: msg={{ app_status.stdout_lines }} # print the stdout of the shell command (which is part of the shell module's return value)
```

The variables can be referenced using double curly braces. If the curly braces directly follow the attribute, you must quote the whole expression to create valid YAML syntax:

```yaml
  tasks:
    - name: Unpack the nodejs file
      unarchive:
        src: "{{ node_file_location }}"
```

### Naming of variables
- Wrong: Playbook keywords, such as environment
- Valid: Letters, numbers and underscores
- Should always start with a letter
- Wrong: linux-name, linux name, linux.name or 12
- Valid: linux_name

### Variables Defined in a Playbook
Variables can be definied directly within the playbook:
```yaml
- name: Deploy nodejs application
  hosts: 134.209.244.217
  become: yes
  become_user: demo
  vars:                       # <-- variable definition
    - version: 1.0.0          # <--
    - user_home: /home/demo   # <--
  tasks:
    - name: Copy application tar file to the server and unpack it there
      unarchive:
        src: ../nodejs-app-{{ version }}.tgz            # <-- variable usage
        dest: {{ user_home }}/                          # <--
    - name: Install dependencies
      npm:
        path: {{ user_home }}/package                   # <--
    - name: Start application
      command: node {{ user_home }}/package/app/server  # <--
      async: 1000
      poll: 0
```

### Passing Variables on the Command Line
To make the Playbook configurable, you don't define the variables within the Playbook, but rather pass them in from the command line:
```sh
ansible-playbook playbook.yaml -e "version=1.0.0 user_home=/home/demo"
```

The long version of `-e` is `--extra-vars`.

### External Variables File
Setting the variable values on the command line gets very inconvenient when the number of variables increases. Ansible also supports the usage of a separate file where all the variables are defined.

_playbook.yaml_
```yaml
```yaml
- name: Deploy nodejs application
  hosts: 134.209.244.217
  become: yes
  become_user: demo
  vars_files:                 # <--
    - project-vars            # <--
```

_project-vars_
```yaml
version: 1.0.0
user_home: /home/demo
```

</details>

*****

<details>
<summary>Video: 14, 15 - Project: Deploy Nexus</summary>
<br />

In the second demo project we are going to deploy Nexus on a DigitalOcean droplet using Ansible. This includes the following steps:
- create a droplet on DigitalOcean
- write an Ansible playbook to
  - install Java and net-tools on the droplet
  - download and unpack Nexus installer
  - create a nexus user to own nexus folders
  - start Nexus with this user
  - verify that Nexus is running successfully

See [demo project 2](./demo-projects/2-nexus-deployment/).

</details>

*****

<details>
<summary>Video: 16 - Ansible Configuration - Default Inventory File</summary>
<br />

As Ansible is an "Infrastructure as Code" tool, its playbooks, inventory files, configuration files etc. should be checked in to a Git repository.

### Configure Inventory Default Location
Ansible supports several sources for configuring its behavior, including an ini file named `ansible.cfg`. You can configure the file globally or for each project, by creating ansible.cfg file in the project. Within this configuration file you can specify the path to the inventory like this:

```yaml
[defaults]
inventory=./hosts
```

See [Ansible Configuration Settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html)

</details>

*****

<details>
<summary>Video: 17, 18 - Project: Run Docker applications</summary>
<br />

In the third demo project we are going to run a Docker container on an AWS EC2 instance using Ansible. This includes the following steps:
- create an EC2 instance on AWS
- write an Ansible playbook to
  - install Docker and Docker Compose on the EC2 instance
  - copy a docker-compose file onto the EC2 instance
  - start the Docker containers specified in this docker-compose file

See [demo project 3](./demo-projects/3-run-docker-applications/).

</details>

****

<details>
<summary>Video: 19 - Project: Terraform & Ansible</summary>
<br />

In the third demo project we provisioned an EC2 instance using Terraform and then switched to Ansible to configure this instance and run a Docker container on it. But we had to manually copy the IP address of the EC2 instance from the output of the Terraform execution and paste it into the Ansible inventory file. 

In the fourth demo project we want to eliminate this manual step and integrate the execution of the Ansible Playbook right in the Terraform configuration file.

See [demo project 4](./demo-projects/4-ansible-integration-in-terraform/).

</details>

****

<details>
<summary>Video: 20 - Project: Dynamic Inventory for EC2 Servers</summary>
<br />

If we have to manage an inventory, which fluctuates over time (i.e. hosts spinning up and shutting down all the time) for example because auto-scaling is used to accomodate for business demands, it isn't practical to hard-code the IP addresses of the servers in a hosts file. Instead we need a way to dynamically configure these IP addresses.

In the fifth demo project we are going to provision three EC2 instances using Terraform and then hand over to Ansible to connect to these instances and configure them without hard-coding their IP addresses.

See [demo project 5](./demo-projects/5-dynamic-inventory/).

</details>

****

<details>
<summary>Video: 21 - Project: Deploying Application in K8s</summary>
<br />

In this sixth demo project we are going to provision a Kubernetes cluster on AWS using the Terraform configuration file created in the Terraform module. We then use Ansible to connect to the EKS cluster and deploy a Deployment and a Service component.

See [demo project 6](./demo-projects/6-deploy-application-in-k8s/).

</details>

****