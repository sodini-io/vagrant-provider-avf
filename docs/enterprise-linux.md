# Enterprise Linux Notes

This repo now supports AlmaLinux 9 and Rocky Linux 9.

This note captures the current state of the enterprise Linux work so we can keep adding it deliberately instead of opportunistically.

Verified against the official project sources on April 18, 2026.

## Recommendation

If we add another enterprise Linux guest next, add it only after both AlmaLinux 9 and Rocky Linux 9 stay green.

Why:

- AlmaLinux publishes official Generic Cloud `aarch64` images with `cloud-init`.
- the current AlmaLinux 9 repository listing includes both the normal Generic Cloud `aarch64` image and an `ext4` variant, which fit the provider's current disk-boot Linux path well enough to build the first supported enterprise Linux box.
- Rocky Linux also publishes official Generic Cloud `aarch64` images, and the current Rocky 9 `aarch64` listing exposes a `Base` qcow2 image that fits the provider's current disk-boot Linux path.

That last point is an inference from the current official repository listings, not a claim that Rocky cannot work.

## What The Current Provider Already Has

The provider already has the pieces needed for a narrow enterprise Linux slice:

- Linux EFI disk boot
- provider-generated NoCloud seed disks for disk-boot Linux guests
- NAT plus localhost SSH forwarding
- honest `ssh_info`
- Linux shared directories through virtiofs
- a box packager that already supports disk-only Linux boxes
- a green AlmaLinux 9 real acceptance path through `scripts/ci-almalinux-acceptance`
- a green Rocky Linux 9 real acceptance path through `scripts/ci-rocky-acceptance`

## What Is Still Missing

The current Ubuntu workflow is still curated and does not use this generic disk-boot path at runtime.

The AlmaLinux and Rocky Linux slices are now in place:

1. package one curated enterprise Linux box around an official Generic Cloud image
2. prove `up`, `ssh`, `halt`, `destroy`, and shared directories through a real Apple Silicon acceptance workflow
3. add it to the release matrix once the acceptance path is green

That work is complete for both AlmaLinux and Rocky Linux.

## Suggested Order

1. keep AlmaLinux 9 and Rocky Linux 9 green in real acceptance
2. only consider another enterprise Linux distro after both stay stable

## Official Sources

- AlmaLinux Generic Cloud image docs: [wiki.almalinux.org/cloud/Generic-cloud.html](https://wiki.almalinux.org/cloud/Generic-cloud.html)
- AlmaLinux 9 `aarch64` cloud image repository: [repo.almalinux.org/almalinux/9/cloud/aarch64/images/](https://repo.almalinux.org/almalinux/9/cloud/aarch64/images/)
- Rocky Linux image policy: [wiki.rockylinux.org/rocky/image/](https://wiki.rockylinux.org/rocky/image/)
- Rocky Linux 9 `aarch64` image repository: [dl.rockylinux.org/pub/rocky/9/images/aarch64/](https://dl.rockylinux.org/pub/rocky/9/images/aarch64/)
