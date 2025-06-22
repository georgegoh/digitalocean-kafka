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
variable "region" {
  description = "The region to deploy all DigitalOcean resources"
  type = string
  default = "sgp1"
}
variable "vpc_ip_range" {
  description = "The internal ip subnet range for the VPC"
  type = string
  default = "10.10.10.0/24"
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

resource "ansible_group" "kafka_connect" {
  name     = "kafka_connect"
  children = ["utility"]
  variables = {
    kafka_connect_confluent_hub_plugins = "confluentinc/kafka-connect-datagen:0.4.0"
  }
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
  region = var.region
  ip_range = var.vpc_ip_range
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
    port_range = "7770-7774"
    source_addresses = [var.development_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "8081-8083"
    source_addresses = [var.development_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "8088"
    source_addresses = [var.development_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "8090"
    source_addresses = [var.development_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "9092"
    source_addresses = [var.development_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "9021"
    source_addresses = [var.development_host]
  }
}

resource "digitalocean_firewall" "generated_fw_kerberos_clients" {
  name = "terraform-firewall-kerberos-clients"
  tags = ["ansible_kerberos"]

  inbound_rule {
    protocol = "tcp"
    port_range = "88"
    source_tags = ["kerberos_client"]
  }

  inbound_rule {
    protocol = "udp"
    port_range = "88"
    source_tags = ["kerberos_client"]
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

# Create the inbound access firewall rule that allows traffic to/from the Kerberos server.
resource "digitalocean_firewall" "generated_fw_kerberos_servers" {
  name = "terraform-firewall-kerberos-servers"
  tags = ["ansible_kerberos"]

  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_tags = ["kerberos_server"]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = [var.ansible_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "88"
    source_addresses = [var.ansible_host]
  }

  inbound_rule {
    protocol = "udp"
    port_range = "88"
    source_addresses = [var.ansible_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "749"
    source_addresses = [var.ansible_host]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "4444"
    source_addresses = [var.ansible_host]
  }
}

# Create the inbound access firewall rule that allows the bootstrap loadbalancer to reach the brokers.
resource "digitalocean_firewall" "generated_fw_bootstrap" {
  name = "terraform-firewall-bootstrap"
  tags = ["broker"]

  inbound_rule {
    protocol = "tcp"
    port_range = "9092"
    source_addresses = [var.ansible_host]
    source_load_balancer_uids = [digitalocean_loadbalancer.bootstrap_lb.id]
  }
}

# Create a kerberos server
resource "digitalocean_droplet" "kerberos_server" {
  image = "rockylinux-9-x64"
  name = "krb5-server"
  size = "s-4vcpu-8gb"
  region = var.region
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kerberos", "kerberos_client", "kerberos_server"]
}

# Create 3 zookeeper servers
resource "digitalocean_droplet" "zookeeper" {
  count = 3
  image = "rockylinux-9-x64"
  name = "zookeeper-${count.index}"
  size = "s-4vcpu-8gb"
  region = var.region
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka", "kerberos_client", "zookeeper"]
}

# Create 3 brokers
resource "digitalocean_droplet" "broker" {
  count = 3
  image = "rockylinux-9-x64"
  name = "broker-${count.index}"
  size = "s-4vcpu-8gb"
  region = var.region
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka", "kerberos_client", "broker"]
}

# Create a bootstrap loadbalancer
resource "digitalocean_loadbalancer" "bootstrap_lb" {
  name   = "loadbalancer-bootstrap"
  size = "lb-small"
  size_unit = 1
  type = "REGIONAL"
  network = "EXTERNAL"
  region = var.region
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  droplet_tag = "broker"
  
  forwarding_rule {
    entry_port     = 9092
    entry_protocol = "tcp"

    target_port     = 9092
    target_protocol = "tcp"
  }

  healthcheck {
    port     = 9092
    protocol = "tcp"
  }

}

# Create a combined schema_registry/ksql/kafka_connect
resource "digitalocean_droplet" "utility" {
  image = "rockylinux-9-x64"
  name = "utility"
  size = "s-4vcpu-8gb"
  region = var.region
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka", "kerberos_client"]
}

# Create a control_center
resource "digitalocean_droplet" "control_center" {
  image = "rockylinux-9-x64"
  name = "control-center"
  size = "s-4vcpu-8gb"
  region = var.region
  vpc_uuid = digitalocean_vpc.generated_vpc.id
  ssh_keys = [digitalocean_ssh_key.generated_key.fingerprint]
  tags = ["ansible_kafka", "kerberos_client"]
}

resource "local_file" "hosts_yaml" {
  content = templatefile("inventory.tmpl",
    {
      kdc_ip_addr = digitalocean_droplet.kerberos_server.ipv4_address
      zk_ip_addrs = digitalocean_droplet.zookeeper[*].ipv4_address
      broker_ip_addrs = digitalocean_droplet.broker[*].ipv4_address
      utility_ip_addr = digitalocean_droplet.utility.ipv4_address
      controlcenter_ip_addr = digitalocean_droplet.control_center.ipv4_address
    }
  )
  filename = "hosts.yml"
}

resource "local_file" "cfk_controlcenter_yaml" {
  content = templatefile("k8s/cfk-controlcenter.tmpl",
    {
      bootstrap_lb_ip_addr = digitalocean_loadbalancer.bootstrap_lb.ip
      utility_ip_addr = digitalocean_droplet.utility.ipv4_address
    }
  )
  filename = "k8s/cfk-controlcenter.yaml"
}

output "private_key" {
  value = tls_private_key.ansible.private_key_pem
  sensitive = true
}
