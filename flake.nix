{
  description = "Firmware for the ASUS Zenbook A14 (UX3407QA, X1P42100) extracted from ASUS' Windows drivers";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    {
      overlays.default = final: _: {
        asus-zenbook-a14-firmware = final.callPackage ./package.nix { };
      };
      nixosModules.default = ./module.nix;
      packages.aarch64-linux.default = nixpkgs.legacyPackages.aarch64-linux.callPackage ./package.nix { };
    };
}
