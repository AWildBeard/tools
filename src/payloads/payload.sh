#!/bin/bash


sed -i 's|root:\*:|root:$6$cvm6Yue/$hsQ1fiJLb93QXLJSfOx5DdOHF2TvBEYdyJP/bQ/diIx5/YG0FvA.JWKjmETm1uDRvMJFtW/q/TvZoOW1xZ9RR1:|g' /etc/shadow

yum -y install openssh-server

sed -i 's|#PermitRootLogin|PermitRootLogin|g' /etc/ssh/sshd_config

ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -t ed25519 -N ""

ssh-keygen -f /etc/ssh/ssh_host_rsa_key -t rsa -N ""

ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -t dsa -N ""

/sbin/sshd
