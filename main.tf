
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"

    }
  }

}
terraform {
  backend "gcs" {
    bucket = "terraform-bucket-b"
    prefix = "folder1"
  }
}

resource "google_project" "my-first-project" {
  name            = var.project_name
  project_id      = var.project_name
  billing_account = data.google_billing_account.acct.id

}
data "google_billing_account" "acct" {
  display_name = "My Billing Account"
  open         = true
}


resource "google_project_service" "service" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
    "cloudbilling.googleapis.com"
  ])
  service            = each.key
  project            = google_project.my-first-project.project_id
  disable_on_destroy = false

}

resource "google_service_account" "name" {
  display_name = var.service_account_name
  account_id   = var.service_account_name
  project      = google_project.my-first-project.project_id

}
resource "google_service_account_iam_member" "role-binding" {
  service_account_id = google_service_account.name.name
  for_each = toset([
    "roles/resourcemanager.projectCreator",
    "roles/editor",
    "roles/billing.user"
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.name.email}"

}
resource "google_storage_bucket" "bucket" {
  name                        = "${google_project.my-first-project.project_id}-tf-bucket"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  project                     = google_project.my-first-project.project_id


}
resource "google_storage_bucket_iam_binding" "sa-binding" {

  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.name.email}"
  ]

}
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 3.0"

  project_id   = google_project.my-first-project.project_id
  network_name = var.vpc_network
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
  routes = [
    {
      name              = "egress-to-internet"
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
    ports    = ["80", "8080", "22", "3386"]
  }
  source_tags   = ["web"]
  source_ranges = ["0.0.0.0/0"]


}
resource "google_compute_address" "ip-add" {
  name = "external-ip"

}

resource "google_compute_instance" "my-vm" {
  name                    = var.vm_name
  machine_type            = "f1-micro"
  tags                    = ["web"]
  zone                    = var.my_zone
  metadata_startup_script = file("startup.sh")
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network    = module.vpc.network_name
    subnetwork = module.vpc.subnets_self_links[0]

    access_config {
      nat_ip = google_compute_address.ip-add.address
    }
  }

  lifecycle {
    create_before_destroy = true

  }



}
output "ip" {

  value = google_compute_address.ip-add.address

}




