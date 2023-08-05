## Demo Project - Nexus Deployment

### Topics of the Demo Project
Automate Nexus deployment

### Technologies Used
- Ansible
- Nexus
- DigitalOcean
- Java
- Linux

### Project Description
- Create Server on DigitalOcean
- Write Ansible Playbook that creates Linux user for Nexus, configure server, installs and deploys Nexus and verifies that it is running successfully


#### Steps to create a server on DigitalOcean
Login to your account on [DigitalOcean](https://cloud.digitalocean.com/login) and create a new Droplet (Frankfurt, Ubuntu, Shared CPU, Regular, 1GB / 1CPU). Use the existing SSH key and name it 'ubuntu-ansible-demo-2'. Copy the IP address of the new droplet (134.122.74.168).


#### Steps to write an Ansible Playbook that deploys Nexus

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
  134.122.74.168 ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_user=root
  ```
- Finally create an empty playbook file called `deploy-nexus.yaml`

The playbook we're going to write is a translation of the manual steps we did in the demo project of Module 06. Written as a shell script they would look like this:

```sh
# install Java version 8 (needed for Nexus) and net-tools (needed for final verification):
apt update
apt install openjdk-8-jre-headless
apt install net-tools

# download and unpack the latest Nexus version into the /opt folder
cd /opt
wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz
tar -zxvf latest-unix.tar.gz

# create nexus user
adduser nexus

# change the privileges for the unpacked folders (nexus user needs to access both):
chown -R nexus:nexus nexus-3.46.0-01
chown -R nexus:nexus sonatype-work

# add 'run_as_user="nexus"' to the file 'nexus-3.46.0-01/bin/nexus.rc' using vim

# switch to the nexus user and start Nexus
su - nexus
/opt/nexus-3.46.0-01/bin/nexus start

# check the port on which Nexus is running
ps aux | grep nexus shows
netstat -tlnp # shows that the process with the nexus PID is listening on port 8081
```

**Install Java and net-tools**\
Add the following play to the playbook 'deploy-nexus.yaml':
```yaml
- name: Install Java and net-tools
  hosts: 134.122.74.168
  tasks:
    - name: Update apt repo and cache
      apt:
        force_apt_get: yes
        update_cache: yes
        cache_valid_time: 3600
    - name: Install Java 8
      apt: name=openjdk-8-jre-headless
    - name: Install net-tools
      apt: name=net-tools
```

**Download and unpack Nexus installer**\
Check the documentation for the following modules:
- [get_url](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/get_url_module.html)
- [find](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/find_module.html)
- [stat](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/stat_module.html)

Also check the documentation of [conditionals](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html).

Add the following play to the playbook 'deploy-nexus.yaml':
```yaml

- name: Download and unpack Nexus installer
  hosts: 134.122.74.168
  tasks:
    - name: Download Nexus
      get_url:
        url: https://download.sonatype.com/nexus/3/latest-unix.tar.gz
        dest: /opt/
      register: download_result
    - name: Untar Nexus installer
      unarchive:
        src: "{{ download_result.dest }}" # dest = e.g. '/opt/nexus-3.58.1-02-unix.tar.gz'
        dest: /opt/
        remote_src: yes
    - name: Find nexus folder
      find:
        paths: /opt
        pattern: "nexus-*"
        file_type: directory
      register: find_result
    - name: Check nexus folder stats
      stat:
        path: /opt/nexus
      register: stat_result
    - name: Rename nexus folder
      shell: mv {{ find_result.files[0].path }} /opt/nexus # find_result.files[0].path = e.g. '/opt/nexus-3.58.1-02'
      when: not stat_result.stat.exists # conditional task execution
      
```