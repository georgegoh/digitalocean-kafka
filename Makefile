
all: env infra config

env:
	echo "initialize terraform env"
	tofu init
	echo "install the required dependencies to get cp-ansible to work"
	ansible-galaxy install -r requirements.yml
infra:
	tofu plan -out=./confluent_platform.plan
	tofu apply ./confluent_platform.plan
	mkdir ./ansible_ssh
	tofu output -raw private_key > ./ansible_ssh/private_key
	chmod 0400 ./ansible_ssh/private_key
config:
	ansible-playbook --private-key ./ansible_ssh/private_key -i hosts.yml confluent.platform.all

destroy:
	tofu destroy

clean: destroy
	rm -rf hosts.yml terraform.tfstate .terraform.lock.hcl .terraform ansible_ssh confluent_platform.plan

