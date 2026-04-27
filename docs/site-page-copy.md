# Site Page Recommendation

## Recommendation

Give `vagrant-provider-avf` its own page next to Perminator.

I would not bury this inside a generic "Open Source Tools" paragraph right now.

Why:

- this project already has a real release, install path, and support surface
- it has enough depth to deserve direct linking from the GitHub repo, RubyGems, and Vagrant registry pages
- a dedicated page will age better as you add versions, notes, screenshots, and links
- a generic tools page is still worth having later, but it should link out to dedicated project pages rather than trying to be the only place each project lives

If your main site currently has only Perminator, the cleanest move is:

1. keep Perminator as its own page
2. add a dedicated `vagrant-provider-avf` page beside it
3. later, if you end up with more projects, add an `Open Source` index page that links to both

That gives you the best of both worlds:

- a clear landing page now
- room for a project index later

## Suggested Page Title

`vagrant-provider-avf`

## Suggested URL Slug

`/vagrant-provider-avf/`

## Suggested Meta Description

`vagrant-provider-avf is a Vagrant provider for Apple Silicon Macs using Apple Virtualization.framework, with ARM64 Linux support for Ubuntu, AlmaLinux, and Rocky Linux.`

## Suggested Page Structure

1. short one-paragraph overview
2. quick install
3. supported guests
4. example `Vagrantfile`
5. links to GitHub, RubyGems, and the box registry

## Suggested Page Copy

`vagrant-provider-avf` is a Vagrant provider for Apple Silicon Macs using Apple’s `Virtualization.framework`.

It is built for ARM64 Linux workflows on macOS, with support today for:

- Ubuntu 24.04.4
- AlmaLinux 9
- Rocky Linux 9

The current release focuses on the basics done well:

- `vagrant up`
- `vagrant halt`
- `vagrant destroy`
- `vagrant ssh`
- localhost SSH forwarding
- Linux shared folders through AVF `virtiofs`

## Quick Install

Install the plugin:

`vagrant plugin install vagrant-provider-avf`

Add a box:

`vagrant box add sodini-io/ubuntu-24.04-arm64 --provider avf --box-version 0.1.0`

Bring it up:

`vagrant up --provider avf`

## Minimal Example

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

## Links

- GitHub: [https://github.com/sodini-io/vagrant-provider-avf](https://github.com/sodini-io/vagrant-provider-avf)
- Issues: [https://github.com/sodini-io/vagrant-provider-avf/issues](https://github.com/sodini-io/vagrant-provider-avf/issues)
- RubyGems: `vagrant-provider-avf`
- Vagrant box example: `sodini-io/ubuntu-24.04-arm64`

## Short Version For A Future Open Source Index

`vagrant-provider-avf` is a Vagrant provider for Apple Silicon Macs built on Apple `Virtualization.framework`. It supports ARM64 Linux workflows for Ubuntu, AlmaLinux, and Rocky Linux with lifecycle support, localhost SSH access, and Linux shared folders.
