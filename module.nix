{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.asus-zenbook-a14-firmware;
in
{
  options.hardware.asus-zenbook-a14-firmware.enable =
    lib.mkEnableOption "firmware for the ASUS Zenbook A14 (UX3407QA) extracted from ASUS' Windows drivers";

  config = lib.mkIf cfg.enable {
    # Listed first so these take precedence over linux-firmware's older WCN6855 files.
    hardware.firmware = lib.mkBefore [ (pkgs.callPackage ./package.nix { }) ];
    nixpkgs.config.allowUnfreePredicate =
      pkg: (lib.getName pkg) == "asus-zenbook-a14-firmware";
  };
}
