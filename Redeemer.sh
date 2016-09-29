#Scale Down script
# ./ Redeemer.sh awsmachinetoscaledown gcemachinestoscaledown finalnumberofHoneypots

#Loads variables from etcd

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
prevawsvmsK=`(curl http://127.0.0.1:4001/v2/keys/awsvms | jq '.node.value' | sed 's/.//;s/.$//')`
prevgcevmsK=`(curl http://127.0.0.1:4001/v2/keys/gcevms | jq '.node.value' | sed 's/.//;s/.$//')`
prevhoneypotsK=`(curl http://127.0.0.1:4001/v2/keys/totalhoneypots | jq '.node.value' | sed 's/.//;s/.$//')`

#Storing parameters as numbers
prevawsvms=`expr "$prevawsvmsK" + 0`
prevgcevms=`expr "$prevgcevmsK" + 0`
prevhoneypots=`expr "$prevhoneypotsK" + 0`

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

#etcdbrowser
etcdbrowserkVMName=`(curl http://127.0.0.1:4001/v2/keys/etcd-browser/name | jq '.node.value' | sed 's/.//;s/.$//')`
publicipetcdbrowser=`(curl http://127.0.0.1:4001/v2/keys/etcd-browser/address | jq '.node.value' | sed 's/.//;s/.$//')`

#determines what to do

#Determines where to destroy

#determines if it must spawn to GCE
if [ $2 -eq 0 ]; then
 GCEKProvision=0
 else
 GCEDestroyK=$2
fi

#Sets the number of VMs to destroy AWS
AWSDestroyK=$1

#Sets the number of Containers Honeypots to spawn
#a=`expr "$a" + "$num"`
Container_InstancesK=`expr "$prevhoneypots" - "$3"`

echo ""

echo ""
echo "$(tput setaf 2) Scaling down $AWSDestroyK Instances in AWS $(tput sgr 0)"
if [ $GCEKProvision -eq 1 ]; then
  echo "$(tput setaf 2) Scaling down $GCEDestroyK Instances in GCE $(tput sgr 0)"
fi
echo "$(tput setaf 2) Scaling down $3 Container Instances $(tput sgr 0)"


echo " "
echo "   _____  _____          _      ______   _____   ______          ___   _ "
echo "  / ____|/ ____|   /\   | |    |  ____| |  __ \ / __ \ \        / / \ | |"
echo " | (___ | |       /  \  | |    | |__    | |  | | |  | \ \  /\  / /|  \| |"
echo "  \___ \| |      / /\ \ | |    |  __|   | |  | | |  | |\ \/  \/ / | . ` |"
echo "  ____) | |____ / ____ \| |____| |____  | |__| | |__| | \  /\  /  | |\  |"
echo " |_____/ \_____/_/    \_\______|______| |_____/ \____/   \/  \/   |_| \_|"
echo " "


#Destroys all existing honeypots

echo ""
echo "$(tput setaf 2) Destroying Honeypots instances via Docker Swarm $(tput sgr 0)"
echo ""

#Connects to Swarm
eval $(docker-machine env --swarm $SwarmVMName)

#Sets variables for launching honeypots that will connect to the receiver
LOG_HOST=$publicipspawnreceiver
LOG_PORT=$ReceiverPortK

i=0
while [ $i -lt $prevhoneypots ]
do
    echo "output: $i"
    #UUIDK=$(cat /proc/sys/kernel/random/uuid)
    echo Destroying Container $i
    
    #Destroys Honeypots
    docker rm -f honeypot-$i 
    
    #destroys nginx (optional)
    #docker rm -f www-$i 
    #Increments counter for honeypots
    true $(( i++ ))
    
done
#Writes total Honeypots destroyed
ContainersDestroyK=$i

echo ""
echo "$(tput setaf 6) Destroyed $ContainersDestroyK Honeypots $(tput sgr 0)"
echo ""

