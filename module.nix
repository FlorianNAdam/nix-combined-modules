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
    # Use dynamic imports to include the nixos configuration
    imports =
      let
        nixosConfig = config.nix-config.nixos;
      in
      [
        # Dynamically pass the nixos configuration as an inline module
        ({ ... }: nixosConfig)
      ];
  };
}
