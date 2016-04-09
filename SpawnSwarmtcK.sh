
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
  docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION SPAWN-CONSUL

  #Opens Firewall Port for Consul
  aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port 8500 --cidr 0.0.0.0/0

  #Connects to remote VM

  docker-machine env SPAWN-CONSUL > /home/ec2-user/CONSUL1
  . /home/ec2-user/CONSUL1

  publicipCONSULK=$(docker-machine ip SPAWN-CONSUL)

  #Launches a remote Consul instance

  docker run -d -p 8400:8400 -p 8500:8500 -p 8600:53/udp -h node1 progrium/consul -server -bootstrap

else 
  echo ""
  echo "$(tput setaf 2) Creating a LOCAL CONSUL Container (DynDNS usage)  $(tput sgr 0)"
  echo ""
  
  #Launches a local Consul instance
  docker run -d --name ConsulDynDNS -p 8400:8400 -p 8500:8500 -p 8600:53/udp -h node1 progrium/consul -server -bootstrap

  #Manually open port 8500 on launcher AWS VM

  publicipCONSULK=$DynDNSK

fi



echo ----
echo Consul RUNNING ON $publicipCONSULK:8500
echo publicipCONSULK=$publicipCONSULK
echo ----


echo ""
echo "$(tput setaf 2) Creating a LOCAL etcd instance  $(tput sgr 0)"
echo ""

docker run -d -v /usr/share/ca-certificates/:/etc/ssl/certs -p 4001:4001 -p 2380:2380 -p 2379:2379 --name etcdk quay.io/coreos/etcd -name etcd0 -advertise-client-urls http://${HostIP}:2379,http://${HostIP}:4001 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 -initial-advertise-peer-urls http://${HostIP}:2380 -listen-peer-urls http://0.0.0.0:2380 -initial-cluster-token etcd-cluster-1 -initial-cluster etcd0=http://${HostIP}:2380 -initial-cluster-state new

if [ $etcdbrowserprovision -eq 1 ]; then
  echo ""
  echo "$(tput setaf 2) Creating a etcd-browser instance in GCE $(tput sgr 0)"
  echo ""

  #Create Docker Receiver Instance in GCE
  #gcloud auth login
  gcloud auth activate-service-account $K2_GOOGLE_AUTH_EMAIL --key-file $GOOGLE_APPLICATION_CREDENTIALS --project $K2_GOOGLE_PROJECT

  docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-type g1-small etcd-browserk

  #
  #Open port for etcd-browser on GCE
  gcloud compute firewall-rules create etcd-browserk --allow tcp:8000 --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT

  #gcloud compute firewall-rules list docker-machine

  #Connects to remote VM

  docker-machine env etcd-browserk > /home/ec2-user/etcd-browserk
  . /home/ec2-user/etcd-browserk

  publicipetcdbrowser=$(docker-machine ip etcd-browserk)
  
  #launches etcd-browser containerized
  docker run -d --name etcd-browserk -p 0.0.0.0:8000:8000 --env ETCD_HOST=$DynDNSK kiodo/etcd-browser:latest
  
  #Register etcd-browser in etcd
  curl -L http://127.0.0.1:4001/v2/keys/etcd-browser/name -XPUT -d value=etcd-browserk
  curl -L http://127.0.0.1:4001/v2/keys/etcd-browser/ip -XPUT -d value=$publicipetcdbrowser
  curl -L http://127.0.0.1:4001/v2/keys/etcd-browser/port -XPUT -d value=8000
  echo ----
  echo "$(tput setaf 2) etcd-browser RUNNING ON $publicipetcdbrowser:8000 $(tput sgr 0)"
  echo "$(tput setaf 2) publicipetcdbrowser=$publicipetcdbrowser $(tput sgr 0)"
  echo ----
 fi
 
 
#Provisions Receiver instance in GCE or AWS
if [ $GCEKProvision -eq 1 ]; then

  echo ""
  echo "$(tput setaf 2) Launching a Receiver Instance in GCE $(tput sgr 0)"
  echo ""


  #Create Docker Receiver Instance in GCE
  #gcloud auth login
  gcloud auth activate-service-account $K2_GOOGLE_AUTH_EMAIL --key-file $GOOGLE_APPLICATION_CREDENTIALS --project $K2_GOOGLE_PROJECT

  docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-type g1-small spawn-receiver

  #
  #Open port for Receiver on GCE
  gcloud compute firewall-rules create receiver-machines --allow tcp:$ReceiverPortK --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT

  #gcloud compute firewall-rules list docker-machine

  #Connects to remote VM

  docker-machine env spawn-receiver > /home/ec2-user/spawn-receiver
  . /home/ec2-user/spawn-receiver

  publicipspawnreceiver=$(docker-machine ip spawn-receiver)
  
  docker run -d --name receiverK -p $ReceiverPortK:$ReceiverPortK $ReceiverImageK

  echo ----
  echo "$(tput setaf 2) Receiver RUNNING ON $publicipspawnreceiver  Port $ReceiverPortK ON GCE $(tput sgr 0)"
  echo publicipspawnreceiver=$publicipspawnreceiver
  echo ----

