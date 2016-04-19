# ProjectSpawnSwarmtc
Project to Spawn a titanium crucible (receiver + multiple honeypots) installation in an automated way accross different Clouds (AWS and optionally GCE) using Docker Machine, Docker Swarm and Docker Discovery. 
A dockerized Consul and etcd instances are used to store variables in a KV store.

Tested on a t1.micro AMI

To install the prerequisites on an AMI image use this piece of code:

https://github.com/FabioChiodini/AWSDockermachine

[the script is run in the context of ec2-user account]

###How to launch

Launch the main script with no parameters (all parameters are stored in the configuration file **Cloud1)

```

./SpawnSwarmtcK.sh

```

## Configuration Files
To run this script you have to prepare two configuration files (in /home/ec2-user)
- **Cloud1** see below for syntax
- **GCEkeyfile.json** used for GCE authentication (see below for instructions)



## Script Flow 

This script creates (leveraging Docker-Machine):

- one VM in AWS with Consul in Docker (used also to prepare docker Discovery). There is an option to run this locally containerized (**remember to open port 8500 if you run this locally**)

- One VM on GCE (g1-small VM type) hosting the receiver application in a container

- One local etcd instance containerized to store local variables (the etcd is not reachable from outside networks)

- One VM in AWS hosting the Docker swarm in a Docker container

- A number of VMs in AWS (specified in the variable export VM_InstancesK) as "slaves" that will host honeypots containers. These are t2.micro VM types

- A number of VMs in GCE (specified in the variable export GCEVM_InstancesK) as "slaves" that will host honeypots containers. These are g1-small VM types

- [Optional] One VM on GCE (g1-small VM type) hosting an etcd browser GUI (to display the data stored in etcd). **Remember to open port 4001 locally (ie on main VM) if you want to be able to access etcd data**

- [in the code there are commented lines to deploy a dockerized nginx via DockerSwarm and opening the relevant port]  


It then starts many Docker Containers (honeypots) via Docker Swarm (the number of instances is specified in the variable InstancesK in the main configuration file)

It also opens up all required port on AWS Security Groups and on GCE Firewall

Currently it opens all ports for Docker Swarm, Docker Machine and SSH plus ports specified in the configuration files for dockerized applications (AppPortK, ReceiverPortK and HoneypotPortK).

Here's an high level diagram: 

![Alt text](/images/Main.png "Main")

## Environment Variables

The code uses a file to load the variables needed (/home/ec2-user/Cloud1).

This file has the following format:

```
export K1_AWS_ACCESS_KEY=AKXXXXXX

export K1_AWS_SECRET_KEY=LXXXXXXXXXX

export K1_AWS_VPC_ID=vpc-XXXXXX

export K1_AWS_ZONE=b

export K1_AWS_DEFAULT_REGION=us-east-1

export AWS_DEFAULT_REGION=us-east-1

export VM_InstancesK=2
export Container_InstancesK=3

export GCEKProvision=1

export GCEVM_InstancesK=1


export K2_GOOGLE_AUTH_EMAIL=XXXXX@developer.gserviceaccount.com
export K2_GOOGLE_PROJECT=XXXXXX
export GOOGLE_APPLICATION_CREDENTIALS="/home/ec2-user/GCEkeyfile.json"

export AppPortK=80

export ReceiverPortK=61116
export ReceiverImageK=kiodo/receiver:latest
export HoneypotPortK=8080
export HoneypotImageK=kiodo/honeypot:latest

export ConsulDynDNSK=1
export DynDNSK=XXXX2.ddns.net

export etcdbrowserprovision=0

export instidk=2
```

Here are the details on how these variables are used:

- The first five variable are used by the docker-machine command and are related to your AWS account

- **AWS_DEFAULT_REGION** variable is used by AWS cli (to edit the security group) 

- **VM_InstancesK** is used to determine the number of VM that will be spawned on AWS 
- **Container_InstancesK** is used to state how many Containers instances will be run

- **GCEKProvision** is a flag to enable provisioning on GCE
- **GCEVM_InstancesK** is used to determine the number of VM that will be spawned on GCE

- **K2_GOOGLE_AUTH_EMAIL** contains the google account email for your GCE project (shown in the manage service accounts panel, this is NOT your google email :P)

- **K2_GOOGLE_PROJECT** contains the project to targte for GCE

- **GOOGLE_APPLICATION_CREDENTIALS** maps to a file containing the Service account keys for your GCE login

- [**AppPortK** is the port that is opened for (optional/code commented out) dockerized nginx instances launched via docker swarm]

- **ReceiverPortK** and **ReceiverImageK** are the port used and the docker image for the receiver Application

- **HoneypotPortK** and **HoneypotImageK** are the port used and the docker image for the honeypot Applications to launch via Docker swarm

