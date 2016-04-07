
#Load Env variables from File (maybe change to DB)
#using /home/ec2-user/Cloud1
#source /home/ec2-user/Cloud1
. /home/ec2-user/Cloud1
echo "loaded Config file"
echo ""
echo "$(tput setaf 2) Starting $VM_InstancesK Instances in AWS $(tput sgr 0)"
if [ $GCEKProvision -eq 1 ]; then
  echo "$(tput setaf 2) Starting $GCEVM_InstancesK Instances in GCE $(tput sgr 0)"
fi
echo "$(tput setaf 2) Starting $Container_InstancesK Container Instances $(tput sgr 0)"


echo "Installing jq"
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

rm -rf /home/ec2-user/KProvisionedK
rm -rf /home/ec2-user/DMListK


#echo $AWS_ACCESS_KEY_ID

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

docker run -d -v /usr/share/ca-certificates/:/etc/ssl/certs -p 4001:4001 -p 2380:2380 -p 2379:2379 \
 --name etcd quay.io/coreos/etcd \
 -name etcd0 \
 -advertise-client-urls http://${HostIP}:2379,http://${HostIP}:4001 \
 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
 -initial-advertise-peer-urls http://${HostIP}:2380 \
 -listen-peer-urls http://0.0.0.0:2380 \
 -initial-cluster-token etcd-cluster-1 \
 -initial-cluster etcd0=http://${HostIP}:2380 \
 -initial-cluster-state new
 
 
#Provisions Receiver instance in GCE or AWS
if [ $GCEKProvision -eq 1 ]; then

  echo ""
  echo "$(tput setaf 2) Launching a Receiver Instance in GCE $(tput sgr 0)"
  echo ""


  #Create Docker Receiver Instance in GCE
  #gcloud auth login
  gcloud auth activate-service-account $K2_GOOGLE_AUTH_EMAIL --key-file $GOOGLE_APPLICATION_CREDENTIALS --project $K2_GOOGLE_PROJECT

  docker-machine create -d google --google-project $K2_GOOGLE_PROJECT spawn-receiver

  #
  #Open port for Receiver on GCE
  gcloud compute firewall-rules create receiver-machines --allow tcp:$ReceiverPortK --source-ranges 0.0.0.0/0 --target-tags docker-machine --project $K2_GOOGLE_PROJECT

  #gcloud compute firewall-rules list docker-machine

  #Connects to remote VM

  docker-machine env spawn-receiver > /home/ec2-user/spawn-receiver
  . /home/ec2-user/spawn-receiver

  publicipspawnreceiver=$(docker-machine ip spawn-receiver)
  
  #registers receiver in Consul
  curl -X PUT -d 'spawn-receiver' http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/$publicipspawnreceiver/key?flags=1

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
  
  #registers receiver in Consul
  curl -X PUT -d 'spawn-receiver' http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/name
  curl -X PUT -d $publicipspawnreceiver http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/ip
  curl -X PUT -d $ReceiverPortK http://$publicipCONSULK:8500/v1/kv/tc/spawn-receiver/port
  
  
  #starts the Receiver dockerized
  docker run -d --name receiverK -p $ReceiverPortK:$ReceiverPortK $ReceiverImageK

  echo ----
  echo "$(tput setaf 2) Receiver RUNNING ON $publicipspawnreceiver  Port $ReceiverPortK ON AWS $(tput sgr 0)"
  echo publicipspawnreceiver=$publicipspawnreceiver
  echo ----

fi

#Register Receiver in etcd
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/ip -XPUT -d value=$publicipspawnreceiver
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/port -XPUT -d value=$ReceiverPortK
  
#double check registrations writing in a file
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/ip | jq '.node.value' | sed 's/.//;s/.$//' > /home/ec2-user/ipreceiver.txt
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/port | jq '.node.value' | sed 's/.//;s/.$//' > /home/ec2-user/portreceiver.txt
  
echo ""
echoe "etcd Registration"
curl -L http://127.0.0.1:4001/v2/keys/spawn-receiver/ip


#Register the tasks for this run in Consul
#Postponed as Consul takes some time to start up
curl -X PUT -d $VM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/awsvms
curl -X PUT -d $GCEVM_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/gcevms
curl -X PUT -d $Container_InstancesK http://$publicipCONSULK:8500/v1/kv/tc/totalhoneypots




#Jonas Style Launch Swarm

echo ""
echo "$(tput setaf 2) Creating Docker Swarm VM $(tput sgr 0)"

#Creates swarm ID and stores it into file and variable
docker run swarm create > /home/ec2-user/kiodo1
tail -1 /home/ec2-user/kiodo1 > /home/ec2-user/SwarmToken

SwarmTokenK=$(cat /home/ec2-user/SwarmToken)

echo ----
echo "$(tput setaf 1) Check swarm token on https://discovery.hub.docker.com/v1/clusters/$SwarmTokenK $(tput sgr 0)"
echo ----

#Create Swarm Master
docker-machine create --driver amazonec2 --amazonec2-access-key $K1_AWS_ACCESS_KEY --amazonec2-secret-key $K1_AWS_SECRET_KEY --amazonec2-vpc-id  $K1_AWS_VPC_ID --amazonec2-zone $K1_AWS_ZONE --amazonec2-region $K1_AWS_DEFAULT_REGION --swarm --swarm-master --swarm-discovery token://$SwarmTokenK swarm-master

echo "$(tput setaf 2) Opening Ports for Docker Swarm$(tput sgr 0)"

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
   echo $publicipKGCE >> /home/ec2-user/KProvisionedK
   echo env-crate-$j >> /home/ec2-user/DMListK
   
   #registers Swarm Slave in Consul
   curl -X PUT -d env-crate-$j http://$publicipCONSULK:8500/v1/kv/tc/env-crate-$j/name
   curl -X PUT -d $publicipKGCE http://$publicipCONSULK:8500/v1/kv/tc/env-crate-$j/ip
   
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
    echo $publicipK >> /home/ec2-user/KProvisionedK
    echo SPAWN$i-$UUIDK >> /home/ec2-user/DMListK
    
    #registers Swarm Slave in Consul
    curl -X PUT -d SPAWN$i-$UUIDK http://$publicipCONSULK:8500/v1/kv/tc/SPAWN$i-$UUIDK/name
    curl -X PUT -d $publicipK http://$publicipCONSULK:8500/v1/kv/tc/SPAWN$i-$UUIDK/ip
    
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
#echo "$(/home/ec2-user/DMListK)"
echo ----
docker run swarm list token://$SwarmTokenK
echo ----
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
docker-machine rm SPAWN-FigureITOUT


#Displays Public IP


