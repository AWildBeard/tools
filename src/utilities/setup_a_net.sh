#!/usr/bin/env bash

function usage {
    echo "
SUMMARY:
    This script makes no changes that can't be solved by
    a reboot.

    This script is used to turn an ethernet device into a
    router-like device that **does not** run DHCP for the
    network specified. A general usecase for the author was
    plugging a Raspberry Pi directly into the ethernet port 
    of their device to masquerade (NAT) the WAN connection 
    from a different network device to the Pi.

    This script makes a few assumptions. The main one being
    that you control iptables through SystemD, so that when
    you decide to de-activate the masquerading that this
    script has set up, it can just flush iptables and
    reflash the rules into iptables with 
    `systemctl restart iptables`.

USAGE:
    -h
        Display this help message and exit

    -s
        Start | Stop the forwarding. This flag is used to
        either start masquerading for a network device, or
        to stop masquerading for a network device. If the
        flag is being used to stop masquerading, all flags
        are ignored.

    -w [DEVICE]
        This flag selects which device connections should
        routed out of the machine to the WAN through.
        Arguments can take any valid network interface 
        form such as but not limited to:

            * wlan0
            * wlx1d4c2f013e7b
            * enp58s0f1
            * eth0

        etc.

    -l [DEVICE]
        This flag selects which device clients will connect
        to. This should be a ethernet device because this
        script will not setup a WAP for wireless devices.
        Arguments might take the form of:

            * enp58s0f1
            * eth0
            * etx1D4c2f013e7b

        etc.

    -n [NETWORK]
        This flag selects the network address and range
        for the ethernet device that will host the 'LAN'
        Arguments should take the form of:
 
            * 172.22.12.1/24
            * 10.0.0.80/8

        etc.

EXAMPLES:
    $0 -s -w wlp58s0f1 -l enp58s0f1 -n 172.22.12.1/24
        This will configure a masquerade for enp58s0f1
        that routes its traffice out wlp58s0f1.
        enp58s0f1 has the address 172.22.12.1 on a
        /24 network

    $0 -s
        This will deconfigure the masquerade and remove
        changes. Remeber that this script makes no
        chanes that can't be reverted by a reboot.

AUTHOR:
    Michael Mitchell
"
}

if [[ $UID -ne 0 ]]; then
    echo "Must be root to run this ;D"
    exit 1
fi

while getopts :hsw:l:n: opt; do
    case $opt in
        h) ## Found help flag
            usage
            exit 0
            ;;
        s) ## Really this is only here to make usability improve
            ;;
        w) ## Found the output_dev flag
            output_dev=$OPTARG
            ;;
        l) ## Found the lan_dev arg
            input_dev=$OPTARG
            ;;
        n) ## Found the network arg
            ip=$OPTARG
            ;;
        :) ## Found a flag that should have an argument but doesnt
            echo "Flag -$OPTARG requires an argument!"
            echo "See $0 -h for help!"
            exit 1
            ;;
        \?) ## Found garbage
            usage
            exit 1
            ;;
    esac
done

if [[ -f /tmp/forwarding.lock ]]; then # Deconfiguring the masquerade is assumed
    source /tmp/forwarding.lock

    echo "Disabling ip packet forwarding in the kernel"
    echo 0 >>/proc/sys/net/ipv4/ip_forward

    echo "Bringing $input_dev down"
    ip link set $input_dev down

    echo "Removing $ip from $input_dev"
    ip a del $ip dev $input_dev

    echo "Leaving $input_dev down for NetworkManager"

    echo "Flushing iptables"
    iptables -F
    iptables -t nat -F

    echo "Restoring iptables from SystemD"
    systemctl restart iptables

    echo "Registering $input_dev with NetworkManager again"
    nmcli device set $input_dev managed true

    rm /tmp/forwarding.lock
    exit 0
fi

if [[ -z ${output_dev} ]]; then
    echo "Missing argument: -w"
    exit 1
fi

if [[ -z ${input_dev} ]]; then
    echo "Missing argument: -l"
    exit 1
fi

if [[ -z ${ip} ]]; then
    echo "Missing argument -n"
    exit 1
fi

echo "Enabling ip_packet forwarding in the kernel"
echo 1 >>/proc/sys/net/ipv4/ip_forward

echo "De-registering $input_dev from NetworkManager"
nmcli device set $input_dev managed false

echo "Setting up NAT and ip packet forwarding"
iptables -t nat -A POSTROUTING -o $output_dev -j MASQUERADE
iptables -A FORWARD -i $input_dev -j ACCEPT

echo "Bringin $input_dev down"
ip link set $input_dev down

echo "Adding $ip to $input_dev"
ip a add $ip dev $input_dev

echo "Bringin $input_dev back up"
ip link set $input_dev up

echo -e "ip=\"$ip\"\ninput_dev=\"$input_dev\"" >/tmp/forwarding.lock