#Writes the final total setup in etcd for further scaling
curl -L http://127.0.0.1:4001/v2/keys/totalhoneypots -XPUT -d value=0

#writes the same info in Consul
curl -X PUT -d '0' http://$publicipCONSULK:8500/v1/kv/tc/totalhoneypots

#Destroys N-x GCE VMs

echo ""
echo "$(tput setaf 2) Scaling down Swarm Nodes in GCE $(tput sgr 0)"
echo ""
#destroys $GCEDestroyK VMs on GCE using Docker machine and connects them to Swarm
# Spawns to GCE
if [ $GCEKProvision -eq 1 ]; then
  echo ""
  echo "$(tput setaf 1) Spawning to GCE $(tput sgr 0)"
  echo ""
  
  #Loops for destroying Swarm nodes
 
  #a=`expr "$a" + "$num"`
  j=`expr "$prevgcevms" - "$GCEDestroyK"`
  
  while [ $j -lt $prevgcevms ]
   do
   
   VMKill=`(curl http://127.0.0.1:4001/v2/keys/DM-GCE-$j/name | jq '.node.value' | sed 's/.//;s/.$//')`
   echo ""
   echo "Destroying VM $VMKill "
   echo ""
  
   docker-machine rm -f $VMKill
   
   #DEregisters Swarm Slave in Consul
   curl -X DELETE http://$publicipCONSULK:8500/v1/kv/tc/DM-GCE-$j/name
   curl -X DELETE http://$publicipCONSULK:8500/v1/kv/tc/DM-GCE-$j/ip
   curl -X DELETE http://$publicipCONSULK:8500/v1/kv/tc/DM-GCE-$j
   
   #DeRegisters Swarm slave in etcd
   curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-GCE-$j/name
   curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-GCE-$j/ip
   curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-GCE-$j/TEST
   curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-GCE-$j/SYNTHETICTEST
   #deletes entire Key
   curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-GCE-$j\?recursive\=true
   
   
   echo ----
   echo "$(tput setaf 1) Machine $VMKill in GCE removed from SWARM $(tput sgr 0)"
   echo ----
   #Increments counter for total GCE VMs
   true $(( j++ ))
   done
fi
#Writes total active GCE VMs 
GCEVM_InstancesK=`expr "$prevgcevms" - "$GCEDestroyK"`

#Writes data to Consul
curl -X PUT -d $GCEVM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/gcevms

#Writes data to etcd
curl -L http://127.0.0.1:4001/v2/keys/gcevms -XPUT -d value=$GCEVM_InstancesK

#Destroys N-y AWS DM

echo ""
echo "$(tput setaf 2) Scaling down swarm Nodes on AWS $(tput sgr 0)"
echo ""

#Destroys $AWSDestroyK VMs on AWS 
#a=`expr "$a" + "$num"`

i=`expr "$prevawsvms" - "$AWSDestroyK"`

#echo ""
#echo prevawsvms = $prevawsvms
#echo AWSDestroyK = $AWSDestroyK
#echo i= $i
#echo ""

while [ $i -lt $prevawsvms ]
do
    VMKill=`(curl http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name | jq '.node.value' | sed 's/.//;s/.$//')`
    echo ""
    echo VMKill $VMKill 
    echo ""
    #http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name -XPUT
    #echo Provisioning VM SPAWN$i-$UUIDK
    echo ""
    echo "$(tput setaf 1) Destroying VM $VMKill $(tput sgr 0)"
    echo ""
    docker-machine rm -f $VMKill
    echo i =$i
    #DE registers Swarm Slave in Consul
    curl -X DELETE http://$publicipCONSULK:8500/v1/kv/tc/DM-AWS-$i/name
    curl -X DELETE http://$publicipCONSULK:8500/v1/kv/tc/DM-AWS-$i/ip
    curl -X DELETE http://$publicipCONSULK:8500/v1/kv/tc/DM-AWS-$i
    
    #DERegister Swarm slave in etcd
    curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name
    curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-AWS-$i/ip
    curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-AWS-$i/TEST
    curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-AWS-$i/SYNTHETICTEST
    #deletes entire Key
    curl -L -X DELETE http://127.0.0.1:4001/v2/keys/DM-AWS-$i\?recursive\=true
    
    
    #Increments counter for total AWS VMs
    true $(( i++ ))
