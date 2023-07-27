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