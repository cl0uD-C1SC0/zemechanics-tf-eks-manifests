resource "null_resource" "auth_to_eks" {
  depends_on = [
    aws_eks_cluster.zemechanics-cluster,
    aws_eks_node_group.ndg-nodegroup
  ]

  triggers = {
    cluster_endpoint = aws_eks_cluster.zemechanics-cluster.endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region us-east-1 --name ${aws_eks_cluster.zemechanics-cluster.name}
    EOT
  }
}

# DEPLOY 01: INGRESS
resource "null_resource" "deploy-ingress-nginx" {
  depends_on = [null_resource.auth_to_eks]

  triggers = {
    manifest_hash = filemd5("${path.module}/k8s/nginx/ingress-nginx.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/k8s/nginx/ingress-nginx.yaml
    EOT
  }
}

resource "null_resource" "wait_for_nlb" {
  depends_on = [null_resource.deploy-ingress-nginx]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $hostname = $null
      for ($i = 1; $i -le 30; $i++) {
        $hostname = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
        if ($hostname) {
          Write-Host "NLB pronto: $hostname"
          exit 0
        }
        Write-Host "Aguardando NLB... ($i/30)"
        Start-Sleep -Seconds 10
      }
      Write-Host "Timeout esperando NLB"
      exit 1
    EOT
  }
}

# CREATE NS: zemechanics
resource "null_resource" "namespace-zemechanics" {
  depends_on = [null_resource.auth_to_eks]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl create ns zemechanics
    EOT
  }
}

# DEPLOY 03: MAILDEV
resource "null_resource" "deploy-maildev-dp" {
  depends_on = [null_resource.namespace-zemechanics]

  triggers = {
    manifest_hash = filemd5("${path.module}/k8s/maildev/maildev-dp.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/k8s/maildev/maildev-dp.yaml
    EOT
  }
}

resource "null_resource" "deploy-maildev-svc" {
  depends_on = [null_resource.namespace-zemechanics]

  triggers = {
    manifest_hash = filemd5("${path.module}/k8s/maildev/maildev-svc.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/k8s/maildev/maildev-svc.yaml
    EOT
  }
}

# DEPLOY 03: APP CONFIGURATIONS

# SECRET
resource "kubernetes_secret_v1" "mecanica_sec" {

  depends_on = [ null_resource.namespace-zemechanics ]

  metadata {
    name      = "mecanica-sec"
    namespace = "zemechanics"
  }

  data = {
    DATABASE_URL      = "mysql+pymysql://${var.database_username}:${var.database_password}@${aws_db_instance.zemechanics-rds.address}/mecanica"
    DATABASE_USERNAME = var.database_username
    DATABASE_PASSWORD = var.database_password
    SECRET_KEY        = var.secret_key
    SECRET_KEY_JWT    = var.secret_key_jwt
    USER_NAME         = var.user_name
    USER_PASSWORD     = var.user_password
    MAIL_SERVER_ADDRESS = var.mail_server_address
  }

  type = "Opaque"
}

# INGRESS
resource "null_resource" "deploy-ingress-api" {
  depends_on = [null_resource.namespace-zemechanics, null_resource.deploy-ingress-nginx]

  triggers = {
    manifest_hash = filemd5("${path.module}/k8s/api/mecanica-ingress.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/k8s/api/mecanica-ingress.yaml
    EOT
  }
}

# CONFIGMAP
resource "null_resource" "deploy-cfg-api" {
  depends_on = [null_resource.namespace-zemechanics]

  triggers = {
    manifest_hash = filemd5("${path.module}/k8s/api/mecanica-cfg.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/k8s/api/mecanica-cfg.yaml
    EOT
  }
}

# SVC
resource "null_resource" "deploy-svc-api" {
  depends_on = [null_resource.namespace-zemechanics]

  triggers = {
    manifest_hash = filemd5("${path.module}/k8s/api/mecanica-svc.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/k8s/api/mecanica-svc.yaml
    EOT
  }
}


# DEPLOYMENT
resource "kubernetes_deployment_v1" "mecanica_dp" {

  depends_on = [ null_resource.namespace-zemechanics, kubernetes_secret_v1.mecanica_sec, null_resource.deploy-cfg-api, null_resource.deploy-svc-api ]

  metadata {
    name      = "mecanica-dp"
    namespace = "zemechanics"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mecanica-dp"
      }
    }

    template {
      metadata {
        labels = {
          app = "mecanica-dp"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-registry-helper"
        }

        container {
          name  = "mecanica-container"
          image = "${aws_ecr_repository.ecr.repository_url}:latest"

          port {
            container_port = 8000
          }

          env_from {
            config_map_ref {
              name = "mecanica-cfg"
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.mecanica_sec.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/v1/health/live"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds         = 10
          }

          readiness_probe {
            http_get {
              path = "/api/v1/health/ready"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds         = 10
          }
        }
      }
    }
  }
}
