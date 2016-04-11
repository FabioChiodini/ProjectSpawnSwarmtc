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
prevawsvms=`(curl http://127.0.0.1:4001/v2/keys/awsvms | jq '.node.value' | sed 's/.//;s/.$//')`
prevgcevms=`(curl http://127.0.0.1:4001/v2/keys/gcevms | jq '.node.value' | sed 's/.//;s/.$//')`
prevhoneypots=`(curl http://127.0.0.1:4001/v2/keys/totalhoneypots | jq '.node.value' | sed 's/.//;s/.$//')`

#swarm-master
publicipSWARMK=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/ip | jq '.node.value' | sed 's/.//;s/.$//')`
SwarmTokenK=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/token | jq '.node.value' | sed 's/.//;s/.$//')`

#SPAWN_CONSUL
ConsulVMNameK=`(curl http://127.0.0.1:4001/v2/keys/SPAWN-CONSUL/name | jq '.node.value' | sed 's/.//;s/.$//')`
publicipCONSULK=`(curl http://127.0.0.1:4001/v2/keys/SPAWN-CONSUL/ip | jq '.node.value' | sed 's/.//;s/.$//')`
ConsulPortK=`(curl http://127.0.0.1:4001/v2/keys/SPAWN-CONSUL/port | jq '.node.value' | sed 's/.//;s/.$//')`

#spawn-receiver
ReceiverNameK=`(curl http://127.0.0.1:4001/v2/keys/spawn-receiver/name | jq '.node.value' | sed 's/.//;s/.$//')`
publicipspawnreceiver=`(curl http://127.0.0.1:4001/v2/keys/spawn-receiver/ip | jq '.node.value' | sed 's/.//;s/.$//')`
ReceiverPortK=`(curl http://127.0.0.1:4001/v2/keys/spawn-receiver/port | jq '.node.value' | sed 's/.//;s/.$//')`


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
Container_InstancesK=$prevhoneypots-$3

echo ""

echo ""
echo "$(tput setaf 2) Scaling down $AWSDestroyK Instances in AWS $(tput sgr 0)"
if [ $GCEKProvision -eq 1 ]; then
  echo "$(tput setaf 2) Scaling down $GCEDestroyK Instances in GCE $(tput sgr 0)"
fi
echo "$(tput setaf 2) Scaling down $3 Container Instances $(tput sgr 0)"



#Destroys all existing honeypots

echo ""
echo "$(tput setaf 2) Destroying Honeypots instances via Docker Swarm $(tput sgr 0)"
echo ""

#Connects to Swarm
eval $(docker-machine env --swarm swarm-master)

#Sets variables for launching honeypots that will connect to the receiver
LOG_HOST=$publicipspawnreceiver
LOG_PORT=$ReceiverPortK

i=0
while [ $q -lt $prevhoneypots ]
do
    echo "output: $i"
    UUIDK=$(cat /proc/sys/kernel/random/uuid)
    echo Destroying Container $i
    
    #Launches Honeypots
    #docker run -d --name honeypot-$i -p $HoneypotPortK:$HoneypotPortK $HoneypotImageK
    docker rm -f honeypot-$i 
    #destroys nginx (optional)
    #docker rm -f www-$i 
    #Increments counter for honeypots
    true $(( i++ ))
    
done
#Writes total Honeypots destroyed
ContainersDestroyK=$i

#Writes the final total setup in etcd for further scaling
curl -L http://127.0.0.1:4001/v2/keys/totalhoneypots -XPUT -d value=0


#Destroys N-x GCE VMs


curl -L -X DELETE http://127.0.0.1:2379/v2/keys/message


#Destroys N-y AWS DM

#Respawns honeypots

#Updates etcd with new totals (DM VMs and Honeypots)


#Outputs results
