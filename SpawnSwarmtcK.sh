
#Load Env variables from File (maybe change to DB)
#using /home/ec2-user/Cloud1
#source /home/ec2-user/Cloud1
. /home/ec2-user/Cloud1
echo ""
echo "Loaded Config file"
echo ""
echo "$(tput setaf 2) Starting $VM_InstancesK Instances in AWS $(tput sgr 0)"
if [ $GCEKProvision -eq 1 ]; then
  echo "$(tput setaf 2) Starting $GCEVM_InstancesK Instances in GCE $(tput sgr 0)"
fi
echo "$(tput setaf 2) Starting $Container_InstancesK Container Instances $(tput sgr 0)"

echo ""
echo "$(tput setaf 2) Installing jq $(tput sgr 0)"
echo ""
wget http://stedolan.github.io/jq/download/linux64/jq

chmod +x ./jq

sudo cp -p jq /usr/bin

echo ""
echo "STARTING"
echo ""


echo ""
echo "$(tput setaf 2) Setting env variables for AWS CLI $(tput sgr 0)"
rm -rf ~/.aws/config
mkdir ~/.aws

touch ~/.aws/config

echo "[default]" > ~/.aws/config
echo "AWS_ACCESS_KEY_ID=$K1_AWS_ACCESS_KEY" >> ~/.aws/config
echo "AWS_SECRET_ACCESS_KEY=$K1_AWS_SECRET_KEY" >> ~/.aws/config
echo "AWS_DEFAULT_REGION=$K1_AWS_DEFAULT_REGION" >> ~/.aws/config

echo ""

#provision Consul via Docker machine or locally 
#depending on DynDDNS Usage variable ConsulDynDNSK
if [ $ConsulDynDNSK -eq 0 ]; then
  echo ""
  echo "$(tput setaf 2) Creating CONSUL VM via Docker Machine $(tput sgr 0)"
  echo ""
  #Create Docker Consul VM 
  docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION $instidk-SPAWN-CONSUL

  #Opens Firewall Port for Consul
  aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port 8500 --cidr 0.0.0.0/0

  #Connects to remote VM

  docker-machine env $instidk-SPAWN-CONSUL > /home/ec2-user/CONSUL1
  . /home/ec2-user/CONSUL1

  publicipCONSULK=$(docker-machine ip $instidk-SPAWN-CONSUL)

  #Launches a remote Consul instance

  docker run -d -p 8400:8400 -p 8500:8500 -p 8600:53/udp -h node1 progrium/consul -server -bootstrap

else 
  echo ""
  echo "$(tput setaf 2) Creating a LOCAL CONSUL Container (DynDNS usage)  $(tput sgr 0)"
  echo ""
  
  #Launches a local Consul instance
  docker run -d --name ConsulDynDNS -p 8400:8400 -p 8500:8500 -p 8600:53/udp -h node1 progrium/consul -server -bootstrap

  #Stores local ip in a variable
  publicipCONSULK=$DynDNSK
  
fi



echo ----
echo "$(tput setaf 6) Consul RUNNING ON $publicipCONSULK:8500 $(tput sgr 0)"
echo publicipCONSULK=$publicipCONSULK
echo ----


echo ""
echo "$(tput setaf 2) Creating a LOCAL etcd instance  $(tput sgr 0)"
echo ""

ipAWSK=`(curl http://169.254.169.254/latest/meta-data/public-ipv4)`
#docker run -d -v /usr/share/ca-certificates/:/etc/ssl/certs -p 4001:4001 -p 2380:2380 -p 2379:2379 --name etcdk quay.io/coreos/etcd -name etcd0 -advertise-client-urls http://${ipAWSK}:2379,http://${ipAWSK}:4001 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 -initial-advertise-peer-urls http://${ipAWSK}:2380 -listen-peer-urls http://0.0.0.0:2380 -initial-cluster-token etcd-cluster-1 -initial-cluster etcd0=http://${ipAWSK}:2380 -initial-cluster-state new

docker run -d -v /usr/share/ca-certificates/:/etc/ssl/certs -p 4001:4001 -p 2380:2380 -p 2379:2379 \
    --name etcdk quay.io/coreos/etcd:v3.1.0-rc.1 \
    /usr/local/bin/etcd \
    --name etcd0 \
    --advertise-client-urls http://${ipAWSK}:2379,http://${ipAWSK}:4001 \
    --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
    --initial-advertise-peer-urls http://${ipAWSK}:2380 \
    --listen-peer-urls http://0.0.0.0:2380 \
    --initial-cluster-token etcd-cluster-1 \
    --initial-cluster etcd0=http://${ipAWSK}:2380 -initial-cluster-state new

