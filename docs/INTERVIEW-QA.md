# Interview questions and answers (54)

Practise out loud: cover the answer, say yours in under a minute, then compare.
Questions only (to print): `Interview-Practice-Sheet.pdf`. Same answers in the team PDF, section 12.

## A. The basics

**Q1. What is the difference between Git and GitHub?**

Git is the version control tool on every laptop: it records commits, branches and history. GitHub hosts Git repositories and adds teamwork features: pull requests, code review, Actions for CI/CD, permissions, rulesets and security scanning.

**Q2. Explain trunk-based development in one or two sentences.**

Everyone merges small changes into one shared branch, **main**, at least once a day. Branches live hours, not weeks, main is always deployable, and unfinished work is hidden behind feature flags.

**Q3. What does "main is always deployable" mean in practice?**

Any commit on main could go to production right now. We make that true with required CI checks on every PR, code review, feature flags for unfinished work, and a rule that a red main is fixed or reverted immediately.

**Q4. If everyone merges daily, why do you still need pull requests?**

The PR is where the safety happens: CI runs the required checks, CODEOWNERS brings in the right reviewer, and there is an audit trail of who approved what. Trunk-based development doesn't mean no review, it means *small and fast* review.

**Q5. What is a feature flag?**

A switch in config that turns a feature on or off without deploying new code. In our project, **discounts_v2** in config/flags.json is off by default and can be overridden per environment with FLAG_DISCOUNTS_V2=true.

**Q6. What is the difference between deploy and release?**

**Deploy** puts code in an environment. **Release** makes a feature visible to users. With flags, we deploy every day with the flag OFF, and release later by turning the flag ON in a small PR, approved by the lead and QA.

> Tip: This one sentence shows you understand trunk-based development. Use it often.

## B. Trunk-based development in a team

**Q7. How do developers, QA and lead engineers work together in your workflow?**

Developers make small PRs from main and write unit tests. QA owns the end-to-end tests, which are a required check on every PR and also run against staging, and QA approves when a flag is turned on. Leads review risky code, like pricing, through CODEOWNERS and approve prod deployments. I, as platform, own the pipeline, rules and environments that make this automatic.

**Q8. How long should a branch live, and why?**

Hours, at most one or two days. The longer a branch lives, the more main moves away from it, so conflicts, review size and risk all grow. Short branches mean small conflicts and fast feedback.

**Q9. How big should a pull request be?**

Small enough to review properly in about 15 minutes, as a guide a few hundred lines at most, and doing **one** thing. Small PRs are reviewed faster, break less, and are easy to revert.

**Q10. If code is merged before it is finished, how does QA test it?**

The code is in main with the flag OFF, so users don't see it. QA turns the flag on in dev or staging (FLAG_DISCOUNTS_V2=true) and tests there. When QA is happy, the flag-on PR needs QA's approval. QA also adds e2e tests that run on every PR, so quality is checked continuously, not at the end.

**Q11. Why do you use squash merge?**

Each PR becomes one clean commit on main, with the PR number and a clear message. History is easy to read, release notes are easy to generate, and if something goes wrong we revert exactly one commit.

**Q12. How do you build a feature that takes three weeks?**

We still merge every day, in small slices behind a feature flag, or with *branch by abstraction* for big refactors. The feature grows inside main while it is switched off, then it is released with a flag PR.

**Q13. How do you keep your branch up to date with main?**

**git fetch** then **git rebase origin/main**, at least every morning and before asking for review. If the branch was already pushed, I push with **--force-with-lease**, which refuses if someone else pushed to my branch.

**Q14. How would you move a team from GitFlow to trunk-based development?**

Step by step, not in one day. 1) Get CI fast and reliable, with good tests, because trunk-based development depends on it. 2) Protect main with required checks and reviews. 3) Add feature flags. 4) Agree on team rules (daily merges, small PRs) and start with one pilot team. 5) Remove the develop branch, and measure lead time and deploy frequency to show the improvement.

> Tip: Interviewers like hearing that you brought people along, not just tools.

## C. Roles, permissions and security

**Q15. How did you design GitHub permissions for developers, QA, leads and platform?**

Teams with least privilege. Developers and QA have **Write**, leads have **Maintain**, platform has **Admin**. Nobody can push to main directly. Responsibility per file comes from CODEOWNERS, and prod deployments need a lead or platform approval through environment reviewers.

**Q16. What is CODEOWNERS and how did you use it?**

A file that maps paths to teams. When a PR touches a path, GitHub requests that team's review, and with "require code owner review" it must approve. We used it for app/pricing.py (leads), tests/e2e (QA), .github and Dockerfile (platform), and flags.json (leads + QA). The last matching line wins.

**Q17. What's the difference between branch protection rules and rulesets?**

Both protect branches. Rulesets are the newer system: several rulesets can apply at once and they stack, they have an explicit bypass list, anyone with read access can see them, they can target many branches by pattern, and on paid plans they can apply across the whole organization. Classic branch protection is one rule per branch pattern.

**Q18. Who can deploy to production, and how is that enforced?**