else
	
  echo ""
  echo "$(tput setaf 2) Launching a Receiver Instance in AWS $(tput sgr 0)"
  echo ""


  #Create Docker Receiver Instance in AWS
  docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION spawn-receiver

  echo "$(tput setaf 2) Opening Ports for Receiver on AWS $(tput sgr 0)"
  #Opens Firewall Port for Receiver on AWS
  aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port $ReceiverPortK --cidr 0.0.0.0/0

  #Connects to remote VM

  docker-machine env spawn-receiver > /home/ec2-user/spawn-receiver
  . /home/ec2-user/spawn-receiver

  publicipspawnreceiver=$(docker-machine ip spawn-receiver)
  
    #starts the Receiver dockerized
  docker run -d --name receiverK -p $ReceiverPortK:$ReceiverPortK $ReceiverImageK

  echo ----
  echo "$(tput setaf 2) Receiver RUNNING ON $publicipspawnreceiver  Port $ReceiverPortK ON AWS $(tput sgr 0)"
  echo publicipspawnreceiver=$publicipspawnreceiver
  echo ----

fi


echo ""
echo "$(tput setaf 2) Registering Services in Consul and etcd  $(tput sgr 0)"
echo ""

#registers receiver in Consul
  curl -X PUT -d 'spawn-receiver' http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/name
  curl -X PUT -d $publicipspawnreceiver http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/ip
  curl -X PUT -d $ReceiverPortK http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/port

#Register Receiver in etcd
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/name -XPUT -d value=spawn-receiver
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/ip -XPUT -d value=$publicipspawnreceiver
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/port -XPUT -d value=$ReceiverPortK
  

#Register the tasks for this run in Consul
#Postponed as Consul takes some time to start up
curl -X PUT -d $VM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/awsvms
curl -X PUT -d $GCEVM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/gcevms
curl -X PUT -d $Container_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalhoneypots

#Register the tasks for this run in etcd
curl -L http://127.0.0.1:4001/v2/keys/awsvms -XPUT -d value=$VM_InstancesK
curl -L http://127.0.0.1:4001/v2/keys/gcevms -XPUT -d value=$GCEVM_InstancesK
curl -L http://127.0.0.1:4001/v2/keys/totalhoneypots -XPUT -d value=$Container_InstancesK



#Jonas Style Launch Swarm

echo ""
echo "$(tput setaf 2) Creating Docker Swarm VM $(tput sgr 0)"
echo ""
#Creates swarm ID and stores it into file and variable
docker run swarm create > /home/ec2-user/kiodo1
tail -1 /home/ec2-user/kiodo1 > /home/ec2-user/SwarmToken

SwarmTokenK=$(cat /home/ec2-user/SwarmToken)

echo ----
echo "$(tput setaf 1) Check swarm token on https://discovery.hub.docker.com/v1/clusters/$SwarmTokenK $(tput sgr 0)"
echo ----

#Create Swarm Master
docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION --swarm --swarm-master --swarm-discovery token://$SwarmTokenK swarm-master

echo ""
echo "$(tput setaf 2) Opening Ports for Docker Swarm$(tput sgr 0)"
echo ""
#Opens Firewall Port for Docker SWARM
aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port 8333 --cidr 0.0.0.0/0

#Connects to remote VM
docker-machine env swarm-master > /home/ec2-user/SWARM1
. /home/ec2-user/SWARM1

publicipSWARMK=$(docker-machine ip swarm-master)

#registers Swarm master in Consul
curl -X PUT -d 'swarm-master' http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/name
curl -X PUT -d $publicipSWARMK http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/ip
curl -X PUT -d '8333' http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/port
curl -X PUT -d $SwarmTokenK http://$publicipCONSULK:8500/v1/kv/tc/swarm-master/token

