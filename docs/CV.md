# Putting this on your CV (honestly)

**Golden rule:** only write what you have **really done** and can **explain line by line**. An interviewer will ask *"how exactly did you do that?"*. This project gives you the answer.

## Option A: you implemented it at Luul Solutions (best)
When you roll this out for your real team (with your lead's approval), you can write:

**DevOps / Platform Engineer, Luul Solutions**
- Led the move from long-lived feature branches to **trunk-based development** for developers, QA and lead engineers; introduced short-lived branches, squash merges and **feature flags** to decouple deploy from release.
- Designed GitHub **rulesets** and **CODEOWNERS** with role-based access (developers: write, QA: e2e ownership, leads: maintain + prod approval, platform: admin), enforcing PR reviews, required status checks and linear history on `main`.
- Built **GitHub Actions** CI/CD: unit, e2e, Docker build and secret-scan checks on every PR; build-once SHA-tagged images promoted **dev → staging → prod** with environment approvals and one-click rollback.
- Managed GitHub teams, permissions, rulesets and environments **as code with Terraform**, making access changes reviewed and auditable.
- Reduced incidents from leaked credentials and broken builds with **push protection, gitleaks, pre-commit hooks** and a merge queue; documented runbooks for rollback, hotfix (cherry-pick to release branches) and incident recovery (`revert`, `bisect`, `reflog`).

Add numbers **only if you measure them**, e.g. *"deploy frequency from every 2 weeks to daily"* or *"lead time from 5 days to under 1 day"*.

## Option B: from this project only (until you do it at work)
Put it under **Projects**, not under a job:

**luul-orders-service: trunk-based delivery platform (personal project)** · github.com/your-org/luul-orders-service
- Simulated a 5-person team (developers, QA, lead, platform) with role-based GitHub permissions, rulesets and CODEOWNERS, defined in **Terraform**.
- GitHub Actions CI/CD with required checks (unit, e2e, Docker, gitleaks) and environment-gated promotion to production.
- Wrote 10 reproducible incident scenarios (merge conflicts, broken trunk, leaked secrets, bisecting regressions, release hotfixes) with tested runbooks.

## Interview story (STAR), ready to tell
- **S:** Our team had long-lived branches. Merges were painful, QA got huge batches, and releases were risky.
- **T:** As the platform engineer I had to make delivery faster and safer for devs, QA and leads.
- **A:** Trunk-based workflow, rulesets + CODEOWNERS per role, CI with required checks, build once and promote with prod approvals, feature flags, Terraform for GitHub config, and runbooks for common incidents.
- **R:** Smaller PRs, fewer conflicts, faster QA feedback, safe rollback in minutes. (Use your real numbers.)

## Questions they'll ask about it (practise out loud)
1. Why trunk-based over GitFlow for your team?
2. How do QA and developers work together if everything merges to main daily?
3. Who can deploy to prod and how is it enforced?
4. Two PRs were green but main broke. Why, and how did you prevent it?
5. A developer pushed an AWS key. Walk me through your response.
6. How do you roll back? How do you hotfix an old release?
7. Why manage GitHub settings with Terraform?
8. How do you onboard and offboard an engineer?

Full answers to these and 46 more: `INTERVIEW-QA.md` (54 questions), or section 12 of the PDF.
Print `Interview-Practice-Sheet.pdf` to practise without seeing the answers.