Only code from main, and only after a lead or platform engineer approves. The prod GitHub environment has required reviewers and a deployment branch policy (main only). The pipeline builds one image per commit and only that image is promoted, so nobody can deploy something that wasn't reviewed and tested.

**Q19. Why manage GitHub settings with Terraform instead of clicking in the UI?**

Changes are reviewed in a PR, there's history and an audit trail, setups are repeatable across many repos, and drift is visible with terraform plan. Access changes like onboarding become a reviewed PR instead of someone clicking in settings.

**Q20. How do you onboard and offboard an engineer?**

Onboarding: add them to the right team (a Terraform PR), they set up SSH keys and their git identity, clone, and run make hooks. Offboarding: remove them from the org the same day, revoke their tokens and keys, and rotate any shared secrets they could see.

**Q21. How do you keep secrets out of Git?**

Layers. A pre-commit hook on laptops, GitHub secret scanning with push protection, a gitleaks job in CI, and .gitignore for .env files. Real secrets live in GitHub Secrets or a vault, and CI uses OIDC to the cloud so there are no long-lived keys to leak.

**Q22. What is OIDC in GitHub Actions and why use it?**

GitHub gives each workflow run a short-lived signed token. The cloud (AWS, Azure, GCP) trusts it for a specific repo and branch and returns temporary credentials. No cloud keys are stored in GitHub, and nothing long-lived can leak.

## D. CI/CD and releases

**Q23. Walk me through your pipeline, from commit to production.**

