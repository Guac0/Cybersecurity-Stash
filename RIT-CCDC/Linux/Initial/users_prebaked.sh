#!/bin/bash
# go through all users:
# lock and change pwd and kill tasks of unauthorized ones
# leave black team accounts alone
# change password and de-privilege authorized accounts
# add our main blue user and a backdoor

# Redirect all output to both terminal and log file
exec > >(tee -a users_prebaked_log.txt) 2>&1

# Check if exactly three arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <system> <man> <auth>"
    exit 1
fi

# OPTIONS
backdoor_username1="systemd-bash"
backdoor_password1=$1
backdoor_username2="man-db"
backdoor_password2=$2
donottouch_users=("systemd-bash" "man-db" "dd-agent" "datadog" "dd-dog" "blackteam" "black-team" "black_team" "whiteteam" "white-team" "white_team" "saloonSally")
authorized_users=("banditAlex" "marshalJustice" "prairiePioneer" "outlawOutlook" "calamityJane" "sheriffMcCoy" "docHolliday" "pokerPete" "gamblerSteve" "wildBill" "ponyExpress" "annieOakley" "DeputyDigital" "WranglerWeb" "CattleRustler")
donottouch_and_authorized_users=("${donottouch_users[@]}" "${authorized_users[@]}")
authorized_users_password=$3

if [ "$EUID" -ne 0 ]
  then echo "Must run as superuser"
  exit
fi

# Check if /bin/redd exists and create it if it doesn't exist
if [ ! -f "/bin/redd" ]; then
    apt install curl -y
    dnf install curl -y
    yum install curl -y
    curl https://raw.githubusercontent.com/Guac0/Cybersecurity-Stash/main/RIT-CCDC/Linux/Initial/gouda.sh > gouda.sh
    bash gouda.sh
fi

# Get all users on the system
all_users=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)



# Create blue team user and backup

# Create the backdoor user
useradd -m $backdoor_username1
useradd -m $backdoor_username2

# Set the password for the backdoor user
echo "$backdoor_username1:$backdoor_password1" | chpasswd
echo "$backdoor_username2:$backdoor_password2" | chpasswd

# Add the backdoor user to the group
usermod -aG sudo $backdoor_username1
usermod -aG sudo $backdoor_username2

# Secure the backdoor user's account by only allowing root/self to access their home directories
chown root:root /home/$backdoor_username1
chmod 700 /home/$backdoor_username1
chown root:root /home/$backdoor_username1/.bashrc
chmod 644 /home/$backdoor_username1/.bashrc
chown root:root /home/$backdoor_username2
chmod 700 /home/$backdoor_username2
chown root:root /home/$backdoor_username2/.bashrc
chmod 644 /home/$backdoor_username2/.bashrc



# Loop through each user and if theyre unauthorized then kill them
for user in $all_users; do
    # if current user is not in the whitelist, then lock them
    if [[ ! " ${donottouch_and_authorized_users[@]} " =~ " ${user} " ]]; then

        chage --maxdays 15 --mindays 6 --warndays 7 --inactive 5 $user;
        crontab -u $user -l > /var/spool/cron/"$user"_crontab_backup_$(date +"%Y%m%d_%H%M%S").bak
        crontab -u $user -r
        usermod --expiredate 1 $user # Set the expiration date to yesterday 
        chsh -s /bin/redd $user

        if grep -q "^$user" /etc/sudoers; then
            # Remove the user from the sudo group
            deluser $user sudo
            echo "Root access removed for user $user"
        fi

        # Lock the user account by disabling pwd login
        passwd -l $user

        # Change the user's password to a random one
        random_password=$(date +%s | sha256sum | base64 | head -c 16)
        echo "$user:$random_password" | chpasswd

        # Kill all processes owned by the user
        pkill -u $user

        # Kill all user's SSH sessions
        #pkill -u $user sshd

        # Close all user's terminal sessions
        #pkill -u $user bash

        echo "Locked $user"
    fi

    # If user is an authorized user, change their password
    if [[ " ${authorized_users[@]} " =~ " ${user} " ]]; then
        # Generate a random password
        random_password=$authorized_users_password
        
        # Change the user's password
        echo "$user:$random_password" | chpasswd

        if grep -q "^$user" /etc/sudoers; then
            # Remove the user from the sudo group
            deluser $user sudo
            echo "Root access removed for user $user"
        fi

        # Kill all processes owned by the user
        pkill -u $user

        chsh -s /bin/redd $user

        # Get all active SSH sessions for the user
        #active_sessions=$(who | grep $user | grep -v "10.15.1" | awk '{print $2}')
        # Get the list of SSH sessions originating from the specified network range
        #active_sessions=$(netstat -tnpa | grep "ESTABLISHED.*sshd" | grep "@$network_range:" | awk '{print $7}' | cut -d '/' -f 1)

        # Get the list of processes owned by the user
        #user_processes=$(ps -u $user -o pid=)

        # Kill active sessions not originating from the specified network range
        #for pid in $user_processes; do
        #    if [[ ! " ${active_sessions[@]} " =~ " ${pid} " ]]; then
        #        sudo kill -9 $pid
        #        echo "Killed process with PID $pid"
        #    fi
        #done

        # Close all user's terminal sessions
        #pkill -u $user bash

        crontab -u $user -l > /var/spool/cron/"$user"_crontab_backup_$(date +"%Y%m%d_%H%M%S").bak
        crontab -u $user -r

        # Output the change
        echo "Changed password and secured $user"
    fi
done

# secure our jump in user
user=saloonSally

random_password=$authorized_users_password
        
# Change the user's password
echo "$user:$random_password" | chpasswd

if grep -q "^$user" /etc/sudoers; then
    # Remove the user from the sudo group
    deluser $user sudo
    echo "Root access removed for user $user"
fi

crontab -u $user -l > /var/spool/cron/"$user"_crontab_backup_$(date +"%Y%m%d_%H%M%S").bak
crontab -u $user -r
chsh -s /bin/redd $user

# dont kill all processes owned by root because that's gonna fuck something up
passwd -l root
# pkill -u root
# crontab -u $user -l > /var/spool/cron/"$user"_crontab_backup_$(date +"%Y%m%d_%H%M%S").bak
# crontab -u $user -r

echo "Done, killing all of executing user's tasks..."

# Kill all processes owned by the user
pkill -u $user

# Output the change
echo "Done (but you won't ever see this lmao)"