# NixOS Dockur Windows Module

A standalone NixOS module that provides a containerized Windows VM running inside Podman via QEMU/KVM acceleration. It leverages the excellent [dockur/windows](https://github.com/dockur/windows) image.

This approach brings the philosophy of DHH's Omarchy environment to NixOS—an opinionated, seamless developer workflow without the bloat. 

<!-- INSERT_SCREENSHOT: "A screenshot showing a Windows 11 session running seamlessly within FreeRDP on a Linux desktop environment." -->

## Features

- **Zero Rebuild Overhead**: Uses runtime Podman OCI image fetching (`ghcr.io/dockur/windows:latest`). Disk images and Windows ISOs are cached in container volumes outside the Nix store, adding zero extra build time to `nixos-rebuild switch`.
- **On-Demand Activation**: The VM container is configured with `autoStart = false`. It does not consume RAM or CPU resources on boot until explicitly invoked.
- **Hardware Acceleration**: Automatic `/dev/kvm` passthrough for native-like performance.
- **Non-Interactive RDP**: Includes `/cert:ignore` in `xfreerdp` invocations. Backgrounded sessions open without terminal passphrase or certificate acceptance prompts.
- **Shared Host Directory**: Automatically mounts a host folder into the Windows VM.

<!-- INSERT_VIDEO: "A short screen recording demonstrating the `windows-vm launch` command, showing the terminal output and the FreeRDP window appearing." -->

## Installation

It is highly recommended to **fork this repository** first so you have full control over any custom configuration or updates. Once forked, replace `jjamesmartiin` with your GitHub username in the paths below.

Alternatively, you can pull directly from this repository by using `jjamesmartiin` in the URLs.

You can install this module using either a Flake or a traditional Nix channel setup.

### Flake Setup

Add the repository to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dockur-windows = {
      # Replace `jjamesmartiin` with your GitHub username if you forked the repository
      url = "github:jjamesmartiin/nixos-dockur-windows";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, dockur-windows, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        dockur-windows.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### Non-Flake Setup

If you are not using flakes, you can fetch the tarball directly in your `configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [
    # Replace `jjamesmartiin` with your GitHub username if you forked the repository
    (import (builtins.fetchTarball "https://github.com/jjamesmartiin/nixos-dockur-windows/archive/main.tar.gz"))
  ];
}
```

## Configuration

Enable the module and configure your preferred settings in `configuration.nix`. 

```nix
{ config, ... }:

{
  virtualisation.dockur-windows = {
    enable = true;
    
    # Absolute path on the host to map as /storage inside Windows
    # We recommend setting this to a directory inside your user's home folder.
    sharedFolder = "/home/yourusername/Windows";
    
    ramSize = "8G";
    cpuCores = "4";
    windowsVersion = "win11";
  };
}
```

### Available Options

- `virtualisation.dockur-windows.enable`: Enables the module (default: `false`).
- `virtualisation.dockur-windows.containerName`: Podman container name (default: `"windows-vm"`).
- `virtualisation.dockur-windows.cliCommandName`: Name of the generated CLI tool (default: `"windows-vm"`).
- `virtualisation.dockur-windows.sharedFolder`: Absolute host path mapped to `/storage` (default: `"/var/lib/dockur-windows"`).
- `virtualisation.dockur-windows.ramSize`: Allocated RAM (default: `"8G"`).
- `virtualisation.dockur-windows.cpuCores`: Allocated CPU cores (default: `"4"`).
- `virtualisation.dockur-windows.windowsVersion`: Windows image version (default: `"win11"`).
- `virtualisation.dockur-windows.webPort`: Port mapped to container web interface (default: `8006`).
- `virtualisation.dockur-windows.rdpPort`: Port mapped to RDP service (default: `3390`).
- `virtualisation.dockur-windows.sshPort`: Port mapped to SSH service (default: `2222`).

## Usage

Once applied, the module provides a CLI helper script (default name: `windows-vm`) for managing the lifecycle of your VM.

- **`windows-vm launch`**: Starts the Windows VM container and immediately connects via FreeRDP.
- **`windows-vm stop`**: Gracefully stops the Windows VM container.
- **`windows-vm status`**: Checks the status of the underlying Podman container.
- **`windows-vm restart`**: Restarts the VM container.
- **`windows-vm web`**: Opens the web-based VNC installation interface in your default browser at `http://127.0.0.1:8006`.

<!-- INSERT_SCREENSHOT: "A screenshot showing the output of `windows-vm status` or `windows-vm --help` in a terminal." -->
