# Launch Post: vagrant-provider-avf 0.1.0

## Title

`vagrant-provider-avf 0.1.0: Native Linux Vagrant on Apple Silicon`

## Slug

`vagrant-provider-avf-0-1-0-native-linux-vagrant-on-apple-silicon`

## Excerpt

Today I’m releasing `vagrant-provider-avf` `0.1.0`, a lean Vagrant provider for Apple Silicon Macs built on Apple’s `Virtualization.framework`. It brings a small, dependable Linux-first Vagrant workflow to native ARM64 Macs, with support for Ubuntu, AlmaLinux, and Rocky Linux.

## WordPress Post

Today I’m releasing `vagrant-provider-avf` `0.1.0`, a lean Vagrant provider for Apple Silicon Macs built on Apple’s `Virtualization.framework`.

The goal of this project is simple: make Vagrant feel useful again on Apple Silicon without turning it into a giant VM platform or burying the implementation under layers of clever abstraction.

This first public release is intentionally narrow. It focuses on a small, dependable Linux-first workflow:

- native `avf` provider support for Vagrant on Apple Silicon macOS
- real lifecycle support for `up`, `halt`, `destroy`, `state`, and `ssh`
- honest `ssh_info` over localhost port forwarding
- Linux shared folders through AVF `virtiofs`
- curated ARM64 Linux box workflows for:
  - Ubuntu 24.04.4
  - AlmaLinux 9
  - Rocky Linux 9

What I wanted from this project was not a giant compatibility matrix or a half-finished GUI story. I wanted something boring in the best way: explicit, testable, readable, and actually pleasant to use for headless development workflows on Apple Silicon.

That shaped a lot of the decisions in this release:

- Apple Silicon only
- headless only
- Linux only
- no bridged networking
- no snapshots
- no GUI path

In other words, `0.1.0` is trying to be a good tool, not an ambitious roadmap.

## Why I Built It

Apple Silicon machines are excellent developer hardware, but the Vagrant story has felt uneven for native ARM64 workflows. There are plenty of ways to run virtual machines on a Mac, but I wanted a path that felt close to the platform:

- native Apple virtualization
- Vagrant workflows that still make sense
- simple box pipelines
- a provider that does not feel like generated scaffolding

I also wanted something that could be maintained without dread. That meant a project with hard boundaries, focused tests, explicit persistence, and minimal abstraction.

## What Works Today

The supported guests in `0.1.0` are:

- Ubuntu 24.04.4 ARM64
- AlmaLinux 9 ARM64
- Rocky Linux 9 ARM64

Supported behavior today includes:

- `vagrant up`
- `vagrant halt`
- `vagrant destroy`
- `vagrant ssh`
- provider-backed `ssh_info`
- localhost SSH forwarding
- read/write Linux shared folders through AVF `virtiofs`

The provider uses Apple `Virtualization.framework` through a signed local helper. Boxes and the provider plugin are published separately, which keeps the release story more honest and easier to reason about.

## Quickstart

Install the provider plugin:

`vagrant plugin install vagrant-provider-avf`

Add a box:

`vagrant box add sodini-io/ubuntu-24.04-arm64 --provider avf --box-version 0.1.0`

Use a minimal `Vagrantfile`:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "sodini-io/ubuntu-24.04-arm64"
  config.vm.box_check_update = false

  config.vm.provider :avf do |avf|
    avf.cpus = 2
    avf.memory_mb = 2048
    avf.disk_gb = 8
    avf.headless = true
  end
end
```

Then bring it up:

`vagrant up --provider avf`

## Release Links

- Source: [https://github.com/sodini-io/vagrant-provider-avf](https://github.com/sodini-io/vagrant-provider-avf)
- Issues: [https://github.com/sodini-io/vagrant-provider-avf/issues](https://github.com/sodini-io/vagrant-provider-avf/issues)

## Closing

I’m happy with where `0.1.0` landed.

It is small.
It is focused.
It works on real Apple Silicon hardware.
And it leaves plenty of room to improve Linux support further without pretending that every future feature needs to exist today.

If you try it, I’d love to hear how it goes.

## Suggested Tags

- Apple Silicon
- Vagrant
- Virtualization
- macOS
- Linux
- Open Source
- Ruby

## Suggested Featured Image Text

`vagrant-provider-avf 0.1.0`

`Native Linux Vagrant on Apple Silicon`
