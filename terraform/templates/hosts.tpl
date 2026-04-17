127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

# pve nodes
%{ for key, node in nodes ~}
${node.ip} ${node.hostname}.pve ${node.hostname}
%{ endfor ~}
