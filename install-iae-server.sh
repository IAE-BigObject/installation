#!/bin/bash

entry_dir=`pwd`
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
#echo $script_dir

# Check docker
if [ -x "$(command -v docker)" ];
then
    currentver="$(docker version --format '{{.Server.Version}}')"
    echo "docker is already installed. version: $currentver"
    requiredver="20.10.8"
    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" != "$requiredver" ]; then
            echo "Required docker version is ${requiredver}, your version is $currentver."
            echo "Please upgrade your docker."
            exit
    fi
else
    echo "Please install docker first"
    exit 1
fi

# Check docker-compose
if [ -x "$(command -v docker-compose)" ];
then
    currentver="$(docker-compose version --short)"
    echo "docker-compose is already installed. version: $currentver"
    requiredver="1.29.2"
    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" != "$requiredver" ]; then
            echo "Required docker-compose version is ${requiredver}, your version is $currentver."
            echo "Please upgrade your docker-comopse."
            exit
    fi
else
    echo "Please install docker-compose first"
    exit 1
fi

# Read working directory
read -p "Enter the directory to install IAE Server (absolute path, e.g., /home/user1/IAE-server): " working_dir
read -p "Enter ip address for docker swarm (usually ip address of IAE server): " ip_address
read -p "Enter http port number of IAE server (8081 is prefered): " iae_port
read -p "Enter password to access system database: " pw_postgres
printf "Make sure that the above information is correct!!!\n"

printf "IAE server will be installed. Do you want to continue? [y/N] "
read -r yn </dev/tty

if [ "$yn" != "y" ]; then
   echo "Exit"
   exit 1
fi

printf "About to remove legacy IAE containers if any.\n"
printf "Press 'y' to continue and 'N' to stop installation. [y/N] "
read -r yn </dev/tty

if [ "$yn" == "y" ]; then
  printf "About to remove containers...\n"
  #docker ps -aq | xargs docker stop | xargs docker rm
  #docker stop $(docker ps --filter status=running -q)
  #docker rm $(docker ps --filter status=exited -q)
  docker container stop $(docker container ls -q --filter name=server-db)
  docker container stop $(docker container ls -q --filter name=IAE-server)
  docker container stop $(docker container ls -q --filter name=test-svt)
  docker container stop $(docker container ls -q --filter name=bowatch)
  docker container stop $(docker container ls -q --filter name=nagios-api)
  docker rm $(docker ps --filter status=exited -q)
  docker network prune
elif [ "$yn" == "N" ]; then
   echo "Exit"
   exit 2
fi

#printf "current user : "
#echo `whoami`

# Prepare Directory
cmd_response=$(mkdir -p $working_dir)
printf "working folder : "
echo $working_dir
echo $cmd_response
if [ -x "$cmd_response" ]; then
    echo "Cannot access working directory, Please verify your permission on the path"
    exit -2
fi

cd $working_dir
cmd_response=`cd $working_dir`
echo $cmd_response
if [ -x "$cmd_response" ]; then
    echo "Cannot get into working directory, Please verify your permission on the path"
    exit -3
fi

mkdir -p volumes/IAE-server/logs
mkdir -p volumes/postgresql
mkdir -p settings
mkdir -p svt
mkdir -p bowatch
#mkdir -p assets

#cp -r $script_dir/assets .

# Download bowatch
curl -L https://get.bigobject.io/bowatch.tar.gz -o bowatch.tar.gz
tar zxvf bowatch.tar.gz
rm bowatch.tar.gz

# Prepare settings/settings.yml
cp $script_dir/sample_settings.yml ./settings/settings.yml

# Prepare docker-compose.yml
cp $script_dir/sample_docker-compose-IAE-server.yml ./docker-compose-IAE-server.yml

matching="s/%_IP_ADDR_%/"
matching+=$ip_address
matching+="/g"
#echo $matching
sed -i -e $matching ./settings/settings.yml
sed -i -e $matching ./docker-compose-IAE-server.yml

matching="s/%_PW_POSTGRES_%/"
matching+=$pw_postgres
matching+="/g"
#echo $matching
sed -i -e $matching ./settings/settings.yml
sed -i -e $matching ./docker-compose-IAE-server.yml

matching="s/%_PORT_HTTP_%/"
matching+=$iae_port
matching+="/g"
#echo $matching
sed -i -e $matching ./docker-compose-IAE-server.yml


# docker-compose up
docker-compose -f docker-compose-IAE-server.yml pull
docker-compose -f docker-compose-IAE-server.yml up -d

cd $entry_dir

