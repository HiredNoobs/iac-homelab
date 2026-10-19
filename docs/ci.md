# CI

``master`` only takes pull requests, merged by the owner (``forgejo-repos.yml``), and ``Lint / lint (push)`` must pass on the branch first. Every job runs on the general runner, in Docker.

| Workflow | Runs for | Does |
| --- | --- | --- |
| ``lint.yml`` | Every push. No credentials. | fmt, validate, Ansible syntax, shellcheck. |
| ``clusters.yml`` | Pull requests and merges touching ``terraform/clusters/``, ``terraform/modules/talos-cluster/`` or itself. | A pull request: ``terraform plan`` (read it in the job's log). A merge into ``master``: plan and apply, ``-parallelism=1``. |

**CI credentials are in Vault, not in Forgejo.** Forgejo gives a repo's secrets to the workflows of any pushed branch, so anyone who can push (Renovate's bot too) could read them with a workflow of their own. Instead, the clusters workflow logs in to Vault with the ID token Forgejo signs for each job (``enable-openid-connect``), and Vault (``terraform/vault``, ``auth/forgejo``) checks the token's claims, which a workflow can't change:

| Vault role | Only for |
| --- | --- |
| ``clusters-apply`` | A push to ``master`` (a merge) by the owner, running ``master``'s ``clusters.yml``. |
| ``clusters-plan`` | A ``pull_request_target`` run of ``master``'s ``clusters.yml`` started by the owner. |

Both read ``labv2/ci/clusters`` (``PM_PASSWORD``, ``PG_PASSWORD``) and nothing else, for 10 minutes. ``clusters.sh`` revokes the Vault token as soon as it has read them, masks them in the log and hands them to Terraform alone. A workflow on any other branch, whoever pushed it, gets nothing.

- Your own pull requests are planned when opened or updated. Someone else's (Renovate's) only when you add a label, after reading it: the plan runs the pull request's Terraform code with the credentials (a provider pointed elsewhere would get them). ``pull_request_target`` makes the workflow and ``clusters.sh`` ``master``'s, whatever the pull request changes; a commit pushed afterwards needs a new label.
- The job log shows the ID token's claims (not the token). If Vault refuses a run, its error names the claim that didn't match.
- CI doesn't run ``mgmt.yml``: the talosconfigs only change with a new cluster or new client certificates. Run ``./build.sh clusters`` by hand then, and apply even if the plan has no changes (that changes nothing): it writes the talosconfigs and runs ``mgmt.yml``.
- The gitops and vault roots are only ever applied by hand, with ``build.sh``.
- A failed apply leaves the state as Terraform left it: fix forward with another pull request, or by hand with ``./build.sh clusters``.
