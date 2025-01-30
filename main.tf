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