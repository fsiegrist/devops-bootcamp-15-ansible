## Exercises for Module 15 "Configuration Management with Ansible"
<br />

<details>
<summary>Exercise 1: Build & Deploy Java Artifact</summary>
<br />

**Tasks:**

You want to help developers automate deploying a Java application on a remote server directly from their local environment. So you create an Ansible project that builds the java application in the Java-gradle project. Then deploys the built jar artifact to a remote Ubuntu server.

Developers will execute the Ansible script by specifying their first name as the Linux user which will start the application on a remote server. If the Linux User for that name doesn't exist yet on the remote server, Ansible playbook will create it.

Also consider that the application may already be running from the previous jar file deployment, so make sure to stop the application and remove the old jar file from the remote server first, before copying and deploying the new one, also using Ansible.

**Solution:**

**Step 1:** Create an Ubuntu server on DigitalOcean\
Login to your account on [DigitalOcean](https://cloud.digitalocean.com/login) and create a new Droplet:
- Frankfurt
- Ubuntu 22.04
- Shared CPU (Basic)
- Regular (Disk type: SSD)
- 1GB/1CPU 25GB SSD
- SSH Key (fesimba)
- Hostname 'ansible-exercise-1'

**Step 2:** Install the "acl" package\
Install the "acl" package that includes "setfacl" command on the Ubuntu machine, so that Ansible can set temporary file permissions correctly, when connecting to the server as an unprivileged user (ubuntu) and becoming another unprivileged user (my-user); see [becoming an unprivileged user](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_privilege_escalation.html#risks-of-becoming-an-unprivileged-user)

```sh
ssh root@64.226.68.131

sudo apt-get update -y
sudo apt-get install -y acl
```

**Step 3:** Create hosts file\
Create a file called `ex1-hosts` with the following content:
```conf
[web_server]
64.226.68.131 ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_user=root
```

**Step 4:** Create playbook\
Create a file called `ex1-build-and-deploy.yaml` with the following content:

```yaml
- name: Create Linux user
  hosts: web_server
  gather_facts: True
  become: True
  tasks:
  - name: Create Linux user
    user:
      name: "{{ linux_user }}"
      group: adm

- name: Make sure Java is installed
  hosts: web_server
  become: True
  tasks:
  - name: Update apt repo cache
    apt: update_cache=yes force_apt_get=yes cache_valid_time=3600
  - name: Install java version 11
    apt: name=openjdk-11-jre-headless

- name: Build application
  hosts: localhost
  gather_facts: False
  tasks:
  - name: Build jar
    command:
      chdir: "{{ project_dir }}"
      cmd: ./gradlew clean build

- name: Stop the currently running java application and remove old jar file
  hosts: web_server
  become: True
  become_user: "{{ linux_user }}"
  tasks:
  - name: Find jar file
    find: 
      paths: /home/{{ linux_user }} 
      patterns: "*.jar"
      file_type: file
    register: find_result
  - debug: msg={{find_result}}  

  - name: Get the PID of Java running process
    ignore_errors: yes
    shell: "ps -few | grep java | awk '{print $2}'"
    register: running_java_processes
    when: find_result.files != []
  - debug: msg={{running_java_processes}}
  - name: Kill running Java process
    ignore_errors: yes
    shell: "kill {{ running_java_processes.stdout_lines[0] }}"
    when: running_java_processes.stdout_lines | length > 2
  
  - name: Remove the jar file
    shell: rm {{find_result.files[0].path}}
    when: find_result.files != []

- name: Deploy java application
  hosts: web_server
  become: True
  become_user: "{{ linux_user }}"
  tasks:
  - name: Copy jar file to remote server
    copy:
      src: "{{ project_dir }}/build/libs/{{ jar_name }}" # local machine
      dest: /home/{{ linux_user }} # remote machine
  - name: Start the application
    command: 
      chdir: /home/{{ linux_user }}
      cmd: java -jar {{ jar_name }} & 
    async: 1000 # without async and poll will hang 
    poll: 0
    register: result
  - debug: msg="{{ result }}"  
  - name: Check that application started and is running
    shell: ps aux | grep java
    register: app_status
  - debug: msg="{{ app_status.stdout_lines }}"   
```

**Step 5:** Run the playbook\
Execute the following command to run the playbook:
```sh
ansible-playbook -i ex1-hosts ex1-build-and-deploy.yaml --extra-vars "linux_user=fesi project_dir=./java-app/ jar_name=bootcamp-java-project-1.0-SNAPSHOT.jar"

# PLAY [Create Linux user] **************************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [64.226.68.131]
# 
# TASK [Create Linux user] **************************************************************************************************************************
# changed: [64.226.68.131]
# 
# PLAY [Make sure Java is installed] ****************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [64.226.68.131]
# 
# TASK [Update apt repo cache] **********************************************************************************************************************
# ok: [64.226.68.131]
# 
# TASK [Install java version 11] *********************************************************************************************************************
# changed: [64.226.68.131]
# 
# PLAY [Build application] **************************************************************************************************************************
# 
# TASK [Build jar] **********************************************************************************************************************************
# changed: [localhost]
# 
# PLAY [Stop the currently running java application and remove old jar file] ************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# [WARNING]: Module remote_tmp /home/fesi/.ansible/tmp did not exist and was created with a mode of 0700, this may cause issues when running as
# another user. To avoid this, create the remote_tmp dir with the correct permissions manually
# ok: [64.226.68.131]
# 
# TASK [Find jar file] ******************************************************************************************************************************
# ok: [64.226.68.131]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [64.226.68.131] => {
#     "msg": {
#         "changed": false,
#         "examined": 5,
#         "failed": false,
#         "files": [],
#         "matched": 0,
#         "msg": "All paths examined",
#         "skipped_paths": {}
#     }
# }
# 
# TASK [Get the PID of Java running process] ********************************************************************************************************
# skipping: [64.226.68.131]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [64.226.68.131] => {
#     "msg": {
#         "changed": false,
#         "false_condition": "find_result.files != []",
#         "skip_reason": "Conditional result was False",
#         "skipped": true
#     }
# }
# 
# TASK [Kill running Java process] ******************************************************************************************************************
# fatal: [64.226.68.131]: FAILED! => {"msg": "The conditional check 'running_java_processes.stdout_lines | length > 2' failed. The error was: error while evaluating conditional (running_java_processes.stdout_lines | length > 2): 'dict object' has no attribute 'stdout_lines'. 'dict object' has no attribute 'stdout_lines'\n\nThe error appears to be in '/Users/fsiegrist/Development/devops_bootcamp/15-Configuration-Management-With-Ansible/devops-bootcamp-15-ansible/exercises/ex1-build-and-deploy.yaml': line 48, column 5, but may\nbe elsewhere in the file depending on the exact syntax problem.\n\nThe offending line appears to be:\n\n  - debug: msg={{running_java_processes}}\n  - name: Kill running Java process\n    ^ here\n"}
# ...ignoring
# 
# TASK [Remove the jar file] ************************************************************************************************************************
# skipping: [64.226.68.131]
# 
# PLAY [Deploy java application] ********************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [64.226.68.131]
# 
# TASK [Copy jar file to remote server] *************************************************************************************************************
# changed: [64.226.68.131]
# 
# TASK [Start the application] **********************************************************************************************************************
# changed: [64.226.68.131]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [64.226.68.131] => {
#     "msg": {
#         "ansible_job_id": "j720708936685.10900",
#         "changed": true,
#         "failed": 0,
#         "finished": 0,
#         "results_file": "/home/fesi/.ansible_async/j720708936685.10900",
#         "started": 1
#     }
# }
# 
# TASK [Check that application started and is running] **********************************************************************************************
# changed: [64.226.68.131]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [64.226.68.131] => {
#     "msg": [
#         "fesi       10909  108  5.7 2271192 57036 ?       Sl   22:23   0:01 java -jar bootcamp-java-project-1.0-SNAPSHOT.jar &",
#         "fesi       10938  0.0  0.0   2888   992 pts/1    S+   22:23   0:00 /bin/sh -c ps aux | grep java",
#         "fesi       10940  0.0  0.2   7004  2072 pts/1    S+   22:23   0:00 grep java"
#     ]
# }
# 
# PLAY RECAP ****************************************************************************************************************************************
# 64.226.68.131              : ok=14   changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=1   
# localhost                  : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

</details>

******

<details>
<summary>Exercise 2: Push Java Artifact to Nexus</summary>
<br />

**Tasks:**

Developers like the convenience of running the application directly from their local dev environment. But after they test the application and see that everything works, they want to push the successful artifact to Nexus repository. So you write a play book that allows them to specify the jar file and pushes it to the team's Nexus repository. 

**Solution:**

**Prerequisites: Create a Nexus server on DigitalOcean**

**Step 1:** Create an Ubuntu server on DigitalOcean\
Login to your account on [DigitalOcean](https://cloud.digitalocean.com/login) and create a new Droplet:
- Frankfurt
- Ubuntu 22.04
- Shared CPU (Basic)
- Regular (Disk type: SSD)
- 4GB/2CPUs 80GB SSD
- SSH Key (fesimba)
- Hostname 'nexus-server'

=> Droplet IP address: 134.122.88.22

**Step 2:** Install Java and net-tools
```sh
# SSH into the server
ssh root@134.122.88.22

# install Java version 8 (needed for Nexus) and net-tools (needed for the netstat command):
apt update
apt install openjdk-8-jre-headless
apt install net-tools
```

**Step 3:** Install Nexus
```sh
# download and unpack the latest Nexus version into the /opt folder
cd /opt
wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz
tar -zxvf latest-unix.tar.gz
```

**Step 4:** Create nexus user
```sh
adduser nexus

# change the privileges for the unpacked folders (nexus user needs to access both):
chown -R nexus:nexus nexus-3.59.0-01
chown -R nexus:nexus sonatype-work
```

**Step 5:** Configure Nexus to run with the nexus user we just created\
Add `run_as_user="nexus"` to the file `nexus-3.59.0-01/bin/nexus.rc` using vim.

**Step 6:** Start Nexus
```sh
# switch to the nexus user and start Nexus
su - nexus
/opt/nexus-3.59.0-01/bin/nexus start

# check the port on which Nexus is running
ps aux | grep nexus # shows the PID of the nexus process
netstat -tlnp # shows that the process with the nexus PID is listening on port 8081
```

So go to the DigitalOcean admin webpage and add a firewall rule opening the port 8081 for all IP addresses.

**Step 7:** Change the admin user's password
- Open your browser and navigate to `http://134.122.88.22:8081` to access the Nexus login page. 
- There is a predefined `admin` user. Its password is stored in `/opt/sonatype-work/nexus3/admin.password`. Log in with this password and change it. 
- Login again with the new password.

**Create and run the Ansible Playbook:**

**Step 1:** Create the Ansible Playbook\
Create a file called `ex2-push-to-nexus.yaml` with the following content:
```yaml
- name: Push to Nexus repo
  hosts: localhost
  gather_facts: False
  tasks:
  - name: Push jar artifact to Nexus repo
    # This protects password from being displayed in task output. Comment out if you want to see the output for debugging
    no_log: True
    
    uri:
      # Notes on Nexus upload artifact URL:
      # 1 - You can add group name in the url ".../com/my/group/{{ artifact_name }}..."
      # 2 - The file name (my-app-1.0-SNAPSHOT.jar) must match the url path of (.../com/my-app/1.0-SNAPSHOT/my-app-1.0-SNAPSHOT.jar), otherwise it won't work
      # 3 - You can only upload file with SNAPSHOT in the version into the maven-snapshots repo, so naming matters
      url: "{{ nexus_url }}/repository/maven-snapshots/com/my/group/{{ artifact_name }}/{{ artifact_version }}/{{ artifact_name }}-{{ artifact_version }}.jar"
      
      method: PUT
      src: "{{ jar_file_path }}"
      user: "{{ nexus_user }}"
      password: "{{ nexus_password }}"
      force_basic_auth: yes
      
      # With default "raw" body_format request form is too large, and causes 500 server error on Nexus (Form is larger than max length 200000), So we are setting it to 'json'
      body_format: json
      
      status_code:
      - 201
```

Create a file called `ex2-hosts` with the following content:
```conf
[localhost]
```

**Step 2:** Run the playbook\
Execute the following command to run the playbook:
```sh
ansible-playbook -i ex2-hosts ex2-push-to-nexus.yaml --extra-vars "nexus_url=http://134.122.88.22:8081 \
  nexus_user=admin \
  nexus_password=******* \
  repository_name=maven-snapshots \
  artifact_name=bootcamp-java-project \
  artifact_version=1.0-SNAPSHOT \
  jar_file_path=./java-app/build/libs/bootcamp-java-project-1.0-SNAPSHOT.jar"

# PLAY [Push to Nexus repo] *************************************************************************************************************************
# 
# TASK [Push jar artifact to Nexus repo] ************************************************************************************************************
# ok: [localhost]
# 
# PLAY RECAP ****************************************************************************************************************************************
# localhost                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

Login to the Nexus server as admin user and browse the maven-snapshot repository to check, whether the jar has been uploaded successfully. Or open the browser and navigate to 'http://134.122.88.22:8081/service/rest/repository/browse/maven-snapshots/com/my/group/bootcamp-java-project/1.0-SNAPSHOT/'.

</details>

******

<details>
<summary>Exercise 3: Install Jenkins on EC2</summary>
<br />

**Tasks:**

Your team wants to automate creating Jenkins instances dynamically when needed. So your task is to write an Ansible code that creates a new EC2 server and installs and runs Jenkins on it. It also installs nodejs, npm and docker to be available for Jenkins builds.

Now your team can use this project to spin up a new Jenkins server with 1 Ansible command.

**Solution:**

Login to your AWS Management Console and create a key-pair called 'ec2-key-pair'. Copy the downloaded 'ec2-key-pair.pem' file to the '~/.ssh' directory.

Create a file called `ex3-provision-jenkins-ec2.yaml` with the following content:
```yaml
# Play Provision Jenkins Server
- name: Provision Jenkins server
  hosts: localhost
  gather_facts: false
  tasks:
  - name: get vpc_information
    amazon.aws.ec2_vpc_net_info:
      region: "{{ aws_region }}"
      filters:
        is-default: True
    register: vpc_info
  - debug: msg={{ vpc_info }}
  - amazon.aws.ec2_vpc_subnet_info:
      filters:
        vpc-id: "{{ vpc_info.vpcs[0].vpc_id }}"
        default-for-az: True
    register: subnet_info
  - debug: msg={{ subnet_info }}
  - name: Start an instance with a public IP address
    amazon.aws.ec2_instance:
      name: "jenkins-server"
      key_name: "{{ key_name }}"
      region: "{{ aws_region }}"
      vpc_subnet_id: "{{ subnet_info.subnets[0].id }}"
      instance_type: t2.medium
      security_group: default
      network:
        assign_public_ip: true
      image_id: "{{ ami_id }}"
      tags:
        server: Jenkins
    register: ec2_result
  # On creation, ec2_result object doesn't get public_ip attribute immediately, because the assignment takes time, so we wait and then query again
  - pause:
      seconds: 60
  - name: Get public_ip address of the ec2 instance 
    amazon.aws.ec2_instance_info:
      region: "{{ aws_region }}"
      instance_ids:
      - "{{ ec2_result.instance_ids[0] }}"
    register: ec2_result
  - name: update hosts file
    lineinfile:
      path: "ex3-hosts-jenkins-server"
      line: "{{ ec2_result.instances[0].public_ip_address }} ansible_ssh_private_key_file={{ ssh_key_path }} ansible_user={{ ssh_user }}"
      insertbefore: BOF
    register: file_result
  - debug: msg={{ file_result }}
```

Create a second file called `ex3-install-jenkins-ec2.yaml` with the following content:
```yaml
# Play Get Server Address
- name: Get server ip 
  hosts: localhost
  gather_facts: false
  tasks:
  - name: Get public_ip address of the ec2 instance 
    amazon.aws.ec2_instance_info:
      region: "{{ aws_region }}"
      filters:
        "tag:Name": "jenkins-server"
    register: ec2_info

# Play Prepare Jenkins Server - with all needed tools, Jenkins, Docker, Nodejs & npm
- name: Prepare server for Jenkins
  hosts: "{{ hostvars['localhost']['ec2_info'].instances[0].public_ip_address }}"
  become: yes
  tasks:
  - name: Install Java
    yum:
      name: java-17-amazon-corretto-devel
      update_cache: yes
      state: present
  - name: Install Jenkins Repository
    get_url:
      url: https://pkg.jenkins.io/redhat-stable/jenkins.repo
      dest: /etc/yum.repos.d/jenkins.repo
  - name: Import RPM key
    rpm_key:
      key: https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
      state: present
  - name: Install daemonize dependency for Jenkins
    command: amazon-linux-extras install epel -y # repository that provides 'daemonize'
  - name: Install /etc/yum.repos.d/jenkins.repo
    yum:
      name: jenkins
      update_cache: yes
      state: present
  - name: Install Docker
    yum: 
      name: docker
      update_cache: yes
      state: present
  - name: Check that nvm installed
    stat:
      path: ~/.nvm
    register: stat_result
  - name: Download installer
    get_url: 
      url: https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh
      dest: ./install.sh
    when: not stat_result.stat.exists
  - name: 
    shell: bash install.sh
    when: not stat_result.stat.exists
  - name: install node
    shell: "source /root/.nvm/nvm.sh && nvm install 8.0.0 && node --version" 
    args:
      executable: /bin/bash
    register: cmd_result
  - debug: msg={{ cmd_result }}

# Play Start Jenkins
- name: Start Jenkins
  hosts: "{{ hostvars['localhost']['ec2_info'].instances[0].public_ip_address }}"
  become: yes
  tasks:
  - name: Start Jenkins server
    service:
      name: jenkins
      state: started
  - name: Wait 10 seconds to check the Jenkins port
    pause:
      seconds: 10  
  - name: Check that application started with netstat
    command: netstat -plnt 
    register: app_status
  - debug: msg={{ app_status }} 
  - name: Print out Jenkins admin password
    slurp:
      src: /var/lib/jenkins/secrets/initialAdminPassword
    register: jenkins_pwd
    # output the passeword base64 encoded; to decode it, execute: echo '...debug-output...' | base64 -d
  - debug: msg={{ jenkins_pwd['content'] }}
```

Finally create an emtpy file called `ex3-hosts-jenkins-server`:
```sh
touch ex3-hosts-jenkins-server
```

Now run the playbook `ex3-provision-jenkins-ec2.yaml` to provision an EC2 instance:
```sh
ansible-playbook ex3-provision-jenkins-ec2.yaml --extra-vars "aws_region=eu-central-1 \
    ami_id=ami-0aa74281da945b6b5 \
    key_name=ec2-key-pair \
    ssh_key_path=~/.ssh/ec2-key-pair.pem \
    ssh_user=ec2-user" 

# [WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'
# 
# PLAY [Provision Jenkins server] *******************************************************************************************************************
# 
# TASK [get vpc_information] ************************************************************************************************************************
# ok: [localhost]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [localhost] => {
#     "msg": {
#         "changed": false,
#         "failed": false,
#         "vpcs": [
#             {
#                 "cidr_block": "172.31.0.0/16",
#                 "cidr_block_association_set": [
#                     {
#                         "association_id": "vpc-cidr-assoc-0af7b313aeed307a7",
#                         "cidr_block": "172.31.0.0/16",
#                         "cidr_block_state": {
#                             "state": "associated"
#                         }
#                     }
#                 ],
#                 "dhcp_options_id": "dopt-07901edc546c6cacb",
#                 "enable_dns_hostnames": true,
#                 "enable_dns_support": true,
#                 "id": "vpc-04acd8f40d2f4b8e9",
#                 "instance_tenancy": "default",
#                 "is_default": true,
#                 "owner_id": "369076538622",
#                 "state": "available",
#                 "tags": {},
#                 "vpc_id": "vpc-04acd8f40d2f4b8e9"
#             }
#         ]
#     }
# }
# 
# TASK [amazon.aws.ec2_vpc_subnet_info] *************************************************************************************************************
# ok: [localhost]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [localhost] => {
#     "msg": {
#         "changed": false,
#         "failed": false,
#         "subnets": [
#             {
#                 "assign_ipv6_address_on_creation": false,
#                 "availability_zone": "eu-central-1a",
#                 "availability_zone_id": "euc1-az2",
#                 "available_ip_address_count": 4089,
#                 "cidr_block": "172.31.32.0/20",
#                 "default_for_az": true,
#                 "enable_dns64": false,
#                 "id": "subnet-05725cf7170e2d028",
#                 "ipv6_cidr_block_association_set": [],
#                 "ipv6_native": false,
#                 "map_customer_owned_ip_on_launch": false,
#                 "map_public_ip_on_launch": true,
#                 "owner_id": "369076538622",
#                 "private_dns_name_options_on_launch": {
#                     "enable_resource_name_dns_a_record": false,
#                     "enable_resource_name_dns_aaaa_record": false,
#                     "hostname_type": "ip-name"
#                 },
#                 "state": "available",
#                 "subnet_arn": "arn:aws:ec2:eu-central-1:369076538622:subnet/subnet-05725cf7170e2d028",
#                 "subnet_id": "subnet-05725cf7170e2d028",
#                 "tags": {},
#                 "vpc_id": "vpc-04acd8f40d2f4b8e9"
#             }
#         ]
#     }
# }
# 
# TASK [Start an instance with a public IP address] *************************************************************************************************
# changed: [localhost]
# 
# TASK [pause] **************************************************************************************************************************************
# Pausing for 60 seconds
# (ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
# ok: [localhost]
# 
# TASK [Get public_ip address of the ec2 instance] **************************************************************************************************
# ok: [localhost]
# 
# TASK [update hosts file] **************************************************************************************************************************
# changed: [localhost]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [localhost] => {
#     "msg": {
#         "backup": "",
#         "changed": true,
#         "diff": [
#             {
#                 "after": "",
#                 "after_header": "ex3-hosts-jenkins-server (content)",
#                 "before": "",
#                 "before_header": "ex3-hosts-jenkins-server (content)"
#             },
#             {
#                 "after_header": "ex3-hosts-jenkins-server (file attributes)",
#                 "before_header": "ex3-hosts-jenkins-server (file attributes)"
#             }
#         ],
#         "failed": false,
#         "msg": "line added"
#     }
# }
# 
# PLAY RECAP ****************************************************************************************************************************************
# localhost                  : ok=9    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

At the end of the playbook, the IP address, key-file and ssh-user information is written to the file `ex3-hosts-jenkins-server`. Now we can execute the playbook `ex3-install-jenkins-ec2.yaml` to install Jenkins on the provisioned EC2 instance:
```sh
ansible-playbook -i ex3-hosts-jenkins-server ex3-install-jenkins-ec2.yaml --extra-vars "aws_region=eu-central-1"

# PLAY [Get server ip] ******************************************************************************************************************************
# 
# TASK [Get public_ip address of the ec2 instance] **************************************************************************************************
# ok: [localhost]
# 
# PLAY [Prepare server for Jenkins] *****************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# [WARNING]: Platform linux on host 3.70.187.221 is using the discovered Python interpreter at /usr/bin/python3.7, but future installation of
# another Python interpreter could change the meaning of that path. See https://docs.ansible.com/ansible-
# core/2.15/reference_appendices/interpreter_discovery.html for more information.
# ok: [3.70.187.221]
# 
# TASK [Install Java] *******************************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [Install Jenkins Repository] *****************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [Import RPM key] *****************************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [Install daemonize dependency for Jenkins] ***************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [Install /etc/yum.repos.d/jenkins.repo] ******************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [Install Docker] *****************************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [Check that nvm installed] *******************************************************************************************************************
# ok: [3.70.187.221]
# 
# TASK [Download installer] *************************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [shell] **************************************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [install node] *******************************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [3.70.187.221] => {
#     "msg": {
#         "changed": true,
#         "cmd": "source /root/.nvm/nvm.sh && nvm install 8.0.0 && node --version",
#         "delta": "0:01:07.656024",
#         "end": "2023-08-30 21:36:46.868725",
#         "failed": false,
#         "msg": "",
#         "rc": 0,
#         "start": "2023-08-30 21:35:39.212701",
#         "stderr_lines": [
#             "Downloading https://nodejs.org/dist/v8.0.0/node-v8.0.0-linux-x64.tar.xz...",
#             ...
#             "Computing checksum with sha256sum",
#             "Checksums matched!"
#         ],
#         "stdout_lines": [
#             "Downloading and installing node v8.0.0...",
#             "Now using node v8.0.0 (npm v5.0.0)",
#             "Creating default alias: \u001b[0;32mdefault\u001b[0m \u001b[0;90m->\u001b[0m \u001b[0;32m8.0.0\u001b[0m (\u001b[0;90m->\u001b[0m \u001b[0;32mv8.0.0\u001b[0m)",
#             "v8.0.0"
#         ]
#     }
# }
# 
# PLAY [Start Jenkins] ******************************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [3.70.187.221]
# 
# TASK [Start Jenkins server] ***********************************************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [Wait 10 seconds to check the Jenkins port] **************************************************************************************************
# Pausing for 10 seconds
# (ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
# ok: [3.70.187.221]
# 
# TASK [Check that application started with netstat]  ***********************************************************************************************
# changed: [3.70.187.221]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [3.70.187.221] => {
#     "msg": {
#         "changed": true,
#         "cmd": [
#             "netstat",
#             "-plnt"
#         ],
#         "delta": "0:00:00.015095",
#         "end": "2023-08-30 21:51:51.120041",
#         "failed": false,
#         "msg": "",
#         "rc": 0,
#         "start": "2023-08-30 21:51:51.104946",
#         "stderr": "",
#         "stderr_lines": [],
#         "stdout_lines": [
#             "Aktive Internetverbindungen (Nur Server)",
#             "Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    ",
#             "tcp        0      0 0.0.0.0:111             0.0.0.0:*               LISTEN      2704/rpcbind        ",
#             "tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      3292/sshd           ",
#             "tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      3150/master         ",
#             "tcp6       0      0 :::111                  :::*                    LISTEN      2704/rpcbind        ",
#             "tcp6       0      0 :::8080                 :::*                    LISTEN      16249/java          ",
#             "tcp6       0      0 :::22                   :::*                    LISTEN      3292/sshd           "
#         ]
#     }
# }
# 
# TASK [Print out Jenkins admin password] ***********************************************************************************************************
# ok: [3.70.187.221]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [3.70.187.221] => {
#     "msg": "MWQzNmIxMzg0MmIzNDc0ZGI0Njc4ODQ4OWQwZWJmYTYK"
# }
# 
# PLAY RECAP ****************************************************************************************************************************************
# 3.70.187.221               : ok=17   changed=4    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   
# localhost                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

The debug output at the end displays the initial Jenkins admin password base64 encoded. To decode it, execute the following command:
```sh
echo 'MWQzNmIxMzg0MmIzNDc0ZGI0Njc4ODQ4OWQwZWJmYTYK' | base64 -d
# 1d36b13842b3474db46788489d0ebfa6
```

Login to the AWS Management Console and add an inbound rule to the default security group of the VPC the EC2 instance is running in, that allows access to port 8080 from all IP addresses. Then open the browser and navigate to 'http://3.70.187.221:8080'. Enter the decoded password ('1d36b13842b3474db46788489d0ebfa6').

</details>

******

<details>
<summary>Exercise 4: Install Jenkins on Ubuntu</summary>
<br />

**Tasks:**

Your company has infrastructure on multiple platforms. So in addition to creating the Jenkins instance dynamically on an EC2 server, you want to support creating it on an Ubuntu server too. Your task it to re-write your playbook (using include_tasks or conditionals) to support both flavors of the OS.

**Solution:**

- To **provision** the EC2 instances, the playbook `ex3-provision-jenkins-ec2.yaml` is executed for both amazon-linux and ubuntu servers. The only difference between the two is the "ami_id" value. So you either provide the "amazon-linux" ami-id or the "ubuntu" ami-id.
- To **install** Jenkins, the playbook `ex4-install-jenkins.yaml` is executed, which contains the shared tasks and dynamically selects the `ex4-host-amazon.yaml` or `ex4-host-ubuntu.yaml` files, which contain the OS specific differences. The selection is based on what "host_os" variable you provide.

**Create and configure Jenkins on --amazon-linux-- EC2 instance:**
```sh
ansible-playbook ex3-provision-jenkins-ec2.yaml --extra-vars "aws_region=eu-central-1 \
    ami_id=ami-0aa74281da945b6b5 \
    key_name=ec2-key-pair \
    ssh_key_path=~/.ssh/ec2-key-pair.pem \
    ssh_user=ec2-user"

# Wait until the server is fully initialised

ansible-playbook -i ex3-hosts-jenkins-server ex4-install-jenkins.yaml --extra-vars "host_os=amazon-linux \
    aws_region=eu-central-1"
```

**Create and configure Jenkins on --ubuntu-- EC2 instance:**
```sh
ansible-playbook ex3-provision-jenkins-ec2.yaml --extra-vars "aws_region=eu-central-1 \
    ami_id=ami-04e601abe3e1a910f \
    key_name=ec2-key-pair \
    ssh_key_path=~/.ssh/ec2-key-pair.pem \
    ssh_user=ubuntu"

# Wait until the server is fully initialised

ansible-playbook -i ex3-hosts-jenkins-server ex4-install-jenkins.yaml --extra-vars "host_os=ubuntu \
    aws_region=eu-central-1"

# PLAY [Get server ip] ******************************************************************************************************************************
# 
# TASK [Get public_ip address of the ec2 instance] **************************************************************************************************
# ok: [localhost]
# 
# PLAY [Prepare server for Jenkins] *****************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [3.127.223.76]
# 
# TASK [Include task for amazon-linux server] *******************************************************************************************************
# skipping: [3.127.223.76]
# 
# TASK [Include task for ubuntu server] *************************************************************************************************************
# included: /Users/fsiegrist/Development/devops_bootcamp/15-Configuration-Management-With-Ansible/devops-bootcamp-15-ansible/exercises/ex4-host-ubuntu.yaml for 3.127.223.76
# 
# TASK [Update apt repo cache] **********************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Install java 11] ****************************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Add GPG keys] *******************************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Install Jenkins from debian package repository] *********************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Update apt repo cache] **********************************************************************************************************************
# ok: [3.127.223.76]
# 
# TASK [Install Jenkins] ****************************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Install Docker] *****************************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Start Docker] *******************************************************************************************************************************
# ok: [3.127.223.76]
# 
# TASK [Check that nvm installed] *******************************************************************************************************************
# ok: [3.127.223.76]
# 
# TASK [Download nvm installer] *********************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Install nvm] ********************************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [Install node] *******************************************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [3.127.223.76] => {
#     "msg": {
#         "changed": true,
#         "cmd": "source /root/.nvm/nvm.sh && nvm install 8.0.0 && node --version",
#         "delta": "0:00:02.741504",
#         "end": "2023-08-31 21:15:13.658672",
#         "failed": false,
#         "msg": "",
#         "rc": 0,
#         "start": "2023-08-31 21:15:10.917168",
#         "stderr_lines": [
#             "Downloading https://nodejs.org/dist/v8.0.0/node-v8.0.0-linux-x64.tar.xz...",
#             "",
#             "                                                                           0.5%",
#             "######################################################################## 100.0%",
#             "Computing checksum with sha256sum",
#             "Checksums matched!"
#         ],
#         "stdout_lines": [
#             "Downloading and installing node v8.0.0...",
#             "Now using node v8.0.0 (npm v5.0.0)",
#             "Creating default alias: \u001b[0;32mdefault\u001b[0m \u001b[0;90m->\u001b[0m \u001b[0;32m8.0.0\u001b[0m (\u001b[0;90m->\u001b[0m \u001b[0;32mv8.0.0\u001b[0m)",
#             "v8.0.0"
#         ]
#     }
# }
# 
# PLAY [Start Jenkins] ******************************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [3.127.223.76]
# 
# TASK [Start Jenkins server] ***********************************************************************************************************************
# ok: [3.127.223.76]
# 
# TASK [Wait 10 seconds to check the Jenkins port] **************************************************************************************************
# Pausing for 10 seconds
# (ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
# ok: [3.127.223.76]
# 
# TASK [Check that application started with netstat] ************************************************************************************************
# changed: [3.127.223.76]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [3.127.223.76] => {
#     "msg": {
#         "changed": true,
#         "cmd": [
#             "netstat",
#             "-plnt"
#         ],
#         "delta": "0:00:00.008945",
#         "end": "2023-08-31 21:15:27.273439",
#         "failed": false,
#         "msg": "",
#         "rc": 0,
#         "start": "2023-08-31 21:15:27.264494",
#         "stderr": "",
#         "stderr_lines": [],
#         "stdout_lines": [
#             "Active Internet connections (only servers)",
#             "Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    ",
#             "tcp        0      0 127.0.0.1:43501         0.0.0.0:*               LISTEN      6197/containerd     ",
#             "tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      409/systemd-resolve ",
#             "tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      678/sshd: /usr/sbin ",
#             "tcp6       0      0 :::8080                 :::*                    LISTEN      5759/java           ",
#             "tcp6       0      0 :::22                   :::*                    LISTEN      678/sshd: /usr/sbin "
#         ]
#     }
# }
# 
# TASK [Print out Jenkins admin password] ***********************************************************************************************************
# ok: [3.127.223.76]
# 
# TASK [debug] **************************************************************************************************************************************
# ok: [3.127.223.76] => {
#     "msg": "NjkwOGY4YTJmYjYwNDk3YmIyM2NkNTllOTE1ZTZjYmIK"
# }
# 
# PLAY RECAP ****************************************************************************************************************************************
# 3.127.223.76               : ok=22   changed=10   unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
# localhost                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

To decode the initial Jenkins admin password, execute the following command:
```sh
echo 'NjkwOGY4YTJmYjYwNDk3YmIyM2NkNTllOTE1ZTZjYmIK' | base64 -d
# 6908f8a2fb60497bb23cd59e915e6cbb
```

Login to the AWS Management Console and add an inbound rule to the default security group of the VPC the EC2 instance is running in, that allows access to port 8080 from all IP addresses (if you haven't done this step at the end of exercise 3). Then open the browser and navigate to 'http://3.127.223.76:8080'. Enter the decoded password ('6908f8a2fb60497bb23cd59e915e6cbb').

</details>

******

<details>
<summary>Exercise 5: Install Jenkins as a Docker Container</summary>
<br />

**Tasks:**

In addition to having different OS flavors as an option, your team also wants to be able to run Jenkins as a docker container. So you write another playbook that starts Jenkins as a Docker container with volumes for Jenkins home and Docker itself, because you want to be able to execute Docker commands inside Jenkins.

Here is a reference of a full docker command for starting Jenkins container, which you should map to Ansible playbook:

```sh
docker run --name jenkins -p 8080:8080 -p 50000:50000 -d \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /usr/local/bin/docker:/usr/bin/docker \
-v jenkins_home:/var/jenkins_home \
jenkins/jenkins:lts
```

Your team is happy, because they can now use Ansible to quickly spin up a Jenkins server for different needs. 

**Solution:**

We run the Docker container on an EC2 instance with the Ubuntu OS installed. So first we provision an Ubuntu server and then start a Docker container running Jenkins.

**Provision the Ubuntu Jenkins server:**
```sh
ansible-playbook ex3-provision-jenkins-ec2.yaml --extra-vars "aws_region=eu-central-1 \
    ami_id=ami-04e601abe3e1a910f \
    key_name=ec2-key-pair \
    ssh_key_path=~/.ssh/ec2-key-pair.pem \
    ssh_user=ubuntu"
```

Wait until the server is fully initialised. The run the second playbook.

**Configure the server to run Jenkins as a Docker container:**
```sh
ansible-playbook -i ex3-hosts-jenkins-server ex5-install-jenkins-docker.yaml --extra-vars "aws_region=eu-central-1"

# PLAY [Get server ip] ******************************************************************************************************************************
# 
# TASK [Get public_ip address of the ec2 instance] **************************************************************************************************
# ok: [localhost]
# 
# PLAY [Prepare server for Jenkins] *****************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [3.79.57.39]
# 
# TASK [Update apt repo cache] **********************************************************************************************************************
# changed: [3.79.57.39]
# 
# TASK [Install Docker] *****************************************************************************************************************************
# changed: [3.79.57.39]
# 
# TASK [Install pip3] *******************************************************************************************************************************
# changed: [3.79.57.39]
# 
# TASK [Install Docker python module] ***************************************************************************************************************
# changed: [3.79.57.39]
# 
# TASK [Start Docker Service] ***********************************************************************************************************************
# ok: [3.79.57.39]
# 
# PLAY [Start Jenkins container on ec2 instance] ****************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [3.79.57.39]
# 
# TASK [Get location of docker executable] **********************************************************************************************************
# changed: [3.79.57.39]
# 
# TASK [Start Jenkins container] ********************************************************************************************************************
# changed: [3.79.57.39]
# 
# PLAY [Set Docker permission] **********************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [3.79.57.39]
# 
# TASK [Set docker permission for Jenkins user] *****************************************************************************************************
# changed: [3.79.57.39]
# 
# PLAY RECAP ****************************************************************************************************************************************
# 3.79.57.39                 : ok=11   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
# localhost                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

To get the initial admin password, ssh into the EC2 instance, enter the Docker container and read the file `/var/jenkins_home/secrets/initialAdminPassword`:
```sh
ssh -i ~/.ssh/ec2-key-pair.pem ubuntu@3.79.57.39

docker ps
# CONTAINER ID   IMAGE                 COMMAND                  CREATED         STATUS         PORTS                                              NAMES
# e097274dd1a9   jenkins/jenkins:lts   "/usr/bin/tini -- /u…"   4 minutes ago   Up 4 minutes   0.0.0.0:8080->8080/tcp, 0.0.0.0:50000->50000/tcp   jenkins

docker exec -it jenkins /bin/sh
cat /var/jenkins_home/secrets/initialAdminPassword
# 41e5655a8f3c4dd2a97cf920866ca6f5

exit # docker container
exit # ec2
```

Since Jenkins listens on port 8080 in the Docker container and this port is mapped to the host's port 8080, we still have to make sure, the port 8080 of the EC2 server is accessible from the internet. So login to the AWS Management Console and add an inbound rule to the default security group of the VPC the EC2 instance is running in, that allows access to port 8080 from all IP addresses (if you haven't done this step at the end of exercise 3 or 4). Then open the browser and navigate to 'http://3.79.57.39:8080'. Enter the password ('41e5655a8f3c4dd2a97cf920866ca6f5').

</details>

******

<details>
<summary>Exercise 6: Web server and Database server configuration</summary>
<br />

**Tasks:**

Great, you have helped automate some IT processes in your company. Now another team wants your support as well. They want to automate deploying and configuring web server and database server on AWS. The project is not dockerized and they are using a traditional application setup.

The setup you and the team agreed on is the following: You create a dedicated Ansible server on AWS. In the same VPC as the Ansible server, you create 2 servers, 1 for deploying your Java application and another one for running a MySQL database. Also, the database should not be accessible from outside, only within the VPC, so the DB server shouldn't have a public IP address.

So your task is to:
- Provision and configure dedicated Ansible server
  - Write Ansible playbook that provisions a dedicated ansible-control plane server
  - Write Ansible playbook that configures the ansible server with all needed tools as well as copies all needed ansible playbooks and configuration for execution there
- Provision and configure databse and web servers
  - Write Ansible playbook that provisions database and web servers.
  - Write Ansible playbook that installs and starts MySQL server on the EC2 instance without public IP address. And deploys and runs the Java web application on another EC2 instance

Notes:
- Use an existing mysql role for installing mysql on the database server, instead of writing the whole logic yourself
- The last 2 playbooks for provisioning and configuring web and database servers will be executed from Ansible control server, because we can't access the database private IP address from outside VPC
- Since the database server will have no public IP address, it will not have a direct internet access. But we will need to download and install some tools, like mysql service itself on the server, and you can do it via NAT gateway. So make sure to create database server in a "private" subnet, with NAT gateway instead of Internet gateway configuration. 

Once all the playbooks executed successfully, check that the java application is running and accessible from browser at http://web-server-public-address:8080

**Solution:**

**Create AWS key-pairs:**\
Login to your AWS Management Console and create an AWS key-pair called `ansible-managed-server-key` for the web server and database server, download it to your local machine and set the permission to 400:
```sh
mv ~/Downloads/ansible-managed-server-key.pem ~/.ssh/ansible-managed-server-key.pem
chmod 400 ~/.ssh/ansible-managed-server-key.pem
```

Create another AWS key-pair called `ansible-control-server-key` for the ansible control server, download it to your local machine and set the permission to 400:
```sh
mv ~/Downloads/ansible-control-server-key.pem ~/.ssh/ansible-control-server-key.pem
chmod 400 ~/.ssh/ansible-control-server-key.pem
```

**Adjust ex6-inventory_aws_ec2.yaml:**\
Set the correct AWS region, in which you want to create all your servers, inside `ex6-inventory_aws_ec2.yaml` file:
```yaml
regions: 
  - eu-central-1
```

**Adjust ansible.cfg:**\
Comment in lines 6,7,8 inside ansible.cfg file, to enable the aws_ec2 plugin and configure remote user:
```conf
enable_plugins = amazon.aws.aws_ec2
remote_user = ubuntu
private_key_file = /home/ubuntu/ansible-managed-server-key.pem
```

**Important:** Since we are creating the database server without public ip address, by default it won't have internet access. But we need outgoing internet access on the database server in order to be able to download and install packages and tools, including the mysql service itself, so we need to configure that with the following steps:
- Create a NAT gateway called "my-nat" in one of the PUBLIC subnets, meaning subnets with internet gateway configured in the associated route table. Allocate elastic IP address to the NAT when creating it.
- Create a new route table called "my-db-rt" and add a route: destination: 0.0.0.0/0, target: "my-nat".
- In the subnet associations of the route table, select a subnet in which you will create your database server. So this will be our "private" subnet.
- Copy the 2 subnet ids, 1 public subnet id in which we created the NAT gateway and 1 private subnet id which we assosiated with the "my-db-rt" route table. 

Because we will create the "ansible-server" and "web-server" in the public subnet and "database-server" in the private subnet, we are going to provide them as variables values to our playbook:
- private-subnet-id: subnet-0612df896fce7720f
- public-subnet-id: subnet-05725cf7170e2d028

**Build Java MySQL Application:**
```sh
cd bootcamp-java-mysql
./gradlew build
```

**Execute playbooks to provision ansible control server and configure it with all needed tools and files:**
```sh
ansible-playbook ex6-provision-ansible-server.yaml --extra-vars "aws_region=eu-central-1 \
    ami_id=ami-04e601abe3e1a910f \
    key_name=ansible-control-server-key \
    subnet_id=subnet-05725cf7170e2d028"

# Wait until the server is fully initialised
# public ip: 3.120.148.191

ansible-playbook -i ex6-inventory_aws_ec2.yaml ex6-configure-ansible-server.yaml

# PLAY [Install Ansible] ****************************************************************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Uninstall preinstalled ansible version] *****************************************************************************************************
# ok: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Update apt repo cache] **********************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Install software-properties-common (needed for ppa support)] ********************************************************************************
# ok: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Add ansible repo] ***************************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Install ansible and pip3] *******************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Install ansible role, collection, python packages, files] ***********************************************************************************
# 
# TASK [Gathering Facts] ****************************************************************************************************************************
# ok: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Install mysql role from galaxy] *************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Install ansible collection for ec2 module] **************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Install pip3 packages for aws] **************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Ensure .aws dir exists] *********************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Copy aws credentials] ***********************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Copy private ssh key for the app servers] ***************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=~/.ssh/ansible-control-server-key.pem)
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=~/.ssh/ansible-managed-server-key.pem)
# 
# TASK [Copy ansible playbook and configuration files] **********************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=./ex6-configure-ansible-server.yaml)
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=./ex6-provision-ansible-server.yaml)
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=./ex6-configure-app-servers.yaml)
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=./ex6-provision-app-servers.yaml)
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=./ex6-vars.yaml)
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com] => (item=./ex6-inventory_aws_ec2.yaml)
# 
# TASK [Copy ansible config file] *******************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# TASK [Copy java jar file] *************************************************************************************************************************
# changed: [ec2-3-120-148-191.eu-central-1.compute.amazonaws.com]
# 
# PLAY RECAP ****************************************************************************************************************************************
# ec2-3-120-148-191.eu-central-1.compute.amazonaws.com : ok=16   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

