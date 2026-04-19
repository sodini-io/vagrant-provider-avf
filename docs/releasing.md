# Releasing Boxes

This repo can build and publish local `.box` artifacts for the `avf` provider.

Use this guide only after the fast suite and the relevant guest-specific acceptance workflow are green.
The current support matrix is in [docs/guest-support.md](/Users/jim/Code/vagrant-provider-avf/docs/guest-support.md).

## Prerequisites

- `vagrant` installed
- authenticated for your target registry using one of:
  - `HCP_CLIENT_ID` and `HCP_CLIENT_SECRET`
  - `VAGRANT_CLOUD_TOKEN`
- a verified box artifact under `build/boxes/`
- the relevant guest workflow already tested locally

If your old Vagrant Cloud organization has been migrated, claim it in HCP first:

- [Migrate to HCP Vagrant Registry](https://developer.hashicorp.com/vagrant/vagrant-cloud/hcp-vagrant/migration-guide)

## Authentication Setup

The most reliable CLI path is token-based login, not the interactive username/password flow.

Why:

- current Vagrant still supports `vagrant cloud auth login --token ...`
- the interactive login flow asks for a token description because it tries to create a token on your behalf
- if that interactive flow returns `Method Not Allowed`, skip it and use a pre-created token instead

Recommended path for a normal Vagrant Cloud account:

1. Create a token in the token section of your Vagrant Cloud account settings.
2. Save it locally with:

```bash
vagrant cloud auth login --token YOUR_TOKEN_HERE
```

3. Verify it with:

```bash
vagrant cloud auth whoami
vagrant cloud auth login --check
```

You can also avoid writing the token to disk and use an environment variable instead:

```bash
export VAGRANT_CLOUD_TOKEN="YOUR_TOKEN_HERE"
```

If your target organization has been migrated to HCP Vagrant Registry, the auth story changes:

- if all of your target registries are already in HCP, use an HCP access token in `VAGRANT_CLOUD_TOKEN`
- if you still need to work with both migrated and unmigrated registries, use the documented composite token format:

```bash
export VAGRANT_CLOUD_TOKEN="<VAGRANT_CLOUD_TOKEN>;<HCP_TOKEN>"
```

If your organizations are in HCP and you are using Vagrant 2.4.3 or later, you can also rely on:

```bash
export HCP_CLIENT_ID="..."
export HCP_CLIENT_SECRET="..."
```

For a brand-new HCP-only registry, this is usually the simplest path:

1. In the HCP portal, open your project.
2. Open `Access control (IAM)`.
3. Create a service principal with:
   - `Contributor` if the registry already exists
   - `Admin` if you still need to create the registry
4. Open that service principal and generate a key.
5. Export the generated values:

```bash
export HCP_CLIENT_ID="..."
export HCP_CLIENT_SECRET="..."
unset VAGRANT_CLOUD_TOKEN
```

In that setup, skip `vagrant cloud auth login` entirely. The interactive username/password flow may fail with `Method Not Allowed` because it is trying to create a classic Vagrant Cloud token on your behalf instead of using HCP service-principal auth.

The current official migration and auth details are here:

- [Usage and Behavior Post Migration to HCP](https://developer.hashicorp.com/vagrant/vagrant-cloud/hcp-vagrant/post-migration-guide)
- [Authentication](https://developer.hashicorp.com/vagrant/vagrant-cloud/users/authentication)
- [Vagrant cloud CLI](https://developer.hashicorp.com/vagrant/docs/cli/cloud)

## Build And Verify First

Ubuntu:

```bash
images/ubuntu/build-image
scripts/build-box
scripts/ci-ubuntu-acceptance
```

AlmaLinux:

```bash
images/almalinux/build-image
scripts/build-almalinux-box
scripts/ci-almalinux-acceptance
```

Rocky Linux:

```bash
images/rocky/build-image
scripts/build-rocky-box
scripts/ci-rocky-acceptance
```

Only publish artifacts that passed their intended workflow.

For a single repo-level confidence gate before publishing anything, run:

```bash
scripts/release-confidence
```

That rebuilds the supported Linux `.box` artifacts from the current checkout, runs the fast suite, and runs the full supported Linux system matrix.

## Publish An Unreleased Version

```bash
scripts/publish-box myorg/ubuntu-24.04-arm64 0.1.0 build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box
```

That publishes the `avf` provider entry without releasing the version.

Until the version is released, name-based installs such as:

```bash
vagrant box add myorg/ubuntu-24.04-arm64 --provider avf
```

may fail with a misleading provider error because the registry is not yet advertising any visible versions/providers for that box. A quick check is:

```bash
curl -fsSL https://vagrantcloud.com/api/v2/vagrant/myorg/ubuntu-24.04-arm64
```

If the response shows `"versions": []`, the version is still unreleased from the registry point of view.

For the current `sodini-io` HCP rollout, use the repo wrapper:

```bash
export HCP_CLIENT_ID="..."
export HCP_CLIENT_SECRET="..."
scripts/publish-supported-linux 0.1.0 --family ubuntu
```

That script:

- defaults to `sodini-io`
- runs `scripts/release-confidence` unless `--skip-confidence` is set
- can target `ubuntu`, `almalinux`, or `rocky`
- stages unreleased versions by default
- waits for the registry API to show the `avf` provider when `--release` is used

By default the wrapper only allows supported Linux targets through:

- Ubuntu
- AlmaLinux
- Rocky Linux

Unknown targets are blocked until they are added deliberately to the release matrix.

## Suggested First Upstream Plan

The lowest-risk upstream sequence is:

1. publish Ubuntu first as an unreleased version
2. verify it from a clean `VAGRANT_HOME` using `vagrant box add` and `vagrant up`
3. release the Ubuntu version once that registry-hosted install path is green
4. repeat the same unreleased-then-release flow for AlmaLinux
5. repeat it for Rocky Linux

Why this order:

- Ubuntu is the smallest curated path and the easiest first public support story
- AlmaLinux and Rocky already clear the same real acceptance bar locally, but publishing them after Ubuntu keeps the first registry rollout simpler
- Vagrant Cloud and HCP Vagrant Registry both support unreleased versions, so we can stage uploads before making them active

## Publish And Release In One Step

Ubuntu:

```bash
scripts/publish-box myorg/ubuntu-24.04-arm64 0.1.0 build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box --release
```

AlmaLinux:

```bash
scripts/publish-box myorg/almalinux-9-arm64 0.1.0 build/boxes/avf-almalinux-9-arm64-0.1.0.box --release
```

Rocky Linux:

```bash
scripts/publish-box myorg/rocky-9-arm64 0.1.0 build/boxes/avf-rocky-9-arm64-0.1.0.box --release
```

## Manual CLI Equivalent

The wrapper is equivalent to:

```bash
vagrant cloud publish myorg/ubuntu-24.04-arm64 0.1.0 avf build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box --force
```

Official references:

- [Vagrant cloud CLI](https://developer.hashicorp.com/vagrant/docs/cli/cloud)
- [Create a new box version](https://developer.hashicorp.com/vagrant/vagrant-cloud/boxes/create-version)
- [Box lifecycle](https://developer.hashicorp.com/vagrant/vagrant-cloud/boxes/lifecycle)
- [Migrate to HCP Vagrant Registry](https://developer.hashicorp.com/vagrant/vagrant-cloud/hcp-vagrant/migration-guide)

## Naming Guidance

Current repo box names:

- `avf/ubuntu-24.04-arm64`
- `avf/almalinux-9-arm64`
- `avf/rocky-9-arm64`

Published under an organization, those become:

- `myorg/ubuntu-24.04-arm64`
- `myorg/almalinux-9-arm64`
- `myorg/rocky-9-arm64`

## Gotchas

- rebuild the box artifact and checksum from the current commit before publishing
- an uploaded unreleased version can still be reachable if someone knows the version URL
- if the organization is still in Vagrant Cloud and has not migrated yet, complete the HCP migration first; during migration the organization is read-only and uploads/releases are unavailable
- keep the embedded `Vagrantfile` and the `avf` provider name stable
- uploading a new version does not replace `vagrant box update` on consumer machines
