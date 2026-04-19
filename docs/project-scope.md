# Project Scope
`vagrant-provider-avf` is a Vagrant provider for Apple Virtualization Framework on Apple Silicon Macs.

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Apple Inc.

Apple, macOS, and Apple Silicon are trademarks of Apple Inc., registered in the U.S. and other countries.

## Current Scope

The repo currently supports three narrow Linux guest workflows:

- Ubuntu 24.04.4 ARM64 under [images/ubuntu/README.md](/Users/jim/Code/vagrant-provider-avf/images/ubuntu/README.md)
- AlmaLinux 9 ARM64 under [images/almalinux/README.md](/Users/jim/Code/vagrant-provider-avf/images/almalinux/README.md)
- Rocky Linux 9 ARM64 under [images/rocky/README.md](/Users/jim/Code/vagrant-provider-avf/images/rocky/README.md)

Shared provider behavior:

- headless only
- Apple `Virtualization.framework` runtime through a signed local helper
- NAT networking plus localhost SSH port forwarding
- one persisted SSH forwarding port per machine, reused across restarts when possible
- Linux shared directories only, through AVF virtiofs
- direct-kernel boot for the curated Ubuntu box
- EFI disk boot plus a provider-generated NoCloud seed disk for AlmaLinux, Rocky, and future Linux cloud-image flows
- explicit cleanup on `halt` and `destroy`

Current limits:

- Apple Silicon macOS only
- Xcode command line tools are required so the AVF helper can be built and signed locally
- no bridged networking
- no snapshots
- no GUI path
- no BSD guests in the active support matrix right now

The support and release bar lives in [docs/guest-support.md](/Users/jim/Code/vagrant-provider-avf/docs/guest-support.md).
The full test guide lives in [docs/testing.md](/Users/jim/Code/vagrant-provider-avf/docs/testing.md).
The publish guide lives in [docs/releasing.md](/Users/jim/Code/vagrant-provider-avf/docs/releasing.md).
Enterprise Linux notes live in [docs/enterprise-linux.md](/Users/jim/Code/vagrant-provider-avf/docs/enterprise-linux.md).
Example Vagrantfiles live under [examples/README.md](/Users/jim/Code/vagrant-provider-avf/examples/README.md).

## Verification

Fast suite:

```bash
bundle exec rspec
```

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

Rocky:

```bash
images/rocky/build-image
scripts/build-rocky-box
scripts/ci-rocky-acceptance
```

Supported Linux matrix:

```bash
scripts/ci-supported-linux
```

That runner uses temporary acceptance roots by default and cleans them on success unless `AVF_KEEP_FAILURE_ARTIFACTS=1` is set.

Release-confidence pass:

```bash
scripts/release-confidence
```

That rebuilds the three supported Linux box artifacts from the current checkout, runs the fast suite, and runs the full supported Linux system matrix.

To inspect a preserved acceptance workspace or a direct machine directory:

```bash
scripts/inspect-machine build/acceptance/ubuntu
```

That prints the machine metadata, AVF start payload, helper log, console log, and matching host DHCP leases.

## Common Gotchas

- `bundle exec rspec` skips the hardware-backed acceptance specs unless `AVF_REAL_ACCEPTANCE=1` is set
- the Ubuntu image build still depends on Docker with Linux ARM64 support
- the AlmaLinux and Rocky image builds are host-native and depend on `qemu-img`
- `scripts/smoke-box` uses the current `VAGRANT_HOME`
- `scripts/run-acceptance-ubuntu`, `scripts/run-acceptance-almalinux`, and `scripts/run-acceptance-rocky` create isolated `VAGRANT_HOME` directories
- the Linux shared-folder path is AVF virtiofs only
- the real smoke and acceptance flows expect the forwarded SSH port to stay stable across `halt` and a later `up`

## Publishing Boxes

The repo includes a thin publish wrapper for supported Linux boxes:

```bash
scripts/publish-box myorg/ubuntu-24.04-arm64 0.1.0 build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box
```

Add `--release` to make the uploaded version active immediately.

For the current `sodini-io` rollout, the repo also includes an HCP-friendly orchestration wrapper:

```bash
export HCP_CLIENT_ID="..."
export HCP_CLIENT_SECRET="..."
scripts/publish-supported-linux 0.1.0 --family ubuntu --release
```

That defaults to the `sodini-io` organization, runs `scripts/release-confidence` unless `--skip-confidence` is set, and can publish Ubuntu, AlmaLinux, and Rocky in rollout order.
It also syncs the public box descriptions first, so the registry entries point back to the source repo:

- [https://github.com/sodini-io/vagrant-provider-avf](https://github.com/sodini-io/vagrant-provider-avf)

The provider plugin itself is a separate RubyGems release. To publish the current gem version:

```bash
export GEM_HOST_API_KEY="..."
scripts/publish-gem
```

That builds the current `vagrant-provider-avf` gem under `build/gems/`, runs `scripts/release-confidence` by default, and pushes the gem to RubyGems.org.

Today the publish path is intentionally limited to:

- Ubuntu
- AlmaLinux
- Rocky Linux

Recommended upstream order:

1. publish Ubuntu as the first unreleased candidate
2. verify install and `vagrant up` from the registry in a clean `VAGRANT_HOME`
3. release Ubuntu
4. repeat the same unreleased-then-release flow for AlmaLinux
5. repeat it for Rocky Linux

Low-effort additions worth keeping in play:

- more example Vagrantfiles when we add real user-facing features
- a single supported Linux CI matrix runner, which now exists as `scripts/ci-supported-linux`

Still intentionally deferred:

- snapshots
- bridged networking
- custom networking modes
- fixed user-configurable SSH port settings
- OpenBSD or other BSD guests