#Register swarm-master in etcd
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/ip -XPUT -d value=$publicipSWARMK
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/port -XPUT -d value=8333
curl -L http://127.0.0.1:4001/v2/keys/swarm-master/token -XPUT -d value=$SwarmTokenK

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
   echo ""
   echo Provisioning VM SPAWN-GCE$j-K
   echo ""
  
   #docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-image ubuntu-1510-wily-v20151114 --swarm --swarm-discovery token://$SwarmTokenK SPAWN-GCE$j-K
   docker-machine create -d google --google-project $K2_GOOGLE_PROJECT --google-machine-type g1-small --swarm --swarm-discovery token://$SwarmTokenK env-crate-$j
   #Stores ip of the VM
   docker-machine env env-crate-$j > /home/ec2-user/Docker$j
   . /home/ec2-user/Docker$j
  
   publicipKGCE=$(docker-machine ip env-crate-$j)
   
   #registers Swarm Slave in Consul
   curl -X PUT -d env-crate-$j http://$publicipCONSULK:8500/v1/kv/tc/env-crate-$j/name
   curl -X PUT -d $publicipKGCE http://$publicipCONSULK:8500/v1/kv/tc/env-crate-$j/ip
   
   #Register Swarm slave in etcd
   curl -L http://127.0.0.1:4001/v2/keys/DM-GCE-$j/name -XPUT -d value=env-crate-$j
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
    echo ""
    echo "$(tput setaf 1) Provisioning VM SPAWN$i-$UUIDK $(tput sgr 0)"
    echo ""
    docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION --swarm --swarm-discovery token://$SwarmTokenK SPAWN$i-$UUIDK

    #Stores ip of the VM
    docker-machine env SPAWN$i-$UUIDK > /home/ec2-user/Docker$i
    . /home/ec2-user/Docker$i

    publicipK=$(docker-machine ip SPAWN$i-$UUIDK)
    
    #registers Swarm Slave in Consul
    curl -X PUT -d SPAWN$i-$UUIDK http://$publicipCONSULK:8500/v1/kv/tc/SPAWN$i-$UUIDK/name
    curl -X PUT -d $publicipK http://$publicipCONSULK:8500/v1/kv/tc/SPAWN$i-$UUIDK/ip
    
    #Register Swarm slave in etcd
    curl -L http://127.0.0.1:4001/v2/keys/DM-AWS-$i/name -XPUT -d value=SPAWN$i-$UUIDK
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
eval $(docker-machine env --swarm swarm-master)


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




#Outputs final status
eval $(docker-machine env --swarm swarm-master) > /home/ec2-user/OutputKK

echo ----
echo "$(tput setaf 1) SWARM  RUNNING ON $publicipSWARMK $(tput sgr 0)"
echo "$(tput setaf 1) Consul RUNNING ON $publicipCONSULK:8500 $(tput sgr 0)"
echo ""
echo "$(tput setaf 1) Run $(tput sgr 0)"
echo "$(</home/ec2-user/OutputKK )"
echo "TO connect to the cluster "
echo THEN run 
echo "docker info" 
echo TO check swarm status
echo ----
echo RUN 
echo "docker ps"
echo TO check which containers are running
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
echo "$(tput setaf 6) Docker Machine provisioned List: $(tput sgr 0)"
echo TBD
echo ----
docker run swarm list token://$SwarmTokenK
echo ----
docker-machine ls
echo ----
if [ $etcdbrowserprovision -eq 1 ]; then
  echo "$(tput setaf 6) etcd-browser RUNNING ON $publicipetcdbrowser:8000 $(tput sgr 0)"
fi
echo "******************************************"


#Optionally close all non useful ports
#Still TBI

echo ""
echo "$(tput setaf 2) Preparing for Clean UP $(tput sgr 0)"
echo ""

#KILLS SWARM (Testing purposes cleanup)
docker-machine rm swarm-master
docker-machine rm SPAWN-CONSUL
docker-machine rm spawn-receiver


#curl http://127.0.0.1:4001/v2/keys/DM-AWS-0/name | jq '.node.value' | sed 's/.//;s/.$//' > DELMEK
#Extract a variable from etcd
DELMEK=`(curl http://127.0.0.1:4001/v2/keys/DM-AWS-0/name | jq '.node.value' | sed 's/.//;s/.$//')`
echo $DELMEK
docker-machine rm $DELMEK
echo "$(tput setaf 2) About to tear down local dockers CAUTION!!! $(tput sgr 0)"
docker-machine rm SPAWN-FigureITOUT


docker rm -f ConsulDynDNS
sleep 1
docker rm -f receiverK
sleep 1
docker rm -f etcdk

#Displays Public IP


