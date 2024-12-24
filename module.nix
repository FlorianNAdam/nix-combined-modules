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
    # Pass nix-config.nixos to the top-level as part of module arguments
    _module = {
      args.nixosConfig = config.nix-config.nixos;
    };

    # Use the passed argument (avoiding recursion)
    imports = [
      ({ nixosConfig, ... }: nixosConfig)
    ];
  };
}
