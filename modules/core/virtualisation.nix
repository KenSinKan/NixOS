{ pkgs, lib, ... }:
{
  # Only enable either docker or podman -- Not both
  virtualisation = {
    spiceUSBRedirection.enable = true;
    # oci-containers = {
    # backend = "podman";
    #   containers = {
    #     ms-sql = {
    #       image = "mcr.microsoft.com/mssql/server:2025-latest";
    #       ports = [ "1433:1433" ];
    #       environment = {
    #         ACCEPT_EULA = "Y";
    #         MSSQL_SA_PASSWORD = "YourStrong@Password123"; # MSSQL требует сложный пароль (минимум 8 символов)
    #       };
    #       volumes = [
    #         "mssql_data:/var/opt/mssql"
    #       ];
    # };
    # };
    # };

    docker = {
      enable = false;
    };

    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;
      };
      hooks.qemu = {
        "passthrough" = lib.getExe (
          pkgs.writeShellApplication {
            name = "qemu-hook";

            runtimeInputs = with pkgs; [
              libvirt
              systemd
              kmod
            ];

            text = ''
              GUEST_NAME="$1"
              OPERATION="$2"

              if [ "$GUEST_NAME" != "win11-passthrough" ]; then
                exit 0;
              fi

              if [ "$OPERATION" == "prepare" ]; then
                systemctl stop display-manager.service
                modprobe -r -a nvidia_drm nvidia_uvm nvidia_modeset nvidia
                virsh nodedev-detach pci_0000_01_00_0
                modprobe vfio-pci
              fi

              if [ "$OPERATION" == "release" ]; then
                virsh nodedev-reattach pci_0000_01_00_0
                modprobe -a nvidia nvidia_modeset nvidia_uvm nvidia_drm
                systemctl start display-manager.service
              fi
            '';
          }
        );
      };
    };

    virtualbox.host = {
      enable = false;
      enableExtensionPack = true;
    };
  };

  services = {
    qemuGuest.enable = true;
    spice-vdagentd.enable = true;
    spice-webdavd.enable = true;
  };

  programs = {
    virt-manager.enable = true;
  };

  environment.systemPackages = with pkgs; [
    virt-viewer # View Virtual Machines
    spice
    spice-gtk
    spice-protocol
    spice-vdagent
    virtio-win
    win-spice

    # lazydocker
    # docker-client
  ];
}
