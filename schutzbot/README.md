# Schutzbot

This directory contains GitHub -> GitLab CI/CD pipeline.

## The workflow:

* GitHub Action `.github/workflows/trigger-gitlab.yml` checkouts the branch and pushes it into GitLab.
* GitLab starts CI/CD pipeline based on `.gitlab-ci.yml`.
* Terraform is checked out (`schutzbot/terraform`) and deploys runner instances.
* Terraform Executor prepares the runners.
* Script `schutzbot/update_github_status.sh` sets GitHub state to pending.
* Runners execute scripts from `schutzbot/`
* Script `schutzbot/update_github_status.sh` updates GitHub to final state.

## GitLab Repo

https://gitlab.com/redhat/services/products/image-builder/ci/osbuild-foundry

## Creating a new setup

* Create GitHub/GitLab repositories.
* Make sure GitLab project that is *public*.
* Create `.github/workflows/trigger-gitlab.yml`.
* Set required GitHub Action variables.
* Create `.gitlab-ci.yml`.
* Set required GitLab CICD variables.

## Other links

* https://github.com/osbuild/image-builder-terraform
* https://github.com/osbuild/gitlab-ci-config
* https://github.com/osbuild/gitlab-ci-terraform
* https://github.com/osbuild/gitlab-ci-terraform-executor