A developer opens a PR. CI runs four required checks: unit-tests, e2e-tests, docker-build and secret-scan. CODEOWNERS reviewers approve, and we squash merge. CD then runs the tests again, builds one Docker image tagged with the commit SHA and pushes it to the registry, then deploys dev, then staging (where QA's e2e tests run), then waits for approval and deploys the *same* image to prod.

**Q24. Which checks are required on a PR, and who owns each one?**

unit-tests are owned by developers. e2e-tests are owned by QA. docker-build and secret-scan are owned by platform. All four are required in the ruleset, and the branch must be up to date with main.

**Q25. What does "build once, deploy many" mean?**

We build the artifact once per commit and promote the exact same image through every environment. What QA tested in staging is byte-for-byte what goes to prod. Rebuilding per environment could give a different result.

**Q26. What is a merge queue and when do you need it?**

Before merging, GitHub tests each PR together with the latest main and the PRs ahead of it in the queue. You need it when many PRs merge every day, because two PRs can each be green but break main together.

> Tip: Mention Scenario 3: WELCOME5 and WELCOME10.

**Q27. How do you version and release?**

Semantic versioning (MAJOR.MINOR.PATCH) with tags on main. Pushing a v1.2.0 tag runs the release workflow, which creates a GitHub Release with generated notes. To patch an old version we use a release branch and cherry-pick fixes from main.

**Q28. How do you roll back a bad deployment?**

The fastest option is to turn the flag off. Otherwise we redeploy the last good image by running CD with the previous commit (gh workflow run CD -f sha=<full SHA>), which also uses that commit's tests and settings, then **git revert** the bad commit on main so trunk is correct again. After that, a blameless postmortem.

**Q29. The pipeline is slow. How do you speed it up?**

Measure first. Then: cache dependencies and Docker layers, run jobs in parallel, run only what changed (path filters), split long test suites, cancel outdated runs with concurrency, and use bigger or self-hosted runners if needed.

## E. What would you do if... (incident questions)

**Q30. main is red right after two PRs were merged. What do you do?**

Restoring main comes first, because everyone is blocked. I find the commit with **git bisect run make test**, **git revert** it through a fast PR, and tell the authors. Then they fix it properly, and I prevent it with up-to-date checks or a merge queue.

**Q31. A developer pushed an AWS key to GitHub. What do you do?**

Rotate the key immediately, because it's compromised the moment it's public. Then remove it from the branch history (reset --soft, rm --cached, force-with-lease), or use git filter-repo if it reached main. Check the cloud audit logs for misuse, and add push protection, gitleaks and OIDC so it can't happen again.

**Q32. You and another developer conflict on business logic. How do you resolve it?**

I don't guess. I talk to the other author and, if it's a business decision, the lead. Then I rebase, resolve the conflict by keeping the agreed result, run the tests and push with --force-with-lease.

**Q33. QA finds a regression in staging and nobody knows which commit caused it.**

QA writes a test that reproduces the bug. I run **git bisect start HEAD <last-good-tag>** and **git bisect run** with that test to find the commit automatically. We fix forward and keep the test as a regression test.

**Q34. Prod has a bug, but main contains unfinished work. How do you hotfix?**

If the unfinished work is behind flags, main is still deployable, so we fix on main and ship normally. If prod runs from a release branch, we fix on main first, cherry-pick the fix (-x) into the release branch, and tag a patch version.

**Q35. A teammate ran git reset --hard and lost their commits.**

**git reflog** shows every position HEAD had, including the lost commits. Find the commit and use git reset --hard HEAD@{n} or git switch -c rescue <sha>. By default Git keeps lost commits in the reflog for 30 days.

**Q36. A developer opens a 2,000-line PR after two weeks of work.**

I help them split it, without blaming them: small branches from the latest main, cherry-pick related commits into separate PRs, and any half-finished part behind a flag. Then we look at why it happened (unclear tickets? no flags?) and fix the process.

**Q37. A flaky test is blocking every PR.**

I don't remove the required check. QA quarantines that one test (skip it with a ticket number) through a PR, the owner fixes it within an agreed time, and we track flaky tests so they don't build up.

## F. Hard follow-up questions

**Q38. Isn't it risky to merge unfinished code into main?**

The risk is lower than with long branches. The code is reviewed and tested, it's switched off by a flag, and it's integrated early, so problems show up while they're small. Big merges after weeks are the risky part.

**Q39. What if a lead approves a bad change?**

Review is one layer, not the only one. Required tests, staging e2e, gradual flag rollout and fast rollback catch what a reviewer misses. Afterwards we add a test for that case. A blameless postmortem looks at the process, not the person.

**Q40. Don't feature flags become technical debt?**

They do if nobody owns them. Each flag gets an owner and a ticket to remove it. When a flag has been at 100% for a while, we delete the flag and the old code path. Some teams also fail CI on flags past their expiry date.

**Q41. Your merge queue is slow. Now what?**

Make CI faster first (caching, parallel jobs). Then tune the queue: group several PRs per build, and only run the slowest tests in the queue rather than on every push.

**Q42. Admins can bypass the rules. Isn't that a security hole?**

It's a deliberate break-glass path for emergencies. We allow it only for org admins and only when merging a PR, never for direct pushes. Every bypass is logged in the audit log and reviewed afterwards.

**Q43. How do you measure whether trunk-based development is working?**

The four DORA metrics: deployment frequency, lead time for changes, change failure rate, and time to restore service. Also PR size, branch age and how often main is red.

**Q44. Some developers resist the change. How do you convince them?**

Listen to the concern first, because it's usually about breaking things. Show them the safety nets (flags, required checks, fast rollback), start with a pilot team, and share results with numbers. People adopt what makes their own day easier.

> Tip: A good answer for culture-fit and leadership questions.

## G. Working with developers (the developer's point of view)

**Q45. How do you, as a DevOps engineer, support developers day to day?**

I make the safe path the easy path: one command (**make test**) that runs the same checks locally as in CI, fast pipelines, clear error messages, templates for new services, and docs. I also look at failed pipelines with them and fix the platform when the problem is the platform, not their code.

**Q46. A developer says: "It works on my laptop but CI fails." What do you do?**

CI is a clean room, so I look for what the laptop has that CI doesn't. Typical causes: a new file that was never committed (**git status** shows ??), a local env var or flag, a different language version, or a package installed only locally. Running the same command as CI (make test) in a fresh clone usually shows it in a minute.

> Tip: Tell the story from the developer lab: ModuleNotFoundError for a file that was never git-added.

**Q47. QA's tests pass locally but fail in staging. How do you find the cause?**

Same code, so I compare **configuration** first: is the right commit deployed (/version)? Are flags and env vars the same (deploy/staging.env)? Then data and dependencies like databases or other services. In our lab the feature flag was OFF in staging, so the endpoint returned 404.

**Q48. What is the difference between unit tests and end-to-end tests, and who owns them?**

Unit tests call functions directly. They take milliseconds and catch logic bugs, and developers own them. End-to-end tests call the running service over HTTP like a customer and catch integration and config problems. QA owns ours, and they also run against staging. Both are required checks.

**Q49. Why should configuration be separate from code?**

So the **same image** runs in every environment and only settings change. Then what we tested is what we ship. Config lives in env files, flags or a config service per environment, and secrets in a vault, never baked into the image.

**Q50. What is test-driven development and why does it help trunk-based teams?**

Write a failing test that describes the behaviour, write the minimum code to pass it, then clean up. It keeps changes small, gives a safety net for merging daily, and makes every PR come with tests.

**Q51. How do you decide when a feature flag can be removed, and who removes it?**

When the feature has been fully on in prod for a while with no problems, the developer who owns the feature removes the flag and the old code path in a small PR, and platform removes it from the environment settings. Each flag has an owner and a removal ticket from day one.

**Q52. A developer wants to skip a failing required check to ship faster. What do you say?**

No, but I help. The check protects everyone on trunk. We look at the failure together: a real bug gets fixed, a flaky test gets quarantined with a ticket by its owner, a slow check gets made faster. If a rule really adds no value, we change it with a PR, never with a bypass.

**Q53. Which HTTP status codes should an API return, and why does DevOps care?**

200 for success, 400 for bad client input, 404 for not found, 500 only when our code crashed. DevOps alerts are built on these numbers. If bad input crashes the app with a 500 instead of returning a 400, on-call gets paged for a client mistake.

**Q54. How do health checks and /version help in production?**

**/health** lets Docker, Kubernetes and load balancers know if an instance is alive, so traffic only goes to healthy ones and broken ones get restarted. **/version** shows exactly which commit is running, which is the first question in any incident.
