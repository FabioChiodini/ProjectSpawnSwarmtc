#Spawn Tear down script
#Cleans up the whole envinronment by reading information from etcd
#It also uses /home/ec2-user/Cloud1 parameters

. /home/ec2-user/Cloud1
echo "loaded Config file"
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
#Reads data from etcd
prevawsvms=`(curl http://127.0.0.1:4001/v2/keys/awsvms | jq '.node.value' | sed 's/.//;s/.$//')`
prevgcevms=`(curl http://127.0.0.1:4001/v2/keys/gcevms | jq '.node.value' | sed 's/.//;s/.$//')`
prevhoneypots=`(curl http://127.0.0.1:4001/v2/keys/totalhoneypots | jq '.node.value' | sed 's/.//;s/.$//')`

#swarm-master
publicipSWARMK=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/ip | jq '.node.value' | sed 's/.//;s/.$//')`
SwarmTokenK=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/token | jq '.node.value' | sed 's/.//;s/.$//')`
SwarmVMName=`(curl http://127.0.0.1:4001/v2/keys/swarm-master/name | jq '.node.value' | sed 's/.//;s/.$//')`

#SPAWN_CONSUL
ConsulVMNameK=`(curl http://127.0.0.1:4001/v2/keys/consul/name | jq '.node.value' | sed 's/.//;s/.$//')`

#spawn-receiver
ReceiverNameK=`(curl http://127.0.0.1:4001/v2/keys/spawn-receiver/name | jq '.node.value' | sed 's/.//;s/.$//')`

#etcd
$etcdbrowserkVMName=`(curl http://127.0.0.1:4001/v2/keys/etcd-browser/name | jq '.node.value' | sed 's/.//;s/.$//')`

#Kill Docker Machines
echo ""
echo "$(tput setaf 1)Destroying GCE VMs ( $prevgcevms ) $(tput sgr 0)"
echo ""

j=0
while [ $j -lt $prevgcevms ]
do
   #Reads VM Name from etcd
   VMKill=`(curl http://127.0.0.1:4001/v2/keys/DM-GCE-$i/name | jq '.node.value' | sed 's/.//;s/.$//')`
   echo ""
   echo "Destroying VM $VMKill "
   echo ""
   docker-machine rm -f $VMKill

   echo ----
   echo "$(tput setaf 1) Machine $VMKill Destroyed $(tput sgr 0)"
   echo ----
   #Increments counter for total GCE VMs
   true $(( j++ ))
   done


echo ""
echo "$(tput setaf 1)Destroying AWS VMs ( $prevawsvms ) $(tput sgr 0)"
echo ""

i=0
while [ $i -lt $prevawsvms ]
do
    #Reads VM Name from etcd
    
    VMKill=`(curl http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name | jq '.node.value' | sed 's/.//;s/.$//')`
    #http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name -XPUT
    #echo Provisioning VM SPAWN$i-$UUIDK
    echo ""
    echo "$(tput setaf 1) Destroying VM $VMKill $(tput sgr 0)"
    echo ""
    docker-machine rm -f $VMKill

    echo ----
    echo "$(tput setaf 1) Machine $VMKill destroyed $(tput sgr 0)"
    echo ----
    #Increments counter for total AWS VMs
    true $(( i++ ))
   done

#Kill Infrastructure Containers
echo ""
echo "$(tput setaf 1) Destroying Infrastructure Containers $(tput sgr 0)"
echo ""
docker-machine rm -f $SwarmVMName
docker-machine rm -f $ConsulVMNameK
docker-machine rm -f $ReceiverNameK
docker-machine rm -f $etcdbrowserkVMName

#Kill local containers
echo ""
echo "$(tput setaf 1) Destroying Local Containers $(tput sgr 0)"
echo ""
docker rm -f ConsulDynDNS
sleep 1
docker rm -f receiverK
sleep 1
docker rm -f etcdk

#Clean firewall Rules
# Still TBI

echo "$(tput setaf 6) Docker machine still alive: $(tput sgr 0)"
docker-machine ls

echo "$(tput setaf 6) Local Docker Containers still alive:$(tput sgr 0)"
docker ps

#Connects to Swarm Cluster
eval $(docker-machine env --swarm $SwarmVMName)

echo ----
echo "$(tput setaf 6) Docker instances running $(tput sgr 0)"
docker ps
echo ""


echo ""
echo "$(tput setaf 1) Everything has been destroyed by Malebolgia ;) $(tput sgr 0)"
echo ""
