# Ubuntu ARM Base Box

This directory contains the first narrow image pipeline for `vagrant-provider-avf`.

It builds one Ubuntu 24.04.4 ARM64 base image, packages it as an `:avf` box, and provides one smoke workflow for local Apple Silicon hosts.

For the full repo-wide testing and verification guide, see [docs/testing.md](/Users/jim/Code/vagrant-provider-avf/docs/testing.md).
For publishing the verified box, see [docs/releasing.md](/Users/jim/Code/vagrant-provider-avf/docs/releasing.md).

## Host Requirements

- Docker with Linux ARM64 support
- `bsdtar`
- Apple Silicon Mac with Xcode command line tools
- Vagrant with `vagrant-provider-avf` installed for the smoke workflow

## What The Image Contains

- Ubuntu Base 24.04.4 ARM64
- `linux-image-virtual`
- `openssh-server`
- DHCP on the first `en*` interface
- a `vagrant` user with passwordless sudo
- a deliberately insecure SSH keypair packaged with the box
- no pre-generated SSH host keys in the packaged disk image
- no pre-set machine identity in the packaged disk image
- a small systemd unit that prints the guest SSH address to the serial console once the guest network is up

The provider uses that serial-console marker to start a localhost SSH forwarder and populate `ssh_info` with `127.0.0.1` plus the assigned forwarded port.
The Ubuntu workflow now boots directly from the packaged kernel, initrd, and labeled ext4 root disk; it does not attach a separate runtime seed image.
The Linux guest also uses AVF virtiofs for synced folders, so the default `/vagrant` share and explicit `config.vm.synced_folder` paths can write back to the host.
The embedded `Vagrantfile` keeps SSH key-only and leaves the normal `/vagrant` share enabled.

## Build The Disk Artifacts

Run:

```bash
images/ubuntu/build-image
```

This writes deterministic artifacts to `build/images/ubuntu-24.04-arm64/`:

- `disk.img`
- `vmlinuz`
- `initrd.img`
- `release.txt`

## Package The Box

Run:

```bash
scripts/build-box
```

This writes:

- `build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box`
- `build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box.sha256`

The box is a flat Vagrant archive with:

- `metadata.json`
- `info.json`
- `Vagrantfile`
- `box/vmlinuz`
- `box/initrd.img`
- `box/disk.img`
- `box/insecure_private_key`

The embedded `Vagrantfile` keeps the default `/vagrant` synced folder enabled, points the AVF provider at the packaged boot artifacts, and configures SSH for the `vagrant` user.

## Add The Box Locally

Run:

```bash
vagrant box add --name avf/ubuntu-24.04-arm64 build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box
```

Then create a `Vagrantfile` like this:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "avf/ubuntu-24.04-arm64"
  config.vm.box_check_update = false

  config.vm.provider :avf do |avf|
    avf.cpus = 2
    avf.memory_mb = 2048
    avf.disk_gb = 8
  end
end
```

## Smoke Workflow

Run:

```bash
scripts/smoke-box build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box
```

The smoke script:

- adds the box locally
- boots it with `vagrant up --provider=avf`
- waits for `vagrant ssh` to work
- verifies `vagrant ssh-config` exposes `127.0.0.1`, the forwarded SSH port, and the `vagrant` user
- verifies the guest generated a machine id and SSH host keys at first boot
- verifies the default `/vagrant` share is mounted
- verifies a custom share under `/home/vagrant/workdir`
- writes through that custom share and confirms the file appears on the host
- runs a small SSH command in the guest
- halts the machine
- confirms SSH does not remain usable while the machine is stopped
- boots it again and verifies the forwarded SSH port stays stable
- writes through the custom share again after restart and confirms host write-back still works
- destroys the running machine

## Real Acceptance Spec

The repo also has one opt-in RSpec acceptance workflow that wraps the smoke path in an isolated `VAGRANT_HOME` and installs the local plugin gem first:

```bash
AVF_REAL_ACCEPTANCE=1 bundle exec rspec spec/acceptance/ubuntu_box_workflow_spec.rb
```

That path uses [scripts/run-acceptance-ubuntu](/Users/jim/Code/vagrant-provider-avf/scripts/run-acceptance-ubuntu).
If the default local box is missing, the script will build the image and package the box first when Docker is available.

For CI jobs on Apple Silicon macOS hosts, use:

```bash
scripts/ci-ubuntu-acceptance
```

The repo also includes a small [Jenkinsfile](/Users/jim/Code/vagrant-provider-avf/Jenkinsfile) that runs the fast suite, then this real Ubuntu acceptance flow, and archives the built box plus any preserved acceptance artifacts.

To keep the temporary acceptance directories after a failure, set:

```bash
AVF_KEEP_FAILURE_ARTIFACTS=1
```

To keep them in a deterministic CI workspace path, also set:

```bash
AVF_ACCEPTANCE_ROOT=/absolute/path/to/build/acceptance/ubuntu
```

## Current Limitations

- the build path is pinned to Ubuntu 24.04.4 ARM64 only
- the image build currently depends on Docker instead of a host-native macOS pipeline
- SSH discovery is currently specific to this curated Ubuntu image because the guest emits the address marker the provider expects
- this remains the cleanest curated Linux flow in the repo, but AlmaLinux and Rocky are also supported publish targets now