- **ConsulDynDNSK** is a flag to determine if the Consul Dockerized instance will be launched locally (to eventually leveragge a local dyndns setup

- **DynDNSK** contains the dyndns name used for the host where this code is launched (ie where the Consul instance will be executed if ConsulDynDNSK=1)

- **etcdbrowserprovision** is a flag to determine if an etcd-browser containerized instance will be launched in GCE 

- **instidk** is a string (that will be added as a prefix to all names of items created) to allow for multiple deployment of tc in the same AWS and GCE instances (avoiding duplicate names)  (**use lowercase string due to GCE docker machine command line limitations**)



![Alt text](/images/Cloud1.png "Cloud1")

The code also uses another file: GCEkeyfile.json 
- This contains data that is used for GCE authentication (Service account keys type in JSON format)


## Service Discovery

For demo purposes two service discovery services are used: Consul and etcd

All the items created by the code are registered in the KV store of **etcd** to allow for further manipulation.

**Consul** is used only for demo purposes (GUI)

### etcd
etcd is launched as a local dockerized applications and stores variables that are used in the main Spawn, in the scale up and tear down code

**jq** is installed on the local AMI (automatically during Spawn execution) to manipulate JSON files in shell scripts

#### etcd-browser

An application (etcd-browser) has been added for showing in a web GUI the data that gets stored to etcd:

![Alt text](/images/etcd-browser.png "etcd-browser")

To enable the use of this application it is necessary to **manually** open port 4001 on the VM where the main script is launched. App port (8000) for etcd-browser is opend up automatically.


![Alt text](/images/Port4001.png "Port4001")

**Added value**: The etcd broswer is also useful for testing this code as you can change values inside etcd directly from its web interface

### Consul

**Important note**: If Consul is launched locally (DynDNS option)  it is necessary to **manually** open port 8500 on the VM where the main script is launched.

Following are some examples of the Consul outputs.

Main KV tree:

![Alt text](/images/ConsulRegistration-3.png "ConsulRegistration-3")

Example entry (with IP) for the Docker Machine hosting the Receiver:

![Alt text](/images/ConsulRegistration-4.png "ConsulRegistration-4")

## NOTES ON Spawning to GCE

To spawn VMs to GCE you need to **Install the GCE SDK** on your AMI image:
- curl https://sdk.cloud.google.com | bash
- exec -l $SHELL
- gcloud init (this will start an interactive setup/configuration)

You also need to propely set up your GCE account, following are the high level steps:

- Enable the Compute Engine API

- Create credentials (Service account keys type - JSON format) and download the json file to /home/ec2-user/GCEkeyfile.json

- Enable billing for your account

Then you need to perform these configurations in the /home/ec2-user/Cloud1 file:

- Populate the configuration file with your GCE account details
- Enable the flag to provision to GCE
- Indicate a number of VMs to provision to GCE


##Scale Out Code

Leetha.sh is the code that automates the scale out of the setup after the first deployment

It reads configuration information from the etcd local instances (to connect to swarm, set up docker-machine and to launch honeypots).

It then launches a number of Docker VMs and honeypot containers as specified with the following launch parameters

###How to launch

```

./Leetha.sh instancestoaddAWS instancestoaddGCE HoneypotsToSpawn 

```
During the launch it also respawns Honeypots containers that were already started in previous runs as these are ephemeral workloads (Still TBI, now it just adds containers specified in launch parameters)

Added value (:P) : If launched without parameters the code opens up all firewall port needed by the application


##Scale Down Code

Redeemer.sh is the code that automates the scale down of the setup after the first deployment

It reads configuration information from the etcd local instances (to connect to swarm, set up docker-machine, gets the number of Docker machines and honeypots and to restart honeypots).

It then destroys the specified Docker machine instances in GCE or AWS. It also cleans up the relevant registrations in etcd and Consul (Consul TBI).

It then restarts honeypot containers to match the number specified with the following launch parameters

###How to launch

```

./Redeemer.sh instancestoremoveinAWS instancestoremoveinGCE HoneypotsToremove 

```
During the launch it also respawns Honeypots containers that were already started in previous runs as these are ephemeral workloads.

This code does NOT reopen firewall ports in GCE or AWs.


##Tear Down Code

Malebolgia.sh is the code that automates the environment teardown

It reads configuration information from the etcd local instances (to connect to swarm, set up docker-machine and to launch honeypots).

It then destroys:
- Docker machine VMs provisioned (by doing so kills all honeypot instances)
- Infrastructure Components (Docker Swarm, Receiver and Consul)
- it then destroys local Docker instances (etcd and eventually Consul if local)
- 

###How to launch

```
./Malebolgia.sh
```

##Continous Integration Code

This code is meant to help in testing the elements deployed by the main code and validate that any change to the base code has been successful

The code tests these components:
- Data written in etcd
- Honeypots
- Receiver Instance
- Consul

After getting the setup details from etcd it tests if the ports are open for the components listed and basically test the application.

###How to launch:

```
./CISpawntc
```

The results of the tests are written in etcd:



Running these tests multiple times updates the test flags value in etcd.

Still TBI

# Minimal Launch Instructions

Following are high level notes on how to get this running quickly:

- Start a t1.small on AWS

- Open ports for this VM on AWS
 - 22 (to reach it ;) )
 - 4001 (all IPs) for etcd-browser
 - 8500 (all IPs) for Consul

![Alt text](/images/MainInboundRules.png "MainInboundRules")

- Connect via SSH to your AWS instance (ie in my case: Get PuTTy configured with AWS key :P )

- Run AWSDockermachine code

- Populate /home/ec2-user/Cloud1

- Populate /home/ec2-user/GCE JSON (if using GCE)

- git clone this code : https://github.com/FabioChiodini/ProjectSpawnSwarmtc.git

- Launch script


@FabioChiodini



