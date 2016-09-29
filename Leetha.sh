#Code to scale up after first Spawn
#Still TBI

#Must use Cloud1 for accounts (any way to change this?)
#Some variables are modified later by fetching data from etcd
. /home/ec2-user/Cloud1
echo "loaded Config file"

echo ""
echo "STARTING"
echo ""


echo ""
echo "$(tput setaf 2) Setting env variables for AWS CLI $(tput sgr 0)"
echo ""
rm -rf ~/.aws/config
mkdir ~/.aws

touch ~/.aws/config

echo "[default]" > ~/.aws/config
echo "AWS_ACCESS_KEY_ID=$K1_AWS_ACCESS_KEY" >> ~/.aws/config
echo "AWS_SECRET_ACCESS_KEY=$K1_AWS_SECRET_KEY" >> ~/.aws/config
echo "AWS_DEFAULT_REGION=$K1_AWS_DEFAULT_REGION" >> ~/.aws/config

echo ""
echo "$(tput setaf 2) Loading env variables from etcd $(tput sgr 0)"
echo ""
#Variables needed

#gets data from previous run
prevawsvms=`(curl http://127.0.0.1:4001/v2/keys/awsvms | jq '.node.value' | sed 's/.//;s/.$//')`
prevgcevms=`(curl http://127.0.0.1:4001/v2/keys/gcevms | jq '.node.value' | sed 's/.//;s/.$//')`
prevhoneypots=`(curl http://127.0.0.1:4001/v2/keys/totalhoneypots | jq '.node.value' | sed 's/.//;s/.$//')`

