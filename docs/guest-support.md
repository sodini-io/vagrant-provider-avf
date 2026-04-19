# Guest Support

This repo is Linux-focused today.

## Current Matrix

| Guest | Box pipeline | `up` / `halt` / `destroy` | `ssh_info` / `vagrant ssh` | Synced folders | Release status |
| --- | --- | --- | --- | --- | --- |
| Ubuntu 24.04.4 ARM64 | yes | yes | yes | yes | supported |
| AlmaLinux 9 ARM64 | yes | yes | yes | yes | supported |
| Rocky Linux 9 ARM64 | yes | yes | yes | yes | supported |

## What Supported Means Here

A guest path is only supported when all of these are true:

- the image and box pipeline are documented and reproducible
- `vagrant up`, `vagrant halt`, and `vagrant destroy` are green through the real provider boundary
- `provider.ssh_info` is honest and `vagrant ssh` is reliable
- the path has a real Apple Silicon acceptance workflow
- the path is ready to publish without caveats

Ubuntu, AlmaLinux, and Rocky Linux clear that bar today.

## What Is Out For Now

BSD guests are not part of the active support matrix right now.
That is deliberate, not accidental: the repo is focusing on a clean Linux story first instead of carrying half-supported guest branches.

OpenBSD may be worth revisiting later because recent upstream progress suggests it is the most promising BSD candidate on Apple virtualization, but it is not implemented here yet.

## Small Additions Worth Considering

Worth doing when they solve a real user problem without widening the runtime surface:

- more example Vagrantfiles
- more Linux-only acceptance coverage when a supported feature lacks a provider-boundary spec
- small CI wrappers like the supported Linux matrix runner

Still intentionally deferred because they widen the support surface more than they help right now:

- snapshots
- bridged networking
- alternate network modes
- user-configurable fixed SSH ports
- new guest families

## Release Bar

The publish wrapper follows the same support bar:

- Ubuntu, AlmaLinux, and Rocky Linux are publishable by default
- unknown guest families stay blocked until they have a documented workflow and are added deliberately

The current enterprise Linux follow-on notes are in [docs/enterprise-linux.md](/Users/jim/Code/vagrant-provider-avf/docs/enterprise-linux.md).
