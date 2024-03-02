#!/bin/bash
# A simple version of downloads.sh that only installs curl, git, and clones the repo

# check for root for installs and exit if not found
if  [ "$EUID" -ne 0 ];
then
    echo "User is not root. Skill issue."
    exit
fi

# Redirect all output to both terminal and log file
exec > >(tee -a downloads_simple_log.txt) 2>&1

#debian
apt install curl -y
apt install git -y

#rhel
yum install curl -y
yum install git -y

git clone https://github.com/Guac0/Cybersecurity-Stash
cd Cybersecurity-Stash/RIT-CCDC/Linux
find ./ -type f -iname "*.sh" -exec chmod +x {} \;
echo "Scripts have been downloaded to ./Linux"