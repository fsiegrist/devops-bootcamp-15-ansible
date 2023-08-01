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
Login to you DigitalOcean account and create a new droplet (Frankfurt, Ubuntu, Shared CPU, Regular, 1GB / 1CPU). Use the existing SSH key and name it 'ubuntu-ansible-demo-1'. Copy the IP address of the new droplet (134.209.244.217).


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
- [copy](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html#ansible-collections-ansible-builtin-copy-module)
- [unarchive](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/unarchive_module.html#ansible-collections-ansible-builtin-unarchive-module)

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
