output "team_slugs" {
  value = { for k, t in github_team.this : k => t.slug }
}
