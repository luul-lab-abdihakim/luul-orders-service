terraform {
  required_version = ">= 1.5"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Auth: export GITHUB_TOKEN=$(gh auth token)
provider "github" {
  owner = var.org
}