**SSH into ansible control server to execute the playbooks for configuring database and web servers:**
```sh
ssh -i ~/.ssh/ansible-control-server-key.pem ubuntu@3.120.148.191

# Execute to provision both (ubuntu) servers inside the same VPC
ansible-playbook ex6-provision-app-servers.yaml --extra-vars "aws_region=eu-central-1 \
    ami_id=ami-04e601abe3e1a910f \
    key_name=ansible-managed-server-key \
    subnet_id_web=subnet-05725cf7170e2d028 \
    subnet_id_db=subnet-0612df896fce7720f"

# ---------------------------------------------
# Wait until both servers are fully initialised
# -> public ip of web-server: 18.193.111.18
# ---------------------------------------------

ansible-playbook -i ex6-inventory_aws_ec2.yaml ex6-configure-app-servers.yaml

# PLAY [Configure Database server] *******************************************************************************************************************************
# 
# TASK [Gathering Facts] *****************************************************************************************************************************************
# ok: [ip-172-31-1-248.eu-central-1.compute.internal]
# 
# TASK [geerlingguy.mysql : ansible.builtin.include_tasks] *******************************************************************************************************
# included: /home/ubuntu/.ansible/roles/geerlingguy.mysql/tasks/variables.yml for ip-172-31-1-248.eu-central-1.compute.internal
# 
# TASK [geerlingguy.mysql : Include OS-specific variables.] ******************************************************************************************************
# ok: [ip-172-31-1-248.eu-central-1.compute.internal] => (item=/home/ubuntu/.ansible/roles/geerlingguy.mysql/vars/Debian.yml)
# 
# TASK [geerlingguy.mysql : Define mysql_packages.] **************************************************************************************************************
# ok: [ip-172-31-1-248.eu-central-1.compute.internal]
# 
# TASK [geerlingguy.mysql : Define mysql_daemon.] ****************************************************************************************************************
# ok: [ip-172-31-1-248.eu-central-1.compute.internal]
# 
# ...
# 
# TASK [geerlingguy.mysql : Check if MySQL is already installed.] ************************************************************************************************
# ok: [ip-172-31-1-248.eu-central-1.compute.internal]
# 
# ...
# 
# TASK [geerlingguy.mysql : Get MySQL version.] ******************************************************************************************************************
# ok: [ip-172-31-1-248.eu-central-1.compute.internal]
# 
# ...
# 
# TASK [geerlingguy.mysql : Ensure MySQL databases are present.] *************************************************************************************************
# changed: [ip-172-31-1-248.eu-central-1.compute.internal] => (item={'name': 'my-app-db', 'encoding': 'latin1', 'collation': 'latin1_general_ci'})
# 
# ...
# 
# TASK [validate mysql service started] **************************************************************************************************************************
# changed: [ip-172-31-1-248.eu-central-1.compute.internal]
# 
# TASK [debug] ***************************************************************************************************************************************************
# ok: [ip-172-31-1-248.eu-central-1.compute.internal] => {
#     "msg": [
#         "mysql       2980 19.6 37.9 1624064 375068 ?      Ssl  15:58   0:00 /usr/sbin/mysqld",
#         "root        3250  0.0  0.0   2888   972 pts/1    S+   15:58   0:00 /bin/sh -c ps aux | grep mysql",
#         "root        3252  0.0  0.2   7004  2272 pts/1    S+   15:58   0:00 grep mysql"
#     ]
# }
# 
# RUNNING HANDLER [geerlingguy.mysql : restart mysql] ************************************************************************************************************
# [WARNING]: Ignoring "sleep" as it is not used in "systemd"
# changed: [ip-172-31-1-248.eu-central-1.compute.internal]
# 
# PLAY [Install Java] ********************************************************************************************************************************************
# 
# TASK [Gathering Facts] *****************************************************************************************************************************************
# ok: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com]
# 
# TASK [Update apt repo cache] ***********************************************************************************************************************************
# changed: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com]
# 
# TASK [Instal java 11] ******************************************************************************************************************************************
# changed: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com]
# 
# PLAY [Configure web server] ************************************************************************************************************************************
# 
# TASK [Gathering Facts] *****************************************************************************************************************************************
# ok: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com]
# 
# TASK [Copy jar file to server] *********************************************************************************************************************************
# changed: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com]
# 
# TASK [Start java application with needed env vars] *************************************************************************************************************
# changed: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com]
# 
# TASK [Validate java app started] *******************************************************************************************************************************
# changed: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com]
# 
# TASK [debug] ***************************************************************************************************************************************************
# ok: [ec2-18-193-111-18.eu-central-1.compute.amazonaws.com] => {
#     "msg": [
#         "ubuntu      4393 37.0  4.6 2269136 45900 ?       Sl   15:59   0:00 java -jar java-app.jar &",
#         "ubuntu      4411  0.0  0.0   2888   976 pts/0    S+   15:59   0:00 /bin/sh -c ps aux | grep java",
#         "ubuntu      4413  0.0  0.2   7004  2236 pts/0    S+   15:59   0:00 grep java"
#     ]
# }
# 
# PLAY RECAP *****************************************************************************************************************************************************
# ec2-18-193-111-18.eu-central-1.compute.amazonaws.com : ok=8    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
# ip-172-31-1-248.eu-central-1.compute.internal : ok=40   changed=11   unreachable=0    failed=0    skipped=18   rescued=0    ignored=0 
```

