{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

{
  options = {
    nix-config = mkOption {
      description = "Custom configuration containing NixOS and Home options";
      type = types.attrsOf (
        types.submodule {
          options = {
            nixos = mkOption {
              type = types.deferredModule;
              description = "NixOS-specific configuration options";
            };
            home = mkOption {
              type = types.attrs;
              description = "Home Manager-specific configuration options";
            };
          };
        }
      );
      default = {
        nixos = { };
        home = { };
      };
    };
  };

  config = mkMerge [
    # Add `nix-config.nixos` directly into the configuration tree
    (config.nix-config.nixos or { })
  ];
}