if [ $etcdbrowserprovision -eq 1 ]; then
  #echo ""
  #echo "$(tput setaf 2) Creating a etcd-browser instance in GCE $(tput sgr 0)"
  #echo ""
  #Create Docker etcdbrowser Instance in GCE
  #gcloud auth login
  #gcloud auth activate-service-account $K2_GOOGLE_AUTH_EMAIL --key-file $GOOGLE_APPLICATION_CREDENTIALS --project $K2_GOOGLE_PROJECT
  #
  #Open port for etcd-browser on GCE
  #gcloud compute firewall-rules create etcd-browserk --allow tcp:8000 --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT
  #creates name
  #etcdbrowserkVMName=etcd-browserk$instidk
  #docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-type g1-small $etcdbrowserkVMName

  echo ""
  echo "$(tput setaf 2) Creating a etcd-browser instance in AWS $(tput sgr 0)"
  echo ""
  #creates name
  etcdbrowserkVMName=etcd-browserk$instidk
  #Create Docker Receiver Instance in AWS
  docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION $etcdbrowserkVMName

  echo "$(tput setaf 2) Opening Ports for etcd-browser on AWS $(tput sgr 0)"
  #Opens Firewall Port for Receiver on AWS
  aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port 8000 --cidr 0.0.0.0/0

  #Connects to remote VM

  docker-machine env $etcdbrowserkVMName > /home/ec2-user/$etcdbrowserkVMName
  . /home/ec2-user/$etcdbrowserkVMName

  publicipetcdbrowser=$(docker-machine ip etcd-browserk$instidk)
  
  #launches etcd-browser containerized
  docker run -d --name etcd-browserk -p 0.0.0.0:8000:8000 --env ETCD_HOST=$DynDNSK kiodo/etcd-browser:latest
  
  #Register etcd-browser in etcd
  curl -L http://127.0.0.1:4001/v2/keys/etcd-browser/name -XPUT -d value=$etcdbrowserkVMName
  curl -L http://127.0.0.1:4001/v2/keys/etcd-browser/ip -XPUT -d value=$publicipetcdbrowser
  curl -L http://127.0.0.1:4001/v2/keys/etcd-browser/port -XPUT -d value=8000
  curl -L http://127.0.0.1:4001/v2/keys/etcd-browser/address -XPUT -d value=$publicipetcdbrowser:8000
  
  #Register etcd-browser in Consul
  curl -X PUT -d $etcdbrowserkVMName http://$publicipCONSULK:8500/v1/kv/tc/etcd-browser/name
  curl -X PUT -d $publicipetcdbrowser http://$publicipCONSULK:8500/v1/kv/tc/etcd-browser/ip
  curl -X PUT -d 8000 http://$publicipCONSULK:8500/v1/kv/tc/etcd-browser/port
  curl -X PUT -d $publicipetcdbrowser:8000 http://$publicipCONSULK:8500/v1/kv/tc/etcd-browser/address
  
  echo ----
  echo "$(tput setaf 6) $etcdbrowserkVMName RUNNING ON $publicipetcdbrowser:8000 $(tput sgr 0)"
  echo "$(tput setaf 4) publicipetcdbrowser=$publicipetcdbrowser $(tput sgr 0)"
  echo ----
fi
 
#Register Consul in etcd
if [ $ConsulDynDNSK -eq 0 ]; then
  curl -L http://127.0.0.1:4001/v2/keys/consul/name -XPUT -d value=$instidk-SPAWN-CONSUL
else
  curl -L http://127.0.0.1:4001/v2/keys/consul/name -XPUT -d value=$DynDNSK
fi
curl -L http://127.0.0.1:4001/v2/keys/consul/ip -XPUT -d value=$publicipCONSULK
curl -L http://127.0.0.1:4001/v2/keys/consul/port -XPUT -d value=8500

