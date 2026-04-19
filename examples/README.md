# Example Vagrantfiles

These examples show the supported `vagrant-provider-avf` surface today.

They are intentionally small and Linux-only.

## Included Examples

- [examples/ubuntu-minimal/Vagrantfile](/Users/jim/Code/vagrant-provider-avf/examples/ubuntu-minimal/Vagrantfile): minimal supported Ubuntu box
- [examples/almalinux/Vagrantfile](/Users/jim/Code/vagrant-provider-avf/examples/almalinux/Vagrantfile): AlmaLinux disk-boot box with the supported `disk_gb = 12` floor
- [examples/rocky/Vagrantfile](/Users/jim/Code/vagrant-provider-avf/examples/rocky/Vagrantfile): Rocky Linux disk-boot box with the supported `disk_gb = 12` floor
- [examples/shared-folders/Vagrantfile](/Users/jim/Code/vagrant-provider-avf/examples/shared-folders/Vagrantfile): resource tuning plus the Linux virtiofs synced-folder path

## Notes

- all examples assume the local box was already added with `vagrant box add`
- all examples target Apple Silicon macOS with the `avf` provider
- synced folders are supported for Linux guests only
- the shared-folder example uses `type: :avf_virtiofs`, which is the only explicit synced-folder type this provider supports today
