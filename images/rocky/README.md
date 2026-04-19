# Rocky Linux ARM Box

This directory contains the first Rocky Linux workflow for `vagrant-provider-avf`.

It is intentionally narrow:

- Rocky Linux `9.7-20251123.2`
- ARM64 / aarch64
- official `GenericCloud Base` image
- EFI boot from disk
- provider-generated NoCloud seed data for first boot
- one local box packaging path
- one Linux smoke workflow through the existing shared-folder and SSH path
- one real Apple Silicon acceptance workflow through `scripts/ci-rocky-acceptance`

For the full repo-wide testing and verification guide, see [docs/testing.md](/Users/jim/Code/vagrant-provider-avf/docs/testing.md).
For release guidance, see [docs/releasing.md](/Users/jim/Code/vagrant-provider-avf/docs/releasing.md).

## Host Requirements

- Apple Silicon Mac
- Xcode command line tools
- `curl`
- `shasum`
- `qemu-img`
- `bsdtar`
- Vagrant with `vagrant-provider-avf` installed for the smoke workflow

## Build The Disk Artifact

Run:

```bash
images/rocky/build-image
```

This downloads the official Rocky Linux 9 GenericCloud Base `aarch64` qcow2 image, verifies it against Rocky Linux's published `CHECKSUM` entry, converts it to raw, and writes:

- `build/images/rocky-9-arm64/disk.img`
- `build/images/rocky-9-arm64/release.txt`

## Package The Box

Run:

```bash
scripts/build-rocky-box
```

This writes:

- `build/boxes/avf-rocky-9-arm64-0.1.0.box`
- `build/boxes/avf-rocky-9-arm64-0.1.0.box.sha256`

The box contains:

- `metadata.json`
- `info.json`
- `Vagrantfile`
- `box/disk.img`
- `box/insecure_private_key`

The embedded `Vagrantfile` keeps the default `/vagrant` synced folder enabled, configures SSH for the `vagrant` user, and points the AVF provider at the packaged disk image.

## Add The Box Locally

```bash
vagrant box add --name avf/rocky-9-arm64 build/boxes/avf-rocky-9-arm64-0.1.0.box
```

Use a `Vagrantfile` like:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "avf/rocky-9-arm64"
  config.vm.box_check_update = false

  config.vm.provider :avf do |avf|
    avf.cpus = 2
    avf.memory_mb = 2048
    avf.disk_gb = 12
  end
end
```

The embedded `Vagrantfile` inside the box already sets `avf.disk_gb = 12`, so you only need to set it yourself if you want something larger.

## Smoke Workflow

Run the existing Linux smoke path with the Rocky box name:

```bash
DISK_GB=12 BOX_NAME=avf/rocky-9-arm64 scripts/smoke-box build/boxes/avf-rocky-9-arm64-0.1.0.box
```

That reuses the same Linux checks as Ubuntu and AlmaLinux:

- `vagrant up`
- `vagrant ssh`
- honest `ssh_info`
- default `/vagrant` shared folder
- explicit synced folders under `/home/vagrant/...`
- halt, restart, and destroy

## Real Acceptance

Run:

```bash
scripts/ci-rocky-acceptance
```

That installs the local plugin into an isolated `VAGRANT_HOME`, rebuilds the box if needed, and runs the real Apple Silicon workflow through `vagrant up`, SSH, halt, restart, and destroy.

## Notes

- This path depends on the provider-generated Linux NoCloud seed disk for the `vagrant` user, SSH key injection, DHCP config, and the serial-console SSH marker.
- The current pinned source image is `Rocky-9-GenericCloud-Base-9.7-20251123.2.aarch64.qcow2`.
- This path now clears the real Apple Silicon acceptance workflow on this host and is part of the supported Linux release matrix.