#swarm-master
publicipSWARMK=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/ip | jq '.node.value' | sed 's/.//;s/.$//')`
SwarmTokenK=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/token | jq '.node.value' | sed 's/.//;s/.$//')`
SwarmVMName=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/name | jq '.node.value' | sed 's/.//;s/.$//')`

#SPAWN_CONSUL
ConsulVMNameK=`(curl http://127.0.0.1:4001/v2/keys/consul/name | jq '.node.value' | sed 's/.//;s/.$//')`
publicipCONSULK=`(curl http://127.0.0.1:4001/v2/keys/consul/ip | jq '.node.value' | sed 's/.//;s/.$//')`
ConsulPortK=`(curl http://127.0.0.1:4001/v2/keys/consul/port | jq '.node.value' | sed 's/.//;s/.$//')`

#spawn-receiver
ReceiverNameK=`(curl http://127.0.0.1:4001/v2/keys/spawn-receiver/name | jq '.node.value' | sed 's/.//;s/.$//')`
publicipspawnreceiver=`(curl http://127.0.0.1:4001/v2/keys/spawn-receiver/ip | jq '.node.value' | sed 's/.//;s/.$//')`
ReceiverPortK=`(curl http://127.0.0.1:4001/v2/keys/spawn-receiver/port | jq '.node.value' | sed 's/.//;s/.$//')`

#etcd
etcdbrowserkVMName=`(curl http://127.0.0.1:4001/v2/keys/etcd-browser/name | jq '.node.value' | sed 's/.//;s/.$//')`
publicipetcdbrowser=`(curl http://127.0.0.1:4001/v2/keys/etcd-browser/address | jq '.node.value' | sed 's/.//;s/.$//')`

#Determines where to spawn

#determines if it must spawn to GCE
if [ $2 -eq 0 ]; then
 GCEKProvision=0
 else
 GCEVM_InstancesK=$2
fi

#Sets the number of VMs to spawn to AWS
VM_InstancesK=$1

#Sets the number of Containers Honeypots to spawn
Container_InstancesK=$3

echo ""
echo "$(tput setaf 2) Scaling up $VM_InstancesK Instances in AWS $(tput sgr 0)"
if [ $GCEKProvision -eq 1 ]; then
  echo "$(tput setaf 2) Scaling up $GCEVM_InstancesK Instances in GCE $(tput sgr 0)"
fi
echo "$(tput setaf 2) Scaling up $Container_InstancesK Container Instances $(tput sgr 0)"


#Sets variables for launching honeypots that will connect to the receiver

echo " "
echo "   _____  _____          _      ______   _    _ _____  "
echo "  / ____|/ ____|   /\   | |    |  ____| | |  | |  __ \ "
echo " | (___ | |       /  \  | |    | |__    | |  | | |__) |"
echo "  \___ \| |      / /\ \ | |    |  __|   | |  | |  ___/ "
echo "  ____) | |____ / ____ \| |____| |____  | |__| | |     "
echo " |_____/ \_____/_/    \_\______|______|  \____/|_| "
echo " "
   
                                                       
                                                     



LOG_HOST=$publicipspawnreceiver
LOG_PORT=$ReceiverPortK

#create new Docker-machines



#Loops for creating Swarm nodes

# THIS IS THE SAME CODE AS THE MAIN SCRIPT
# THIS IS THE SAME CODE AS THE MAIN SCRIPT
# THIS IS THE SAME CODE AS THE MAIN SCRIPT

echo ""
echo "$(tput setaf 2) Creating Swarm Nodes $(tput sgr 0)"

#Starts #GCEVM-InstancesK VMs on GCE using Docker machine and connects them to Swarm
# Spawns to GCE
if [ $GCEKProvision -eq 1 ]; then
  echo ""
  echo "$(tput setaf 1)Spawning to GCE $(tput sgr 0)"
  echo ""
  
  #open Port 80 on GCE VMs
  echo ""
  echo "$(tput setaf 1)Setting Firewall Rules on GCE $(tput sgr 0)"
  echo ""
  #gcloud auth login
  gcloud auth activate-service-account $K2_GOOGLE_AUTH_EMAIL --key-file $GOOGLE_APPLICATION_CREDENTIALS --project $K2_GOOGLE_PROJECT
  #gcloud config set project $K2_GOOGLE_PROJECT
  #Open ports for Swarm
  gcloud compute firewall-rules create swarm-machines --allow tcp:3376 --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT
  #Opens AppPortK for Docker machine on GCE
  gcloud compute firewall-rules create http80-machines --allow tcp:$AppPortK --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT
  #Opens HoneypotPortK for Docker machine on GCE
  gcloud compute firewall-rules create honey-machines --allow tcp:$HoneypotPortK --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT
  
  #Loops for creating Swarm nodes
  #changed to loop to o to preserve naming convention
  #j keeps the count of total VMs consistent with previous run
  
  j=$prevgcevms
  o=0
  while [ $o -lt $GCEVM_InstancesK ]
  do
   
   UUIDK=$(cat /proc/sys/kernel/random/uuid)
   # Makes sure the UUID is lowercase for GCE provisioning
   UUIDKL=${UUIDK,,}
   VMGCEnameK=env-crate-$j
   #VMGCEnameK+="-" #Not used as GCE does not like it
   VMGCEnameK+=$instidk
   echo ""
   echo "Provisioning VM $VMGCEnameK "
   echo ""
  
   #docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-image ubuntu-1510-wily-v20151114 --swarm --swarm-discovery token://$SwarmTokenK SPAWN-GCE$j-K
   docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-type g1-small --swarm --swarm-discovery token://$SwarmTokenK $VMGCEnameK
   #Stores ip of the VM
   docker-machine env $VMGCEnameK > /home/ec2-user/Docker$j
   . /home/ec2-user/Docker$j
  
   publicipKGCE=$(docker-machine ip $VMGCEnameK)
   
   #registers Swarm Slave in Consul
   curl -X PUT -d $VMGCEnameK http://$publicipCONSULK:8500/v1/kv/tc/env-crate-$j/name
   curl -X PUT -d $publicipKGCE http://$publicipCONSULK:8500/v1/kv/tc/env-crate-$j/ip
   
   #Register Swarm slave in etcd
   curl -L http://127.0.0.1:4001/v2/keys/DM-GCE-$j/name -XPUT -d value=$VMGCEnameK
   curl -L http://127.0.0.1:4001/v2/keys/DM-GCE-$j/ip -XPUT -d value=$publicipKGCE
   
   echo ----
   echo "$(tput setaf 1) Machine $publicipKGCE in GCE connected to SWARM $(tput sgr 0)"
   echo ----
   #Increments counter for total GCE VMs
   true $(( j++ ))
   true $(( o++ ))
  done
fi
#Writes total GCE VMs provisioned
GCEVM_InstancesK=$j
#bandaid
if [ $2 -eq 0 ]; then GCEVM_InstancesK=$prevgcevms
fi

echo ""
echo "$(tput setaf 2) Creating swarm Nodes on AWS $(tput sgr 0)"
echo ""

#Starts #VM-InstancesK VMs on AWS using Docker machine and connects them to Swarm

echo ----
echo "Opening Firewall ports for Honeypots"
echo ----
#Opens Firewall Port for Honeypots
aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port $HoneypotPortK --cidr 0.0.0.0/0

i=$prevawsvms
p=0
while [ $p -lt $VM_InstancesK ]
do
    #echo "output: $i"
    UUIDK=$(cat /proc/sys/kernel/random/uuid)
    VMAWSnameK=SPAWN$i-$UUIDK
    VMAWSnameK+="-"
    VMAWSnameK+=$instidk
    #echo Provisioning VM SPAWN$i-$UUIDK
    echo ""
    echo "$(tput setaf 1) Provisioning VM $VMAWSnameK $(tput sgr 0)"
    echo ""
    docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION --swarm --swarm-discovery token://$SwarmTokenK $VMAWSnameK

    #Stores ip of the VM
    docker-machine env $VMAWSnameK > /home/ec2-user/Docker$i
    . /home/ec2-user/Docker$i

    publicipK=$(docker-machine ip $VMAWSnameK)
    
    #registers Swarm Slave in Consul
    curl -X PUT -d $VMAWSnameK http://$publicipCONSULK:8500/v1/kv/tc/SPAWN$i-$UUIDK/name
    curl -X PUT -d $publicipK http://$publicipCONSULK:8500/v1/kv/tc/SPAWN$i-$UUIDK/ip
    
    #Register Swarm slave in etcd
    curl -L http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name -XPUT -d value=$VMAWSnameK
    curl -L http://127.0.0.1:4001/v2/keys/DM-AWS-$i/ip -XPUT -d value=$publicipK
    
    
    echo ----
    echo "$(tput setaf 1) Machine $publicipK connected to SWARM $(tput sgr 0)"
    echo ----
    #Increments countert for total AWS VMs
    true $(( i++ ))
    true $(( p++ ))
done
#Writes total AWS VMs provisioned
VM_InstancesK=$i
#bandaid
if [ $1 -eq 0 ]; then VM_InstancesK=$prevawsvms
fi

#Launches $instancesK Containers using SWARM
#deploy more containers via Docker Swarm
echo ""
echo "$(tput setaf 2) Launching Honeypots instances via Docker Swarm $(tput sgr 0)"
echo ""

#Connects to Swarm
eval $(docker-machine env --swarm $SwarmVMName)

#Sets variables for launching honeypots that will connect to the receiver
LOG_HOST=$publicipspawnreceiver
LOG_PORT=$ReceiverPortK

i=$prevhoneypots
q=0
while [ $q -lt $Container_InstancesK ]
do
    echo "output: $i"
    UUIDK=$(cat /proc/sys/kernel/random/uuid)
    echo Provisioning Container $i
    
    #Launches Honeypots
        docker run -d --name honeypot-$i -e LOG_HOST=$publicipspawnreceiver -e LOG_PORT=$ReceiverPortK -p $HoneypotPortK:$HoneypotPortK $HoneypotImageK 
    #launches nginx (optional)
    #docker run -d --name www-$i -p $AppPortK:$AppPortK nginx
    #Increments counter for honeypots
    true $(( i++ ))
    true $(( q++ ))
done
#Writes total Honeypots provisioned
Container_InstancesK=$i

#Adds total VM instances
#a=`expr "$a" + "$num"`
TotalVMInstancesK=`expr "$GCEVM_InstancesK" + "$VM_InstancesK"`
curl -L http://127.0.0.1:4001/v2/keys/totalvms -XPUT -d value=$TotalVMInstancesK
curl -X PUT -d $TotalVMInstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalvms


#Writes the final total setup in etcd for further scaling

curl -L http://127.0.0.1:4001/v2/keys/awsvms -XPUT -d value=$VM_InstancesK
curl -L http://127.0.0.1:4001/v2/keys/gcevms -XPUT -d value=$GCEVM_InstancesK
curl -L http://127.0.0.1:4001/v2/keys/totalhoneypots -XPUT -d value=$Container_InstancesK


#Register the tasks for this run in Consul
#Postponed as Consul takes some time to start up
curl -X PUT -d $VM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/awsvms
curl -X PUT -d $GCEVM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/gcevms
curl -X PUT -d $Container_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalhoneypots


#Totals provisioned
echo ""
echo "$(tput setaf 6) Total provisioned $(tput sgr 0)"
echo "$(tput setaf 6) AWS VMs = $VM_InstancesK $(tput sgr 0)"
echo "$(tput setaf 6) GCE VMs = $GCEVM_InstancesK $(tput sgr 0)"
echo "$(tput setaf 6) Honeypots = $Container_InstancesK $(tput sgr 0)"


echo ----
echo "$(tput setaf 6) Docker Machine provisioned ( $TotalVMInstancesK ) List ( includes $SwarmVMName $publicipSWARMK ) : $(tput sgr 0)"
echo ----
docker run swarm list token://$SwarmTokenK
echo ----
docker-machine ls
echo ----
echo ""
echo "$(tput setaf 6) Check etcd-browser RUNNING ON $publicipetcdbrowser:8000 $(tput sgr 0)"
echo ""
echo ""
echo "eval ``$``(docker-machine env --swarm $SwarmVMName) "
echo ""
echo "******************************************"

