terraform {
    required_providers {
      google ={
        source = "hashicorp/google"
      }
    }
}

terraform {
  backend "gcs" {
    bucket      = "terraform-bucket-a"
    prefix      = "folder1"
  }
}

provider "google" {
  project     = var.project
  region      = var.region
  zone        = "us-central1-a"

}



module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 3.0"

  project_id   = var.project
  network_name = "my-network"
  routing_mode = "GLOBAL"

  subnets = [

    {
      subnet_name           = "subnet-01"
      subnet_ip             = "10.138.20.0/24"
      subnet_region         = "us-west1"
      subnet_private_access = "true"
      subnet_flow_logs      = "true"
      description           = "us-west1 subnet"
    },
    {
      subnet_name               = "subnet-02"
      subnet_ip                 = "10.128.30.0/24"
      subnet_region             = "us-central1"
      subnet_flow_logs          = "true"
      subnet_flow_logs_interval = "INTERVAL_10_MIN"
      subnet_flow_logs_sampling = 0.7
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
    }
  ]

  secondary_ranges = {
    subnet-02 = [
      {
        range_name    = "subnet-02-secondary-01"
        ip_cidr_range = "192.168.64.0/24"
      },
    ]

    subnet-02 = []
  }

  routes = [
    {
      name              = "egress-internet"
      description       = "route through IGW to access internet"
      destination_range = "0.0.0.0/0"
      tags              = "egress-inet"
      next_hop_internet = "true"
    },

  ]
}
resource "google_compute_firewall" "firewall" {
  name    = "allow-ssh-icmp-rdp-http"
  network = module.vpc.network_name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000", "22", "3386"]
  }
  source_tags   = ["web"]
  source_ranges = ["0.0.0.0/0"]


}
resource "google_compute_address" "ip-add" {
  name = "external-ip"

}

resource "google_compute_instance" "my-vm" {
  name                    = "terrform-vm"
  machine_type            = "f1-micro"
  tags                    = ["web","http-server"]
  zone                    = "us-central1-a"
  metadata_startup_script = "echo hi > /test.txt"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface { 
    network = module.vpc.network_name 
    subnetwork = module.vpc.subnets_self_links[0]

    access_config {
      nat_ip = google_compute_address.ip-add.address
    }
  }

  
  
  

}
output "ip" {

  value = google_compute_address.ip-add.address

}