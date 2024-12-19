# DigitalOcean Kafka Lab Environment Setup

## Introduction

This is a collection of templates that generate working configs to:

1. Create a small Kafka cluster consisting of 3 zk, 3 brokers, and a single 'utility' node that contains several roles (e.g., Control Center, Schema Registry, Proxy REST, etc).
2. Generate a `hosts.yml` file for you that is ready to use with Confluent Platform Ansible playbooks.

## How to use

Default configurations here will work. Just enter your DO token and you should
be ready to go.

1. Find or create your DigitalOcean token at (https://cloud.digitalocean.com/account/api/tokens) and set it up in the TF autovars:

```
echo 'do_token = "<your token here>"' > main.auto.tfvars
```
*Note: You can scope access to the absolute minimum you need to make this work:*
```
droplet (4): create, read, update, delete
firewall (4): create, read, update, delete
ssh_key (4): create, read, update, delete
vpc (4): create, read, update, delete
```

2. Run `make all`

3. When you no longer need the cluster and want to stop getting charged, run
`make clean` to destroy all the resources that were created. You will not be 
able to get any data back after running this, so make sure this is what you
really want to do.

## Details

The Makefile relies on being able to call `curl ifconfig.me` to figure out the
localhost public IP address. Then it sets up DigitalOcean firewall rules to 
*only* allow access to the Kafka nodes via that IP. We don't want them to be
accessible to the world.
