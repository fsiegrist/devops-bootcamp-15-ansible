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
Create a new Droplet on DigitalOcean:
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



</details>

******

<details>
<summary>Exercise 3: Install Jenkins on EC2</summary>
<br />

**Tasks:**

Your team wants to automate creating Jenkins instances dynamically when needed. So your task is to write an Ansible code that creates a new EC2 server and installs and runs Jenkins on it. It also installs nodejs, npm and docker to be available for Jenkins builds.

Now your team can use this project to spin up a new Jenkins server with 1 Ansible command.

**Solution:**



</details>

******

<details>
<summary>Exercise 4: Install Jenkins on Ubuntu</summary>
<br />

**Tasks:**

Your company has infrastructure on multiple platforms. So in addition to creating the Jenkins instance dynamically on an EC2 server, you want to support creating it on an Ubuntu server too. Your task it to re-write your playbook (using include_tasks or conditionals) to support both flavors of the OS.

**Solution:**



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



</details>

******