Make sure to open port 8080 for the web server and access the application via http://18.193.111.18:8080 from browser to make sure the application was successfuly deployed.

</details>

******

<details>
<summary>Exercise 7: Deploy Java MySQL Application in Kubernetes</summary>
<br />

**Tasks:**

After some time, the team decides they want to move to a more modern infrastructure setup, so they want to dockerize their application and start deploying to a K8s cluster.

However, K8s is a very new tool for them, and they don't want to learn kubectl and K8s configuration syntax and how all that works, so they want the deployment process to be automated so that it's much easier for them to deploy the application to the cluster without much K8s knowledge.

So they ask you to help them in the process. You create K8s configuration files for deployments, services for Java and MySQL applications as well as configMap and Secret for the Database connectivity. You also want to access your web application from browser, so you will have to deploy nginx-ingress controller chart and create ingress component for your java app. And you deploy everything in a cluster using an Ansible automated script.

Note: MySQL application will run as 1 replica and for the Java Application you will need to create and push an image to a Docker repo. You can create the K8s cluster with TF script or any other way you prefer.

**Solution:**

**Dockerize the Java application:**\
The Docker image of the application we want to run is `fsiegrist/fesi-repo:bootcamp-java-mysql-project-1.0` (that's how we are referencing it in `k8s-manifests/exercise-7/java-app.yaml`). Make sure this image is available in the private repository `fsiegrist/fesi-repo` on Docker-Hub. 

If it's not, switch to the 'bootcamp-java-mysql' project folder, build the application using Gradle, build an amd64 image and push it to the repository using the following commands:
```sh
cd bootcamp-java-mysql
./gradlew build
docker buildx create --use
docker login
docker buildx build --platform linux/amd64 -t fsiegrist/fesi-repo:bootcamp-java-mysql-project-1.0 --push .
```

**Create k8s cluster:**\
Execute the following commands to provision the AWS EKS cluster:
```sh
cd ex7-terraform
terraform init
terraform apply --auto-approve
```

**Set environment variable for accessing k8s cluster with kubectl and Ansible:**
```sh
aws eks update-kubeconfig --name myapp-eks-cluster
export KUBECONFIG=~/.kube/config
```

<!-- Not needed on AWS EKS (Ingress is replaced by cloud-native LoadBalancer): Set value of the ingress host in file k8s-manifests/exercise-7/java-app-ingress.yaml, which you will use to access the java app from browser -->

**Execute playbook:**\
Execute the playbook to deploy k8s manifests (make sure you have Docker running locally when executing the playbook):
```sh
ansible-playbook ex7-deploy-on-k8s.yaml --extra-vars "docker_user=fsiegrist docker_pass=your-dockerhub-password"
```

**Note:** If you get an error on creating ingress component related to "nginx-controller-admission" webhook, than manually delete the ValidationWebhook and try again. To delete the ValidationWebhook:
```sh
kubectl get ValidatingWebhookConfiguration # gives you the name
kubectl delete ValidatingWebhookConfiguration {name}
```



</details>

******

<details>
<summary>Exercise 8: Deploy MySQL Chart in Kubernetes</summary>
<br />

**Tasks:**

Everything works great, but the team worries about the application availability, so wants to run the MySQL DB in multiple replicas. So they ask you to help them solve this problem. Your task is to deploy a MySQL with 3 replicas from a helm chart using Ansible script in place of the currently running single MySQL instance. 

**Solution:**

**Set environment variable for accessing k8s cluster with kubectl and Ansible:**
```sh
aws eks update-kubeconfig --name myapp-eks-cluster
export KUBECONFIG=~/.kube/config
```

Set value of the ingress host in file k8s-manifests/exercise-8/java-app-ingress.yaml, which you will use to access the java app from browser.

Remove the currently running mysql deployment, that we created in exercise 7:
```sh
kubectl delete deployment mysql-deployment
```

Execute playbook to deploy the mysql chart in your already existing k8s cluster:
```sh
ansible-playbook ex8-deploy-on-k8s.yaml --extra-vars "docker_user=fsiegrist docker_pass=your-dockerhub-password"
```

</details>

******

Amazing, now you have automated a lot of things in your project's workflows, which means less manual work and well documented DevOps processes! Really well done!
