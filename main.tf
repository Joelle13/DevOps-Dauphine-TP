# Activation des APIs nécessaires

#cloudresourcemanager.googleapis.com
resource "google_project_service" "ressource_manager" {
    service = "cloudresourcemanager.googleapis.com"
}

#serviceusage.googleapis.com
resource "google_project_service" "ressource_usage" {
    service = "serviceusage.googleapis.com"
    depends_on = [ google_project_service.ressource_manager ]
}

#artifactregistry.googleapis.com
resource "google_project_service" "artifact" {
    service = "artifactregistry.googleapis.com"
    depends_on = [ google_project_service.ressource_manager ]
}

#sqladmin.googleapis.com
resource "google_project_service" "sql" {
  service = "sqladmin.googleapis.com"
  depends_on = [ google_project_service.ressource_manager ]
}

#cloudbuild.googleapis.com
resource "google_project_service" "cloud_build" {
  service = "cloudbuild.googleapis.com"
  depends_on = [ google_project_service.ressource_manager ]
}

# Créer le repository Artifact Registry
resource "google_artifact_registry_repository" "my-repo" {
  location      = "us-central1"
  repository_id = "website-tools"
  description   = "Exemple de repo Docker"
  format        = "DOCKER"

  depends_on = [ google_project_service.artifact ]
}

# SQL Database
resource "google_sql_database" "database" {
  name     = "wordpress"
  instance = "main-instance"
}

# SQL User
resource "google_sql_user" "wordpress" {
   name     = "wordpress"
   instance = "main-instance"
   password = "ilovedevops"
}

data "google_iam_policy" "noauth" {
   binding {
      role = "roles/run.invoker"
      members = [
         "allUsers",
      ]
   }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
   location    = google_cloud_run_service.default.location # remplacer par le nom de votre ressource
   project     = google_cloud_run_service.default.project # remplacer par le nom de votre ressource
   service     = google_cloud_run_service.default.name # remplacer par le nom de votre ressource

   policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_run_service" "default" {
name     = "serveur-wordpress"
location = "us-central1"

template {
   spec {
      containers {
        ports {
          container_port = 80
        }
      image = "us-central1-docker.pkg.dev/tp1-devops-449218/website-tools/wordpress-image:0.1"
      }
   }
}

traffic {
   percent         = 100
   latest_revision = true
}
}
# Ajout du provider Kubernetes
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

data "google_client_config" "default" {}

data "google_container_cluster" "my_cluster" {
   name     = "gke-dauphine"
   location = "us-central1-a"
}

provider "kubernetes" {
   host                   = data.google_container_cluster.my_cluster.endpoint
   token                  = data.google_client_config.default.access_token
   cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)
}

# Code généré par ChatGPT pour la question 5.iii de la partie 3
# Create a Namespace
resource "kubernetes_namespace" "wordpress_ns" {
  metadata {
    name = "wordpress"
  }
}

# Deploy MySQL Database
resource "kubernetes_deployment" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.wordpress_ns.metadata[0].name
    labels = {
      app = "mysql"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:5.7"

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "rootpassword"
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "wordpress"
          }

          env {
            name  = "MYSQL_USER"
            value = "wordpress"
          }

          env {
            name  = "MYSQL_PASSWORD"
            value = "wordpresspassword"
          }

          port {
            container_port = 3306
          }
        }
      }
    }
  }
}

# Create MySQL Service
resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.wordpress_ns.metadata[0].name
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }
  }
}

# Deploy WordPress Application
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress_ns.metadata[0].name
    labels = {
      app = "wordpress"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:latest"

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mysql.wordpress.svc.cluster.local:3306"
          }

          env {
            name  = "WORDPRESS_DB_USER"
            value = "wordpress"
          }

          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "wordpresspassword"
          }

          env {
            name  = "WORDPRESS_DB_NAME"
            value = "wordpress"
          }

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Expose WordPress using a LoadBalancer
resource "kubernetes_service" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress_ns.metadata[0].name
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}