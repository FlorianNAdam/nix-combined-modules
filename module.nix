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
              type = types.attrs;
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

  config = {
    # Merge the `nix-config.nixos` into the top-level configuration
    _module = {
      config = mkMerge [
        config.nix-config.nixos
      ];
    };
  };
}
