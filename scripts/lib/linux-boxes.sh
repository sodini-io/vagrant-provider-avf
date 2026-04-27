#!/usr/bin/env bash

linux_supported_families() {
  printf 'ubuntu\nalmalinux\nrocky\n'
}

linux_assert_supported_family() {
  local family="$1"

  case "${family}" in
    ubuntu|almalinux|rocky) ;;
    *)
      echo "unsupported linux family: ${family}" >&2
      return 1
      ;;
  esac
}

linux_slug_for_family() {
  local family="$1"

  linux_assert_supported_family "${family}" || return 1

  case "${family}" in
    ubuntu) printf 'ubuntu-24.04-arm64\n' ;;
    almalinux) printf 'almalinux-9-arm64\n' ;;
    rocky) printf 'rocky-9-arm64\n' ;;
  esac
}

linux_box_name() {
  local family="$1"

  printf 'avf/%s\n' "$(linux_slug_for_family "${family}")"
}

linux_cloud_box_name() {
  local organization="$1"
  local family="$2"

  printf '%s/%s\n' "${organization}" "$(linux_slug_for_family "${family}")"
}

linux_default_disk_gb_for_box() {
  local box_name="$1"

  case "${box_name}" in
    avf/almalinux-9-arm64|avf/rocky-9-arm64|*/almalinux-9-arm64|*/rocky-9-arm64)
      printf '12\n'
      ;;
    *)
      printf '8\n'
      ;;
  esac
}

linux_default_box_path() {
  local repo_root="$1"
  local family="$2"
  local version="${3:-0.1.0}"

  printf '%s/build/boxes/avf-%s-%s.box\n' "${repo_root}" "$(linux_slug_for_family "${family}")" "${version}"
}

linux_artifact_dir() {
  local repo_root="$1"
  local family="$2"

  printf '%s/build/images/%s\n' "${repo_root}" "$(linux_slug_for_family "${family}")"
}

linux_disk_image_artifact() {
  local repo_root="$1"
  local family="$2"

  printf '%s/disk.img\n' "$(linux_artifact_dir "${repo_root}" "${family}")"
}

linux_build_image_command() {
  local repo_root="$1"
  local family="$2"

  linux_assert_supported_family "${family}" || return 1

  case "${family}" in
    ubuntu) printf '%s/images/ubuntu/build-image\n' "${repo_root}" ;;
    almalinux) printf '%s/images/almalinux/build-image\n' "${repo_root}" ;;
    rocky) printf '%s/images/rocky/build-image\n' "${repo_root}" ;;
  esac
}

linux_build_box_command() {
  local repo_root="$1"
  local family="$2"

  linux_assert_supported_family "${family}" || return 1

  case "${family}" in
    ubuntu) printf '%s/scripts/build-box\n' "${repo_root}" ;;
    almalinux) printf '%s/scripts/build-almalinux-box\n' "${repo_root}" ;;
    rocky) printf '%s/scripts/build-rocky-box\n' "${repo_root}" ;;
  esac
}

linux_acceptance_spec() {
  local repo_root="$1"
  local family="$2"

  linux_assert_supported_family "${family}" || return 1

  case "${family}" in
    ubuntu) printf '%s/spec/acceptance/ubuntu_box_workflow_spec.rb\n' "${repo_root}" ;;
    almalinux) printf '%s/spec/acceptance/almalinux_box_workflow_spec.rb\n' "${repo_root}" ;;
    rocky) printf '%s/spec/acceptance/rocky_box_workflow_spec.rb\n' "${repo_root}" ;;
  esac
}
