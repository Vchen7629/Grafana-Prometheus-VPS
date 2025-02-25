set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\u001b[31m'
NC='\033[0m'

echo -e "${YELLOW}Provisoning Digital Ocean Droplet with Terraform...${NC}"
cd "../vps-creation"
terraform init
terraform apply -auto-approve

SERVER_IP=$(terraform output -raw grafana_ipv4)
echo -e "${GREEN}Server provisioned with IP: ${SERVER_IP}${NC}"

echo -e "${YELLOW}Creating hosts.yml file...${NC}"
mkdir -p "../vps-configuration/inventory"
cd "../vps-configuration/inventory"

cat > rootuser.yml << EOF
---
grafana_root:
  hosts:
    ${SERVER_IP}:
      ansible_user: root
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

EOF

cat > newuser.yml << EOF
---
grafana-new-user:
  hosts:
    ${SERVER_IP}:
      ansible_user: vchen7629
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      
EOF

echo -e "${GREEN}hosts.yml created successfully${NC}"

echo -e "${YELLOW}Updating Ansible environment file with new IP...${NC}"
cd ../../vps-configuration


echo -e "${YELLOW}Copying ssh key to wsl...${NC}"
ansible-playbook -i hosts.yml wsl-setup.yml

echo -e "${YELLOW} Waiting for server to become available...${NC}"
for i in {1..10}; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 root@${SERVER_IP} 'exit' 2>/dev/null; then
        echo -e "${GREEN} Server is available!${NC}"
        break;
    else
        echo -e "${YELLOW}Attempt $i: Server not yet available, waiting...${NC}"
        sleep 30
    fi

    if [ $i -eq 10 ]; then 
        echo -e "${RED}Server didn't become available after 5 minutes. Proceeding anyway...${NC}"
    fi
done

echo -e "${YELLOW}Creating a new non root user../${NC}"
ansible-playbook -i inventory/rootuser.yml new-user.yml

echo -e "${YELLOW}Installing Docker on VPS...${NC}"
ansible-playbook -i inventory/newuser.yml software.yml --extra-vars "ansible_become_password={{ New_User_Password }}" --extra-vars "@../vps-configuration/.env.yml"

echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}Server running on IP: ${SERVER_IP}${NC}"
