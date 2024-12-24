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
    # Dynamically add configuration by merging nix-config.nixos
    _module = {
      args = {
        nixosConfig = config.nix-config.nixos;
      };

      # Merge the `nixosConfig` directly into the configuration tree
      config = mkMerge [
        (config._module.args.nixosConfig or { })
      ];
    };
  };
}
