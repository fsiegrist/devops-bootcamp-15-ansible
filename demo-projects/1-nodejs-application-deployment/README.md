## Demo Project - Node.js Application Deployment

### Topics of the Demo Project
Automate Node.js application deployment

### Technologies Used
- Ansible
- Node.js
- DigitalOcean
- Linux

### Project Description
- Create Server on DigitalOcean
- Write Ansible Playbook that installs necessary technologies, creates Linux user for an application and deploys a NodeJS application with that user


#### Steps to create a server on DigitalOcean
Login to your account on [DigitalOcean](https://cloud.digitalocean.com/login) and create a new Droplet (Frankfurt, Ubuntu, Shared CPU, Regular, 1GB / 1CPU). Use the existing SSH key and name it 'ubuntu-ansible-demo-1'. Copy the IP address of the new droplet (134.209.244.217).


#### Steps to write an Ansible Playbook that deploys a NodeJS application

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
  134.209.244.217 ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_user=root
  ```
- Finally create an empty playbook file called `deploy-node-app.yaml`

**Install node and npm**\
Check the documentation for the following modules:
- [apt: force_apt_get](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html#parameter-force_apt_get)
- [apt: update_cache](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html#parameter-update_cache)
- [apt: cache_valid_time](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html#parameter-cache_valid_time)
- [apt: install](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html#parameter-name)


Add the following content to the playbook 'deploy-node-app.yaml':
```yaml
- name: Install node and npm
  hosts: 134.209.244.217
  tasks:
    - name: Update apt repo and cache
      apt:
        force_apt_get: yes
        update_cache: yes # Yes, true, True would also be possible
        cache_valid_time: 3600 # in seconds
    - name: Install nodejs and npm
      apt:
        pkg:
          - nodejs
          - npm
```

**Copy and unpack tar file**\
Clone the Git repository containing the sample [NodeJS application](https://gitlab.com/devops-bootcamp3/simple-nodejs). There you'll find a `nodejs-app-1.0.0.tgz` file. If not, execute `npm pack` to create it.

Check the documentation for the following modules:
- [copy](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html)
- [unarchive](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/unarchive_module.html)

Add the following content to the playbook 'deploy-node-app.yaml':
```yaml

- name: Deploy nodejs application
  hosts: 134.209.244.217
  tasks:
    - name: Copy application tar file to the server
      copy:
        src: ../nodejs-app-1.0.0.tgz
        dest: /root/app-1.0.0.tgz
    - name: Unpack tar file
      unarchive:
        src: /root/app-1.0.0.tgz
        dest: /root/
        remote_src: yes
```

Execute the playbook created so far:
```sh
cd ansible
ansible-playbook deploy-node-app.yaml
# 
# PLAY [Install node and npm] **********************************************************************************************
# 
# TASK [Gathering Facts] ***************************************************************************************************
# ok: [134.209.244.217]
# 
# TASK [Update apt repo and cache] *****************************************************************************************
# changed: [134.209.244.217]
# 
# TASK [Install nodejs and npm] ********************************************************************************************
# changed: [134.209.244.217]
# 
# PLAY [Deploy nodejs application] *****************************************************************************************
# 
# TASK [Gathering Facts] ***************************************************************************************************
# ok: [134.209.244.217]
# 
# TASK [Copy application tar file to the server] ***************************************************************************
# changed: [134.209.244.217]
# 
# TASK [Unpack tar file] ***************************************************************************************************
# changed: [134.209.244.217]
# 
# PLAY RECAP ***************************************************************************************************************
# 134.209.244.217            : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

SSH into the droplet and make sure there is a `/root/package/` folder containing the Nodejs application.

Note: Instead of copying a local file to the remote server and then unarchiving a remote file, we could just unarchive a local file on the remote server. The copy step will be part of the unarchive task. So a simplified version of the play would be:
```yaml
- name: Deploy nodejs application
  hosts: 134.209.244.217
  tasks:
    - name: Copy application tar file to the server and unpack it there
      unarchive:
        src: ../nodejs-app-1.0.0.tgz
        dest: /root/
```

This time the copied tar file will be removed after unpacking it.

**Start the Application**\
Check the documentation for the following modules:
- [community.general.npm](https://docs.ansible.com/ansible/latest/collections/community/general/npm_module.html)
- [command](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html)

Also check the documentation for [async playbook execution](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_async.html)

Add the following tasks to the "Deploy nodejs application" play:
```yaml
    - name: Install dependencies
      npm:
        path: /root/package
    - name: Start application
      command: node /root/package/app/server
      async: 1000
      poll: 0
```

Execute the playbook, ssh into the droplet and make sure there is a `node_modules` directory in `/root/package` and that the node server is running (`ps aux | grep node`).

**Ensure App is Running**\
Check the documentation for the following modules:
- [shell](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html)
- [debug](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/debug_module.html)

Add the following tasks to the "Deploy nodejs application" play:
```yaml
    - name: Ensure app is running
      shell: ps aux | grep node
      register: app_status # register the return value of the module into a variable
    - debug: msg={{ app_status.stdout_lines }}
```

Execute the playbook:

```sh
ansible-playbook deploy-node-app.yaml
# PLAY [Install node and npm] ********************************************************************
# 
# ...
# 
# TASK [Install dependencies] ********************************************************************
# ok: [134.209.244.217]
# 
# TASK [Start application] ***********************************************************************
# changed: [134.209.244.217]
# 
# TASK [Ensure app is running] *******************************************************************
# changed: [134.209.244.217]
# 
# TASK [debug] ***********************************************************************************
# ok: [134.209.244.217] => {
#     "msg": [
#         "root       35334 41.0  0.5 599400 47208 ?        Sl   20:50   0:00 node /root/package/app/server",
#         "root       35347  0.0  0.0   2888   980 pts/1    S+   20:50   0:00 /bin/sh -c ps aux | grep node",
#         "root       35349  0.0  0.0   7004  2116 pts/1    S+   20:50   0:00 grep node"
#     ]
# }
# 
# PLAY RECAP *************************************************************************************
# 134.209.244.217            : ok=9    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

**Executing tasks with a different user**\
For security reasons it would be better to execute the tasks with an app specific user or a team user instead of the root user. So we have to create a user and then run the application with this user.

Check the documentation for the following module:
- [user](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html)

We can leave the "Install node and npm" play unchanged, because the tools may be installed with the root user. But right after this play we add a new play as follows:

```yaml
- name: Create new Linux user for the node app
  hosts: 134.209.244.217
  tasks:
    - name: Create Linux user
      user:
        name: demo
        comment: Demo user for deploying and running the node app
        group: admin
```

Now adjust the tasks in the "Deploy nodejs application" play to use this new user (read the documentation on [privilege escalation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_privilege_escalation.html) to understand the usage of `become` and `become_user`):

```yaml
- name: Deploy nodejs application
  hosts: 134.209.244.217
  become: yes        # <--
  become_user: demo  # <--
  tasks:
    - name: Copy application tar file to the server and unpack it there
      unarchive:
        src: ../nodejs-app-1.0.0.tgz
        dest: /home/demo/                           # <--
    - name: Install dependencies
      npm:
        path: /home/demo/package                    # <--
    - name: Start application
      command: node /home/demo/package/app/server   # <--
      async: 1000
      poll: 0
    - name: Ensure app is running
      shell: ps aux | grep node
      register: app_status # register the return value of the module into a variable
    - debug: msg={{ app_status.stdout_lines }}
```

Execute the playbook:

```sh
ansible-playbook deploy-node-app.yaml
# PLAY [Install node and npm] ********************************************************************
#
# ...
# 
# PLAY [Create new Linux user for the node app] **************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# ok: [134.209.244.217]
# 
# TASK [Create Linux user] ***********************************************************************
# changed: [134.209.244.217]
# 
# PLAY [Deploy nodejs application] ***************************************************************
# 
# TASK [Gathering Facts] *************************************************************************
# [WARNING]: Module remote_tmp /home/demo/.ansible/tmp did not exist and was created with a mode
# of 0700, this may cause issues when running as another user. To avoid this, create the
# remote_tmp dir with the correct permissions manually
# ok: [134.209.244.217]
# 
# TASK [Copy application tar file to the server and unpack it there] *****************************
# changed: [134.209.244.217]
# 
# TASK [Install dependencies] ********************************************************************
# changed: [134.209.244.217]
# 
# TASK [Start application] ***********************************************************************
# changed: [134.209.244.217]
# 
# TASK [Ensure app is running] *******************************************************************
# changed: [134.209.244.217]
# 
# TASK [debug] ***********************************************************************************
# ok: [134.209.244.217] => {
#     "msg": [
#         "demo       56415 41.0  0.5 598848 46964 ?        Sl   17:32   0:00 node /home/demo/package/app/server",
#         "demo       56435  0.0  0.0   2888   968 pts/1    S+   17:32   0:00 /bin/sh -c ps aux | grep node",
#         "demo       56437  0.0  0.0   7004  2192 pts/1    R+   17:32   0:00 grep node"
#     ]
# }
# 
# PLAY RECAP *************************************************************************************
# 134.209.244.217            : ok=11   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```
