variable "org" {
  description = "Sandbox GitHub organization (never the production org without approval)"
  type        = string

  validation {
    condition     = lower(var.org) != "luul-solutions"
    error_message = "Sandbox config: do not point it at the production Luul-Solutions org."
  }
}

variable "repo" {
  description = "Repository name"
  type        = string
  default     = "luul-orders-service"
}

variable "teams" {
  description = "Team name -> repo role and members"
  type = map(object({
    description = string
    permission  = string # pull | triage | push | maintain | admin
    members     = list(string)
  }))
  default = {
    developers = { description = "Write code, open PRs", permission = "push", members = [] }
    qa         = { description = "Own e2e tests, review flag changes", permission = "push", members = [] }
    leads      = { description = "Review money logic, approve prod", permission = "maintain", members = [] }
    platform   = { description = "Pipelines, settings, rulesets", permission = "admin", members = [] }
  }
}

variable "required_checks" {
  type    = list(string)
  default = ["unit-tests", "e2e-tests", "docker-build", "secret-scan"]
}
