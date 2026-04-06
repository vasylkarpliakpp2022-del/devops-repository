terraform {
  backend "s3" {
    # Використовуємо endpoints для нових версій Terraform і додаємо https://
    endpoints = {
      s3 = "https://fra1.digitaloceanspaces.com"
    }
    
    region = "us-east-1" # Для DO Spaces це завжди us-east-1
    key    = "terraform.tfstate"
    bucket = "karpliak-tfstate-bucket" # Назва бакета, який ти створив вручну

    # Ці параметри критично важливі для роботи з DigitalOcean:
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true # Виправляє помилку "Retrieving AWS account details"
    skip_s3_checksum            = true
    skip_region_validation      = true
  }

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token             = var.do_token
  spaces_access_id  = var.spaces_access_key
  spaces_secret_key = var.spaces_secret_key
}

# 1. VPC
resource "digitalocean_vpc" "exam_vpc" {
  name     = "karpliak-vpc"
  region   = "fra1"
  ip_range = "10.10.10.0/24"
}

# 2. Firewall
resource "digitalocean_firewall" "exam_fw" {
  name = "karpliak-firewall"
  droplet_ids = [digitalocean_droplet.exam_node.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8000-8003"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# 3. Droplet (ВМ)
resource "digitalocean_droplet" "exam_node" {
  image    = "ubuntu-24-04-x64"
  name     = "karpliak-node"
  region   = "fra1"
  size     = "s-2vcpu-4gb"
  vpc_uuid = digitalocean_vpc.exam_vpc.id
  # Тут вказується SSH ключ, який ти додав у панель DO
  ssh_keys = [data.digitalocean_ssh_key.my_key.id]
}

data "digitalocean_ssh_key" "my_key" {
  name = "karpliak_key" # Назва ключа, як він підписаний у DigitalOcean
}

# 4. Бакет
resource "digitalocean_spaces_bucket" "exam_bucket" {
  name   = "karpliak-bucket"
  region = "fra1"
}