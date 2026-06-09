{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    # compatibility layer for home-manager
    flake.homeConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };

    flake.diskoConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };

    nix-config = mkOption {
      type = types.submoduleWith {
        modules = (import ./modules/all-modules.nix) ++ [
          { _module.args.inputs = inputs; }
        ];
      };
    };
  };

  config = {
    flake = {
      diskoConfigurations = config.nix-config.diskoConfigurations;
      homeConfigurations = config.nix-config.homeConfigurations;
      nixosConfigurations = config.nix-config.nixosConfigurations;

      packages = import ./diskoPackages.nix { inherit config inputs lib; };
    };
  };
}
