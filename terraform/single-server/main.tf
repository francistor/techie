terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.79.0"
    }
  }
}

provider "google" {
  credentials = file("../../../terraform-key.json")
  project     = "operating-spot-389516"
  region      = "europe-southwest1"
  zone        = "europe-southwest1-a"
}

variable "http_port" {
    description = "web server port"
    type = number
    default = 8081
}

resource "google_compute_network" "vpc_network" {
  name = "book-network"
}

resource "google_compute_instance_template" "mytemplate" {
  name_prefix  = "member"
  machine_type = "e2-micro"
  tags         = ["tag1", "tag2"]
  disk {
    auto_delete = true
    disk_size_gb = 10
    disk_type = "pd-balanced"
    source_image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20230829"
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      // Ephemeral public IP
    }
  }
  
  metadata_startup_script = <<-EOF
    #!/bin/bash

   #!/bin/bash
    echo "Hello, World" > index.xhtml
    nohup busybox httpd -f -p ${var.http_port} &

  EOF
}

resource "google_compute_autoscaler" "myautoscaler" {
  name   = "myautoscaler"
  zone   = "europe-southwest1-a"
  target = google_compute_instance_group_manager.mygroupmanager.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

resource "google_compute_instance_group_manager" "mygroupmanager" {
  name = "mygroupmanager"
  zone = "europe-southwest1-a"
  
  version {
    instance_template  = google_compute_instance_template.mytemplate.id
  }

  base_instance_name = "instance"
}

resource "google_compute_firewall" "book" {
    name = "book-firewall"
    network = google_compute_network.vpc_network.name

    allow {
        protocol = "tcp"
        ports = [var.http_port, "22"]
    }
    source_ranges = ["0.0.0.0/0"]
    target_tags = ["tag1"]
}


