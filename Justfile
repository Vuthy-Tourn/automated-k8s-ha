ping-all: 
    echo "Ping all instances inside inventory.ini " 
    ansible -i inventory/inventory.ini \
        all -m ping 
        
setup-all:
    ansible-playbook playbooks/main.yml --vault-password-file ./secrets/vault_pass.txt

create-machines:
    ansible-playbook playbooks/main.yml --tags provision
    
destroy-machines:
    ansible-playbook playbooks/tasks/destroy-gcp.yml

prepare-node:
    ansible-playbook playbooks/main.yml --tags prepare

setup-kubespray:
    ansible-playbook playbooks/main.yml --tags kubespray

setup-domain:
    ansible-playbook playbooks/main.yml --tags domains --vault-password-file ./secrets/vault_pass.txt