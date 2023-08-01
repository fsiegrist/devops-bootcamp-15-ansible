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

The task "Gathering Facts" is part of the "Gather Facts" module of Ansible, which is automatically called by playbooks to gather useful variables about remote hosts, that you can use in the playbooks. So Ansible provides many facts about the system automatically.

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

 If you have a large Ansible project with lots of playbooks, modules and plugins, you can also [create your own collection](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections.html) bundling all these components and making it easier to share it with other developers or teams.

</details>

*****