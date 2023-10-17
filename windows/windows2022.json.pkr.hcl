packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "autounattend" {
  type    = string
  default = "./packer-windows/answer_files/2022/Autounattend.xml"
}

variable "disk_size" {
  type    = string
  default = "61440"
}

variable "disk_type_id" {
  type    = string
  default = "1"
}

variable "headless" {
  type    = string
  default = "false"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:3e4fa6d8507b554856fc9ca6079cc402df11a8b79344871669f0251535255325"
}

variable "iso_url" {
  type    = string
  default = "https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
}

variable "manually_download_iso_from" {
  type    = string
  default = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022"
}

variable "memory" {
  type    = string
  default = "2048"
}

variable "restart_timeout" {
  type    = string
  default = "5m"
}

variable "virtio_win_iso" {
  type    = string
  default = "./virtio-win.iso"
}

variable "winrm_timeout" {
  type    = string
  default = "2h"
}

source "qemu" "autogenerated_1" {
  accelerator      = "kvm"
  boot_wait        = "0s"
  communicator     = "winrm"
  cpus             = 2
  disk_size        = "${var.disk_size}"
  floppy_files     = ["${var.autounattend}", "./packer-windows/scripts/disable-screensaver.ps1", "./packer-windows/scripts/disable-winrm.ps1", "./packer-windows/scripts/enable-winrm.ps1", "./packer-windows/scripts/microsoft-updates.bat", "./packer-windows/scripts/unattend.xml", "./packer-windows/scripts/sysprep.bat", "./packer-windows/scripts/win-updates.ps1"]
  headless         = true
  iso_checksum     = "${var.iso_checksum}"
  iso_url          = "${var.iso_url}"
  memory           = "${var.memory}"
  output_directory = "output-windows_server-2022"
  qemuargs         = [["-drive", "file=output-windows_server-2022/{{ .Name }},if=virtio,cache=writeback,discard=ignore,format=qcow2,index=1"], ["-drive", "file=${var.iso_url},media=cdrom,index=2"], ["-drive", "file=${var.virtio_win_iso},media=cdrom,index=3"]]
  shutdown_command = "a:/sysprep.bat"
  vm_name          = "packer-windows_server-2022"
  winrm_password   = "vagrant"
  winrm_timeout    = "${var.winrm_timeout}"
  winrm_username   = "vagrant"
}

build {
  sources = ["source.qemu.autogenerated_1"]

  provisioner "windows-shell" {
    execute_command = "{{ .Vars }} cmd /c \"{{ .Path }}\""
    scripts         = ["./packer-windows/scripts/enable-rdp.bat"]
  }

  provisioner "powershell" {
    scripts = ["./packer-windows/scripts/vm-guest-tools.ps1", "./packer-windows/scripts/debloat-windows.ps1"]
  }

  provisioner "windows-restart" {
    restart_timeout = "${var.restart_timeout}"
  }

  provisioner "windows-shell" {
    execute_command = "{{ .Vars }} cmd /c \"{{ .Path }}\""
    scripts         = ["./packer-windows/scripts/pin-powershell.bat", "./packer-windows/scripts/set-winrm-automatic.bat", "./packer-windows/scripts/uac-enable.bat", "./packer-windows/scripts/compile-dotnet-assemblies.bat", "./packer-windows/scripts/dis-updates.bat", "./packer-windows/scripts/compact.bat"]
  }

  post-processor "shell-local" {
    inline = [
      "SOURCE=windows_server-2022",
      "IMG_FMT=raw",
      "source ../scripts/fuse-nbd",
      "source ./post.sh",
      ]
    inline_shebang = "/bin/bash -e"
  }
  post-processor "compress" {
    output = "windows-server-2022.dd.gz"
  }
}
