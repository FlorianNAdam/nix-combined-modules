{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.nix-config;
in
{
  imports = [ ];

  options = {
    nixos2 = mkOption {
      type = types.anything;
      default = { }; # Ensure a valid default
    };

    home = mkOption {
      type = types.anything;
      default = { };
    };
  };

  config = mkMerge [
    config.nixos2
  ];
}
