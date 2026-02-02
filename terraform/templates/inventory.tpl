all:
  children:
%{ for env in distinct([for n in nodes : n.env]) ~}
    ${env}:
      children:
%{ for stack in distinct([for n in nodes : n.stack if n.env == env]) ~}
        ${stack}:
          hosts:
%{ for name, cfg in nodes ~}
%{ if cfg.env == env && cfg.stack == stack ~}
            ${name}:
              ansible_host: ${split("/", cfg.ip)[0]}
              ansible_user: root
              ansible_password: ${passwords[name].result}
%{ endif ~}
%{ endfor ~}
%{ endfor ~}
%{ endfor ~}
