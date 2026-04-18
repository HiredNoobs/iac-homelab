127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

# --- BEGIN PVE ---
%{ for key, node in nodes ~}
${split("/", node.ip)[0]} ${node.hostname}.pve ${node.hostname}
%{ endfor ~}
# --- END PVE ---
