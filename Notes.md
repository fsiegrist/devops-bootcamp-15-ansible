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