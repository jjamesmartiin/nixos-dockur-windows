{
  description = "A NixOS module for running Dockur Windows VMs seamlessly via Podman/QEMU";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules = {
      dockur-windows = import ./module.nix;
      default = self.nixosModules.dockur-windows;
    };
  };
}
