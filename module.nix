{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.dockur-windows;
  
  # CLI helper script matching the Omarchy/dockur workflow
  windowsVmScript = pkgs.writeShellScriptBin cfg.cliCommandName ''
    set -e

    function show_help() {
      echo "Usage: ${cfg.cliCommandName} {launch|stop|status|restart|web}"
      echo ""
      echo "  launch  - Start Windows VM container and open RDP session"
      echo "  stop    - Stop Windows VM container"
      echo "  status  - Check status of Windows VM container"
      echo "  restart - Restart Windows VM container"
      echo "  web     - Open web-based VNC installation interface in browser (http://127.0.0.1:${toString cfg.webPort})"
      exit 0
    }

    ACTION="''${1:-launch}"

    case "$ACTION" in
      launch|start)
        echo "Starting Windows VM container (${cfg.containerName})..."
        mkdir -p "${cfg.sharedFolder}"
        sudo systemctl start podman-${cfg.containerName}.service || sudo podman start ${cfg.containerName} || true

        echo "Waiting for Windows VM RDP endpoint (127.0.0.1:${toString cfg.rdpPort})..."
        for i in {1..30}; do
          if ${pkgs.netcat-openbsd}/bin/nc -z 127.0.0.1 ${toString cfg.rdpPort} 2>/dev/null; then
            echo "RDP endpoint ready!"
            break
          fi
          sleep 2
        done

        echo "Launching RDP session..."
        ${pkgs.freerdp}/bin/xfreerdp /v:127.0.0.1:${toString cfg.rdpPort} /u:docker /p:"" /cert:ignore /dynamic-resolution /sound /clipboard +home-drive &
        ;;

      stop)
        echo "Stopping Windows VM container..."
        sudo systemctl stop podman-${cfg.containerName}.service || sudo podman stop ${cfg.containerName}
        echo "Windows VM stopped."
        ;;

      status)
        sudo podman ps -a --filter name=${cfg.containerName}
        ;;

      restart)
        echo "Restarting Windows VM..."
        sudo systemctl restart podman-${cfg.containerName}.service
        ;;

      web)
        echo "Starting Windows VM container (${cfg.containerName}) if needed..."
        mkdir -p "${cfg.sharedFolder}"
        sudo systemctl start podman-${cfg.containerName}.service || sudo podman start ${cfg.containerName} || true

        echo "Waiting for Web interface (127.0.0.1:${toString cfg.webPort})..."
        for i in {1..30}; do
          if ${pkgs.netcat-openbsd}/bin/nc -z 127.0.0.1 ${toString cfg.webPort} 2>/dev/null; then
            echo "Web interface ready!"
            break
          fi
          sleep 2
        done

        echo "Opening web interface at http://127.0.0.1:${toString cfg.webPort}..."
        ${pkgs.xdg-utils}/bin/xdg-open "http://127.0.0.1:${toString cfg.webPort}"
        ;;

      *)
        show_help
        ;;
    esac
  '';

in {
  options.virtualisation.dockur-windows = {
    enable = mkEnableOption "the Dockur Windows VM via Podman/QEMU";

    containerName = mkOption {
      type = types.str;
      default = "windows-vm";
      description = "The name of the Podman container.";
    };

    cliCommandName = mkOption {
      type = types.str;
      default = "windows-vm";
      description = "The name of the CLI helper script installed in your environment.";
    };

    sharedFolder = mkOption {
      type = types.str;
      default = "/var/lib/dockur-windows";
      description = "The absolute path of the host directory to map into the VM as /storage. It is highly recommended to set this to a path within your user directory, like /home/username/Windows.";
    };

    ramSize = mkOption {
      type = types.str;
      default = "8G";
      description = "Amount of RAM to allocate to the VM.";
    };

    cpuCores = mkOption {
      type = types.str;
      default = "4";
      description = "Number of CPU cores to allocate to the VM.";
    };

    windowsVersion = mkOption {
      type = types.str;
      default = "win11";
      description = "Windows edition to install (e.g., win11, win10, win7).";
    };

    webPort = mkOption {
      type = types.port;
      default = 8006;
      description = "Host port to map to the container's web installation GUI.";
    };

    rdpPort = mkOption {
      type = types.port;
      default = 3390;
      description = "Host port to map to the container's RDP service (mapped to 3390 by default to avoid host xrdp conflicts).";
    };

    sshPort = mkOption {
      type = types.port;
      default = 2222;
      description = "Host port to map to the container's SSH service.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.${cfg.containerName} = {
      image = "ghcr.io/dockur/windows:latest";
      autoStart = false; # Do not consume resources on boot; launch on demand
      ports = [
        "${toString cfg.webPort}:8006"
        "${toString cfg.rdpPort}:3389"
        "${toString cfg.sshPort}:22"
      ];
      volumes = [
        "${cfg.sharedFolder}:/storage"
      ];
      environment = {
        RAM_SIZE = cfg.ramSize;
        CPU_CORES = cfg.cpuCores;
        VERSION = cfg.windowsVersion;
        MANUAL = "N";
      };
      extraOptions = [
        "--device=/dev/kvm:/dev/kvm"
        "--device=/dev/net/tun:/dev/net/tun"
        "--cap-add=NET_ADMIN"
        "--sysctl=net.ipv4.ip_forward=1"
      ];
    };

    environment.systemPackages = [
      windowsVmScript
      pkgs.freerdp
      pkgs.remmina
      pkgs.netcat-openbsd
    ];
  };
}