done
#Writes total AWS VMs provisioned
VM_InstancesK=`expr "$prevawsvms" - "$AWSDestroyK"`

#Writes the stuff in etcd
curl -X PUT -d $VM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/awsvms

#Writes the data in consul
curl -L http://127.0.0.1:4001/v2/keys/awsvms -XPUT -d value=$VM_InstancesK

#Respawns honeypots
#Launches $Container_InstancesK Containers using SWARM

echo ""
echo "$(tput setaf 2) Launching Honeypots instances via Docker Swarm $(tput sgr 0)"
echo ""

#Connects to Swarm
eval $(docker-machine env --swarm $SwarmVMName)


#Sets variables for launching honeypots that will connect to the receiver
LOG_HOST=$publicipspawnreceiver
LOG_PORT=$ReceiverPortK



i=0
echo ""
echo Spawning $Container_InstancesK Honeypots
echo ""
while [ $i -lt $Container_InstancesK ]
do
    echo "output: $i"
    UUIDK=$(cat /proc/sys/kernel/random/uuid)
    echo Provisioning Container $i
    
    #Launches Honeypots
    #docker run -d --name honeypot-$i -p $HoneypotPortK:$HoneypotPortK $HoneypotImageK
    docker run -d --name honeypot-$i -e LOG_HOST=$publicipspawnreceiver -e LOG_PORT=$ReceiverPortK -p $HoneypotPortK:$HoneypotPortK $HoneypotImageK 
    #launches nginx (optional)
    #docker run -d --name www-$i -p $AppPortK:$AppPortK nginx
    true $(( i++ ))
done


#Updates etcd with new totals (DM VMs and Honeypots)
#Register the tasks for this run in Consul
curl -X PUT -d $Container_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalhoneypots

#Register the tasks for this run in etcd
curl -L http://127.0.0.1:4001/v2/keys/totalhoneypots -XPUT -d value=$Container_InstancesK

#Adds total VM instances
#a=`expr "$a" + "$num"`
TotalVMInstancesK=`expr "$GCEVM_InstancesK" + "$VM_InstancesK"`
curl -L http://127.0.0.1:4001/v2/keys/totalvms -XPUT -d value=$TotalVMInstancesK
curl -X PUT -d $TotalVMInstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalvms


#Totals provisioned
echo ""
echo "$(tput setaf 6) Total provisioned $(tput sgr 0)"
echo "$(tput setaf 6) AWS VMs = $VM_InstancesK $(tput sgr 0)"
echo "$(tput setaf 6) GCE VMs = $GCEVM_InstancesK $(tput sgr 0)"
echo "$(tput setaf 6) Honeypots = $Container_InstancesK $(tput sgr 0)"

#Outputs results
echo ----
echo "$(tput setaf 6) Docker Machine ( $TotalVMInstancesK De-provisioned) provisioned List (includes $SwarmVMName $publicipSWARMK ): $(tput sgr 0)"
echo ----
echo ----
docker run swarm list token://$SwarmTokenK
echo ----
docker-machine ls
echo ----

#Connects to Swarm Cluster
eval $(docker-machine env --swarm $SwarmVMName)

echo ----
echo "$(tput setaf 6) Docker instances running $(tput sgr 0)"
docker ps
echo ""
echo "$(tput setaf 6) Check etcd-browser RUNNING ON $publicipetcdbrowser:8000 $(tput sgr 0)"
echo ""
echo "eval ``$``(docker-machine env --swarm $SwarmVMName) "
echo ""
