terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3.0"
    }
  }
}

resource "ansible_group" "kafka_connect" {
  name     = "kafka_connect"
  children = ["utility"]
  variables = {
    kafka_connect_confluent_hub_plugins = "confluentinc/kafka-connect-datagen:0.4.0"
  }
}

# Set the variable values in main.auto.tfvars file
# or using -var="do_token=..." CLI option
variable "do_token" {
  description = "Digital Ocean Personal Access Token"
  type = string
  sensitive = true
}
variable "ansible_host" {
  description = "The public IP address of the Ansible host (this host)"
  type = string
}
variable "development_host" {
  description = "The public IP address of the development host that will access Control Center, etc."
  type = string
}


# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Create new SSH key
resource "tls_private_key" "ansible" {
  algorithm = "RSA"
  rsa_bits = 4096
}
# Push the new SSH key into DigitalOcean
resource "digitalocean_ssh_key" "generated_key" {
  name = "Terraform-generated Ansible Key"
  public_key = tls_private_key.ansible.public_key_openssh
}

# Create the VPC
resource "digitalocean_vpc" "generated_vpc" {
  name = "terraform-vpc-kafka"
  region = "sgp1"
  description = "An auto-generated VPC to isolate Kafka instances."
}

# Create the firewall that allows Kafka nodes to talk to each other
resource "digitalocean_firewall" "generated_fw" {
  name = "terraform-firewall-kafka"
  tags = ["ansible_kafka"]

  inbound_rule {
    protocol = "tcp"
    port_range = "1-65535"
    source_tags = ["ansible_kafka"]
  }

  outbound_rule {
    protocol = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol = "tcp"
    port_range = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol = "udp"
    port_range = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Create the inbound access firewall rule that allows the Ansible host to reach the target nodes
resource "digitalocean_firewall" "generated_fw_ansible" {
  name = "terraform-firewall-ansible"
  tags = ["ansible_kafka"]

  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = [var.ansible_host]
  }
}

# Create the inbound access firewall rule that allows the dev host to reach the target nodes
resource "digitalocean_firewall" "generated_fw_dev" {
  name = "terraform-firewall-kafka-dev"
  tags = ["ansible_kafka"]

  inbound_rule {
    protocol = "tcp"
    port_range = "8082"
    source_addresses = [var.development_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "8090"
    source_addresses = [var.development_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "9021"
    source_addresses = [var.development_host]
  }
}

# Create 3 zookeeper servers
resource "digitalocean_droplet" "zookeeper_1" {
  image = "rockylinux-9-x64"
  name = "zookeeper"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

resource "digitalocean_droplet" "zookeeper_2" {
  image = "rockylinux-9-x64"
  name = "zookeeper"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

resource "digitalocean_droplet" "zookeeper_3" {
  image = "rockylinux-9-x64"
  name = "zookeeper"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

# Create 3 brokers
resource "digitalocean_droplet" "broker_1" {
  image = "rockylinux-9-x64"
  name = "broker-1"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

resource "digitalocean_droplet" "broker_2" {
  image = "rockylinux-9-x64"
  name = "broker-2"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

resource "digitalocean_droplet" "broker_3" {
  image = "rockylinux-9-x64"
  name = "broker-3"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

# Create a combined schema_registry/ksql/kafka_connect
resource "digitalocean_droplet" "utility" {
  image = "rockylinux-9-x64"
  name = "utility"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

# Create a control_center
resource "digitalocean_droplet" "control_center" {
  image = "rockylinux-9-x64"
  name = "control-center"
  region = "sgp1"
  size = "s-4vcpu-8gb"
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka"]
}

resource "local_file" "hosts_yaml" {
  content = templatefile("inventory.tmpl",
    {
      zk_ip_addrs = [digitalocean_droplet.zookeeper_1.ipv4_address, digitalocean_droplet.zookeeper_2.ipv4_address, digitalocean_droplet.zookeeper_3.ipv4_address]
      broker_ip_addrs = [digitalocean_droplet.broker_1.ipv4_address, digitalocean_droplet.broker_2.ipv4_address, digitalocean_droplet.broker_3.ipv4_address]
      utility_ip_addr = digitalocean_droplet.utility.ipv4_address
      controlcenter_ip_addr = digitalocean_droplet.control_center.ipv4_address
    }
  )
  filename = "hosts.yml"
}

output "private_key" {
  value = tls_private_key.ansible.private_key_pem
  sensitive = true
}
