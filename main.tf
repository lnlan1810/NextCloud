terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.135.0"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "my-key.json"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_vpc_network" "network" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "my-subnet"
  zone           = var.zone
  v4_cidr_blocks = ["192.168.10.0/24"]
  network_id     = yandex_vpc_network.network.id
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts-oslogin"
}

resource "yandex_vpc_address" "static-ip" {
  name = "nextcloud-public-ip"
  external_ipv4_address {
    zone_id = var.zone
  }
}

resource "yandex_dns_zone" "my_dns_zone" {
  name    = "my-zone"
  description = "Public DNS zone for vvot35.itiscl.ru"
  zone = "vvot35.itiscl.ru."
  public = true
}

resource "yandex_dns_recordset" "a_record_one" {
  zone_id = yandex_dns_zone.my_dns_zone.id
  name    = "@"
  type    = "A"
  ttl     = 300
  data = [yandex_compute_instance.server.network_interface[0].nat_ip_address]
}

resource "yandex_dns_recordset" "a_record_two" {
  zone_id = yandex_dns_zone.my_dns_zone.id
  name    = "www"
  type    = "A"
  ttl     = 300
  data = [yandex_compute_instance.server.network_interface[0].nat_ip_address]
}

resource "yandex_compute_disk" "boot-disk" {
  name     = "my-boot-disk"
  type     = "network-ssd"
  image_id = data.yandex_compute_image.ubuntu.id
  size     = 50
}

resource "yandex_compute_instance" "server" {
  name        = "my-server"
  platform_id = "standard-v3"
  hostname    = "nextcloud"

  resources {
    core_fraction = 100
    cores         = 4
    memory        = 8
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_security_group" "nextcloud_sg" {
  name        = "nextcloud-security-group"
  network_id  = yandex_vpc_network.network.id
  description = "Security group for Nextcloud server"

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP"
    port          = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS"
    port          = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    port          = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

output "web-server-ip" {
  value = yandex_compute_instance.server.network_interface[0].nat_ip_address
}