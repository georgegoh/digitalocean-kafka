
all: init build config

init:
	echo "initialize terraform env"
	tofu init
	echo "install the required dependencies to get cp-ansible to work"
	ansible-galaxy install -r requirements.yml

build:
	MY_IPADDR=`curl ifconfig.me`; tofu plan -var="ansible_host=$$MY_IPADDR" -var="development_host=$$MY_IPADDR" -out=./confluent_platform.plan
	tofu apply ./confluent_platform.plan
	mkdir ./ansible_ssh
	tofu output -raw private_key > ./ansible_ssh/private_key
	chmod 0400 ./ansible_ssh/private_key

kerberos:
	ansible-playbook playbooks/kerberos.yml

confluent:
	ansible-playbook confluent.platform.all

config: kerberos confluent

destroy:
	tofu destroy -var="ansible_host=''" -var="development_host=''"

clean: destroy
	rm -rf hosts.yml terraform.tfstate .terraform.lock.hcl .terraform ansible_ssh confluent_platform.plan keytabs

