{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    nix-config = lib.mkOption {
      description = "Custom configuration containing NixOS and Home options";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            nixos = lib.mkOption {
              type = lib.types.attrs;
              description = "NixOS-specific configuration options";
            };
            home = lib.mkOption {
              type = lib.types.attrs;
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

  config = lib.mkMerge [
    lib.evalModules
    {
      modules = [
        config.nix-config.nixos
      ];
    }
  ];
}