#register local ip and dns name in etcd
myipK=$( dig +short $DynDNSK @8.8.8.8)
curl -L http://127.0.0.1:4001/v2/keys/maininstance/ip -XPUT -d value=$myipK
fqnK=$(nslookup $myipK)
fqnK=${fqnK##*name = }
fqnK=${fqnK%.*}
#echo $fqn
curl -L http://127.0.0.1:4001/v2/keys/maininstance/name -XPUT -d value=$fqnK
if [ $ConsulDynDNSK -eq 1 ]; then
  curl -L http://127.0.0.1:4001/v2/keys/maininstance/dyndns -XPUT -d value=$DynDNSK
fi

#register instance id in etcd
curl -L http://127.0.0.1:4001/v2/keys/maininstance/uniqueinstanceid -XPUT -d value=$instidk

#register local ip and dns name in Consul
curl -X PUT -d $fqnK http://$publicipCONSULK:8500/v1/kv/tc/maininstance/name
curl -X PUT -d $myipK http://$publicipCONSULK:8500/v1/kv/tc/maininstance/ip
if [ $ConsulDynDNSK -eq 1 ]; then
  curl -X PUT -d $DynDNSK http://$publicipCONSULK:8500/v1/kv/tc/maininstance/dyndns
fi

#register instance id in Consul
curl -X PUT -d $instidk http://$publicipCONSULK:8500/v1/kv/tc/maininstance/uniqueinstanceid


echo ""
echo "  _____  ______ _____ ______ _______      ________ _____  "
echo " |  __ \|  ____/ ____|  ____|_   _\ \    / /  ____|  __ \ "
echo " | |__) | |__ | |    | |__    | |  \ \  / /| |__  | |__) |"
echo " |  _  /|  __|| |    |  __|   | |   \ \/ / |  __| |  _  / "
echo " | | \ \| |___| |____| |____ _| |_   \  /  | |____| | \ \ "
echo " |_|  \_\______\_____|______|_____|   \/   |______|_|  \_\ "
echo ""

#Provisions Receiver instance in GCE or AWS
#provisions External Receiver if ExternalReceiverK =0
if [ $ExternalReceiverK -eq 0 ]; then 
 #Provisions a receiver on GCE or AWS depending on flags
 echo ""
 echo "$(tput setaf 2) Launching a Receiver Instance $(tput sgr 0)"
 echo ""
 if [ $GCEKProvision -eq 1 && $ReceiverKinGCE -eq 1 ] ; then

  echo ""
  echo "$(tput setaf 2) Launching a Receiver Instance in GCE $(tput sgr 0)"
  echo ""
  #creates name
  ReceiverNameK=spawn-receivergce$instidk

  #Create Docker Receiver Instance in GCE
  #gcloud auth login
  gcloud auth activate-service-account $K2_GOOGLE_AUTH_EMAIL --key-file $GOOGLE_APPLICATION_CREDENTIALS --project $K2_GOOGLE_PROJECT

  docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-type g1-small $ReceiverNameK

  #
  #Open port for Receiver on GCE
  gcloud compute firewall-rules create receiver-machines --allow tcp:$ReceiverPortK --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT

  #gcloud compute firewall-rules list docker-machine

  #Connects to remote VM

  docker-machine env $ReceiverNameK > /home/ec2-user/$ReceiverNameK
  . /home/ec2-user/$ReceiverNameK

  publicipspawnreceiver=$(docker-machine ip $ReceiverNameK)
  
  docker run -d --name receiverK -p $ReceiverPortK:$ReceiverPortK $ReceiverImageK

  echo ----
  echo "$(tput setaf 6) Receiver RUNNING ON $publicipspawnreceiver  Port $ReceiverPortK ON GCE $(tput sgr 0)"
  echo publicipspawnreceiver=$publicipspawnreceiver
  echo ----

 else
	
  echo ""
  echo "$(tput setaf 2) Launching a Receiver Instance in AWS $(tput sgr 0)"
  echo ""
  
  #creates name
  ReceiverNameK=spawn-receiverAWS$instidk

  #Create Docker Receiver Instance in AWS
  docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION $ReceiverNameK

  echo "$(tput setaf 2) Opening Ports for Receiver on AWS $(tput sgr 0)"
  #Opens Firewall Port for Receiver on AWS
  aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port $ReceiverPortK --cidr 0.0.0.0/0

  #Connects to remote VM

  docker-machine env $ReceiverNameK > /home/ec2-user/$ReceiverNameK
  . /home/ec2-user/$ReceiverNameK

  publicipspawnreceiver=$(docker-machine ip $ReceiverNameK)
  
    #starts the Receiver dockerized
  docker run -d --name receiverK -p $ReceiverPortK:$ReceiverPortK $ReceiverImageK

  echo ----
  echo "$(tput setaf 2) Receiver RUNNING ON $publicipspawnreceiver  Port $ReceiverPortK ON AWS $(tput sgr 0)"
  echo publicipspawnreceiver=$publicipspawnreceiver
  echo ----

 fi
else
 #using Extenal Receiver
 #Sets parameter for external receiver
 echo ""
 echo "$(tput setaf 2) using an EXTERNAL a Receiver Instance $(tput sgr 0)"
 echo ""
 ReceiverNameK=$ExternalReceiverNameK
 publicipspawnreceiver=$ExternalReceiverIpK
 ReceiverPortK=$ExternalReceiverPortK
 echo ----
 echo "$(tput setaf 2) EXTERNAL Receiver RUNNING ON $publicipspawnreceiver  Port $ReceiverPortK ON AWS $(tput sgr 0)"
 echo publicipspawnreceiver=$publicipspawnreceiver
 echo ----
fi

echo ""
echo "$(tput setaf 2) Registering Services in Consul and etcd  $(tput sgr 0)"
echo ""

#registers receiver in Consul
  curl -X PUT -d $ReceiverNameK http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/name
  curl -X PUT -d $publicipspawnreceiver http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/ip
  curl -X PUT -d $ReceiverPortK http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/port

#Register Receiver in etcd
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/name -XPUT -d value=$ReceiverNameK
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/ip -XPUT -d value=$publicipspawnreceiver
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/port -XPUT -d value=$ReceiverPortK
  

#Register the tasks for this run in Consul
#Postponed as Consul takes some time to start up
curl -X PUT -d $VM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/awsvms
curl -X PUT -d $GCEVM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/gcevms
curl -X PUT -d $Container_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalhoneypots
curl -X PUT -d $HoneypotPortK http://$publicipCONSULK:8500/v1/kv/tc/HoneypotPort


#Register the tasks for this run in etcd
curl -L http://127.0.0.1:4001/v2/keys/awsvms -XPUT -d value=$VM_InstancesK
curl -L http://127.0.0.1:4001/v2/keys/gcevms -XPUT -d value=$GCEVM_InstancesK
curl -L http://127.0.0.1:4001/v2/keys/totalhoneypots -XPUT -d value=$Container_InstancesK
curl -L http://127.0.0.1:4001/v2/keys/HoneypotPort -XPUT -d value=$HoneypotPortK

#Adds total VM instances
#a=`expr "$a" + "$num"`
TotalVMInstancesK=`expr "$GCEVM_InstancesK" + "$VM_InstancesK"`
curl -L http://127.0.0.1:4001/v2/keys/totalvms -XPUT -d value=$TotalVMInstancesK
curl -X PUT -d $TotalVMInstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalvms

#Jonas Style Launch Swarm

#AASCI ART
echo ""
echo "  _______          __     _____  __  __ "
echo " / ____\ \        / /\   |  __ \|  \/  |"
echo "| (___  \ \  /\  / /  \  | |__) | \  / |"
echo " \___ \  \ \/  \/ / /\ \ |  _  /| |\/| |"
echo " ____) |  \  /\  / ____ \| | \ \| |  | |"
echo "|_____/    \/  \/_/    \_\_|  \_\_|  |_|"
echo ""      



echo ""
echo "$(tput setaf 2) Creating Docker Swarm VM$(tput sgr 0)"
echo ""
#Creates swarm ID and stores it into file and variable
docker run swarm create > /home/ec2-user/kiodo1
tail -1 /home/ec2-user/kiodo1 > /home/ec2-user/SwarmToken

SwarmTokenK=$(cat /home/ec2-user/SwarmToken)

echo ----
echo "$(tput setaf 1) Check swarm token on https://discovery.hub.docker.com/v1/clusters/$SwarmTokenK $(tput sgr 0)"
echo ----
#creates name
UUIDSWK=$(cat /proc/sys/kernel/random/uuid)
#echo Provisioning VM SPAWN$i-$UUIDK
SwarmVMName=swarm-master-$UUIDSWK
SwarmVMName+="-"
SwarmVMName+=$instidk

#
#SwarmVMName=swarm-master$instidk
#Create Swarm Master
docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION --swarm --swarm-master --swarm-discovery token://$SwarmTokenK $SwarmVMName

echo ""
echo "$(tput setaf 2) Opening Ports for Docker Swarm$(tput sgr 0)"
echo ""
#Opens Firewall Port for Docker SWARM
aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port 8333 --cidr 0.0.0.0/0

#Connects to remote VM
docker-machine env $SwarmVMName > /home/ec2-user/SWARM1
. /home/ec2-user/SWARM1

publicipSWARMK=$(docker-machine ip $SwarmVMName)

#launches a container to prevent Honeypots to run on swarm-master
docker run -d --name www-8080 -p $HoneypotPortK:$HoneypotPortK nginx


#registers Swarm master in Consul
curl -X PUT -d $SwarmVMName http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/name
curl -X PUT -d $publicipSWARMK http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/ip
curl -X PUT -d '8333' http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/port
curl -X PUT -d $SwarmTokenK http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/token
StringTokenK="https://discovery.hub.docker.com/v1/clusters/$SwarmTokenK"
curl -X PUT -d $StringTokenK http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/address
#Builds connection string
StringEvalK="eval ``$``(docker-machine env ``--``swarm"
StringEvalK+=" $SwarmVMName)"
echo ""
echo "$(tput setaf 2) String Connect $StringEvalK $(tput sgr 0)"
echo ""
curl -X PUT --data-binary "$StringEvalK"  http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/connect

#Register swarm-master in etcd
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/name -XPUT -d value=$SwarmVMName
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/ip -XPUT -d value=$publicipSWARMK
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/port -XPUT -d value=8333
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/token -XPUT -d value=$SwarmTokenK
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/address -XPUT -d value=$StringTokenK
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/connect -XPUT -d value=$StringEvalK

echo ----
echo "$(tput setaf 1) SWARM  RUNNING ON $publicipSWARMK $(tput sgr 0)"
echo publicipSWARMK=$publicipSWARMK
echo Consul RUNNING ON $publicipCONSULK:8500
echo ----

#Loops for creating Swarm nodes

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
  j=0
  while [ $j -lt $GCEVM_InstancesK ]
  do
   UUIDK=$(cat /proc/sys/kernel/random/uuid)
   # Makes sure the UUID is lowercase for GCE provisioning
   UUIDKL=${UUIDK,,}
   #echo ""
   #echo Provisioning VM SPAWN-GCE$j-K
   #echo ""
  
   #docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-image ubuntu-1510-wily-v20151114 --swarm --swarm-discovery token://$SwarmTokenK SPAWN-GCE$j-K
   #a=2
   #a+=4
   VMGCEnameK=env-crate-$j
   #VMGCEnameK+="-"
   VMGCEnameK+=$instidk
   echo ""
   echo Provisioning VM $VMGCEnameK
   echo ""
   docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-type g1-small --swarm --swarm-discovery token://$SwarmTokenK $VMGCEnameK
   #Stores ip of the VM
   docker-machine env $VMGCEnameK > /home/ec2-user/Docker$j
   . /home/ec2-user/Docker$j
  
   publicipKGCE=$(docker-machine ip $VMGCEnameK)
   
   #registers Swarm Slave in Consul
   curl -X PUT -d $VMGCEnameK http://$publicipCONSULK:8500/v1/kv/tc/DM-GCE-$j/name
   curl -X PUT -d $publicipKGCE http://$publicipCONSULK:8500/v1/kv/tc/DM-GCE-$j/ip
   
   #Register Swarm slave in etcd
   curl -L http://127.0.0.1:4001/v2/keys/DM-GCE-$j/name -XPUT -d value=$VMGCEnameK
   curl -L http://127.0.0.1:4001/v2/keys/DM-GCE-$j/ip -XPUT -d value=$publicipKGCE
   
   echo ----
   echo "$(tput setaf 1) Machine $publicipKGCE in GCE connected to SWARM $(tput sgr 0)"
   echo ----
   true $(( j++ ))
  done
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


i=0
while [ $i -lt $VM_InstancesK ]
do
    echo "output: $i"
    UUIDK=$(cat /proc/sys/kernel/random/uuid)
    #echo Provisioning VM SPAWN$i-$UUIDK
    VMAWSnameK=SPAWN$i-$UUIDK
    VMAWSnameK+="-"
    VMAWSnameK+=$instidk
    
    
    echo ""
    echo "$(tput setaf 1) Provisioning VM $VMAWSnameK $(tput sgr 0)"
    echo ""
    docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION --swarm --swarm-discovery token://$SwarmTokenK $VMAWSnameK

    #Stores ip of the VM
    docker-machine env $VMAWSnameK > /home/ec2-user/$VMAWSnameK-Docker$i
    . /home/ec2-user/$VMAWSnameK-Docker$i

    publicipK=$(docker-machine ip $VMAWSnameK)
    
    #registers Swarm Slave in Consul
    curl -X PUT -d $VMAWSnameK http://$publicipCONSULK:8500/v1/kv/tc/DM-AWS-$i/name
    curl -X PUT -d $publicipK http://$publicipCONSULK:8500/v1/kv/tc/DM-AWS-$i/ip
    
    #Register Swarm slave in etcd
    curl -L http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name -XPUT -d value=$VMAWSnameK
    curl -L http://127.0.0.1:4001/v2/keys/DM-AWS-$i/ip -XPUT -d value=$publicipK
    
    
    echo ----
    echo "$(tput setaf 1) Machine $publicipK connected to SWARM $(tput sgr 0)"
    echo ----
    true $(( i++ ))
done


#Launches $instancesK Containers using SWARM

echo ""
echo "$(tput setaf 2) Launching Honeypots instances via Docker Swarm $(tput sgr 0)"
echo ""

#Connects to Swarm
eval $(docker-machine env --swarm $SwarmVMName)


#Sets variables for launching honeypots that will connect to the receiver
LOG_HOST=$publicipspawnreceiver
LOG_PORT=$ReceiverPortK



i=0
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






echo ----
echo "$(tput setaf 1) SWARM  RUNNING ON $publicipSWARMK $(tput sgr 0)"
echo "$(tput setaf 1) Consul RUNNING ON $publicipCONSULK:8500 $(tput sgr 0)"
echo ----
echo "$(tput setaf 1) Check swarm token on https://discovery.hub.docker.com/v1/clusters/$SwarmTokenK $(tput sgr 0)"
echo ----
echo "*****************************************"
echo ----
echo "$(tput setaf 6) Receiver RUNNING ON $publicipspawnreceiver  Port $ReceiverPortK $(tput sgr 0)"
echo ----
echo ----
echo ----
echo "$(tput setaf 6) Honeypots RUNNING ON $(tput sgr 0)"
echo "$(</home/ec2-user/KProvisionedK )"
echo "$publicipSWARMK"
echo "$(tput setaf 6) Port $HoneypotPortK $(tput sgr 0)"
echo ----
echo "$(tput setaf 6) Docker Machine ( $TotalVMInstancesK ) provisioned List (includes $SwarmVMName $publicipSWARMK )  : $(tput sgr 0)"
echo TBD
echo ----
docker run swarm list token://$SwarmTokenK
echo ----
docker-machine ls
echo ----
echo "$(tput setaf 6) Docker instances running $(tput sgr 0)"
docker ps
echo ""
if [ $etcdbrowserprovision -eq 1 ]; then
  echo "$(tput setaf 6) etcd-browser RUNNING ON $publicipetcdbrowser:8000 $(tput sgr 0)"
  echo ""
fi
echo ""
echo "$(tput setaf 6) EMCWorld Demo!!! $(tput sgr 0)"
echo "$(tput setaf 6) Swarm VM Name $(tput sgr 0)"
echo " $SwarmVMName "
echo ""
echo "Swarm Connection String:"
echo "eval ``$``(docker-machine env --swarm $SwarmVMName) "
echo ""
echo "******************************************"


#Optionally close all non useful ports
#Still TBI

# Clean up is now performed by another script
#echo ""
#echo "$(tput setaf 2) Preparing for Clean UP $(tput sgr 0)"
#echo ""

#KILLS SWARM (Testing purposes cleanup)
#docker-machine rm swarm-master
#docker-machine rm SPAWN-CONSUL
#docker-machine rm spawn-receiver


#curl http://127.0.0.1:4001/v2/keys/DM-AWS-0/name | jq '.node.value' | sed 's/.//;s/.$//' > DELMEK
#Extract a variable from etcd
#DELMEK=`(curl http://127.0.0.1:4001/v2/keys/DM-AWS-0/name | jq '.node.value' | sed 's/.//;s/.$//')`
#echo $DELMEK
#docker-machine rm $DELMEK
#echo "$(tput setaf 2) About to tear down local dockers CAUTION!!! $(tput sgr 0)"
#docker-machine rm SPAWN-FigureITOUT


#docker rm -f ConsulDynDNS
#sleep 1
#docker rm -f receiverK
#sleep 1
#docker rm -f etcdk

#Displays Public IP


