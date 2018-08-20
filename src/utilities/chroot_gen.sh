#!/usr/bin/env bash


###*****                      WARNING                        *****###
###***** If this script fails on first run; DO NOT RERUN IT! *****###

### DESCRIPTION: ###
## (config below)
## This volatile script will perform every necessary step to create a
## decent(?) chroot. 
## 
## The script;
##      1) Creates a virtual drive for the chroot (of a preset size)
##          and mounts it.
##      2) Adds the preset binaries (configure below) 
##          and their dependant libraries to the chroot.
##      3) Creates a pre-configured chroot user, a pre-configured 
##          chroot group and a home folder for the pre-configured user 
##          (configure all below) and then creates an ssh keypair to
##          remotely access the chroot using that created user.
##      4) The program then modifies the sshd_config to automagically
##          move the pre-configured chroot user into the chroot
##      5) Finally the program adds the virtual drive and its mount
##          point to /etc/fstab so that the chroot is ready to go on
##          system boot! \o/
##

### REQUIREMENTS: ###
## 1) Ubuntu server 18.04
## 2) root
##


## Enjoy!


###***** CONFIG *****###


## The binaries you want in the chroot (space separated)
INCLUDED_BINARIES="bash ls"

## A file on the file system (doesn't need to exist) that
## the script will use as a virtaul drive.
CHROOT_DRIVE=/var/chroot_drive

## Where the script will mount the virtual drive for the chroot
CHROOT_MOUNT=/var/chroot_mount

## The user account that will get tossed into the chroot when
## someone sucessfully ssh' into that account
CHROOT_USER=phone

## The max size of the chroot
CHROOT_MAX_DISK_SIZE=500M

## Create the user account that gets thrown into the chroot
## as a system account (more apprpriate for automated systems)
CREATE_SYSTEM_USER=true

## If a user belongs to this group, they will be thrown into
## the chroot when they log in.
CHROOT_GROUP=chroot

## The algorithm used to generate the SSH keypair
SSH_KEY_ALGO=rsa

## The SSH keypair bits
SSH_KEY_BITS=4096


###***** END CONFIG *****###


###*** PLEASE DON'T MODIFY ***###

CHROOT_HOME=$CHROOT_MOUNT/home
CHROOT_USER_HOME=$CHROOT_HOME/$CHROOT_USER

###***                     ***###


### Program ###
if [ $UID -ne 0 ] ; then
    echo "MUST BE ROOT!"
    exit 0
fi

echo "Creating chroot self contained drive"
touch $CHROOT_DRIVE
truncate -s $CHROOT_MAX_DISK_SIZE $CHROOT_DRIVE 
mkfs.ext4 $CHROOT_DRIVE

echo "Mounting chroot drive"
mkdir $CHROOT_MOUNT
mount $CHROOT_DRIVE $CHROOT_MOUNT

echo "Adding binaries and libraries"
for bin in $INCLUDED_BINARIES; do
    bin=$(which $bin)
    
    echo -e "\tAdding $bin"

    if [ ! -d "$CHROOT_MOUNT$(dirname $bin)" ]; then
        mkdir -p $CHROOT_MOUNT$(dirname $bin)
    fi

    cp $(which $bin) $CHROOT_MOUNT$(which $bin)

    for lib in $(ldd $bin | grep "=>" | awk '{print $3}') ; do
        echo -e "\tAdding $lib"

        if [ ! -d "$CHROOT_MOUNT$(dirname $lib)" ]; then
            mkdir -p $CHROOT_MOUNT$(dirname $lib)
        fi

        cp $lib $CHROOT_MOUNT$(dirname $lib)/
    done
done

## Ubuntu stuff
mkdir -p $CHROOT_MOUNT/lib64
cp "/lib64/ld-linux-x86-64.so.2" $CHROOT_MOUNT/lib64/

echo "Making chroot home folder"
mkdir -p $CHROOT_USER_HOME/.ssh

echo "Adding chroot group"
groupadd $CHROOT_GROUP

if [ $CREATE_SYSTEM_USER == "true" ]; then
    echo "Adding $CHROOT_USER system user account"
    useradd --system -s /bin/bash -b /home -M -G $CHROOT_GROUP $CHROOT_USER
else
    echo "Adding $CHROOT_USER user account"
    useradd -s /bin/bash -b /home -M -G $CHROOT_GROUP $CHROOT_USER
fi

echo "Creating $CHROOT_USER ssh keypair. You will be able to find them in $HOME after the script has run"
ssh-keygen -t $SSH_KEY_ALGO -b $SSH_KEY_BITS -C "$CHROOT_USER-Key" -f $HOME/$CHROOT_USER.key
cp $HOME/$CHROOT_USER.key.pub $CHROOT_USER_HOME/.ssh/authorized_keys

echo "Setting ownership on $CHROOT_USER_HOME"
chown -R $CHROOT_USER:$CHROOT_USER $CHROOT_USER_HOME

echo "Setting permissions on $CHROOT_USER_HOME"
chmod 700 $CHROOT_USER_HOME/.ssh
chmod 600 $CHROOT_USER_HOME/.ssh/authorized_keys

echo "Configuring SSHD"
echo "
## Custom CHROOT
Match Group $CHROOT_GROUP
    AuthorizedKeysFile $CHROOT_HOME/%u/.ssh/authorized_keys
    AllowTCPForwarding no
    AllowAgentForwarding no
    ChrootDirectory $CHROOT_MOUNT
" >> /etc/ssh/sshd_config 

echo "Configuring fstab"
echo -e "
$CHROOT_DRIVE\t$CHROOT_MOUN\text4\tdefaults\t0 2
" >> /etc/fstab

echo "Restarting SSHD"
systemctl restart sshd
echo "DONE! Give it a go!"
echo "Username: $CHROOT_USER, Key: $HOME/$CHROOT_USER.key"
echo "ssh -i $HOME/$CHROOT_USER.key $CHROOT_USER@localhost"

exit 0

