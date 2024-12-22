{
  config,
  lib,
  inputs,
  flake-parts-lib,
  ...
}:
let

  inherit (lib)
    mkOption
    types
    ;
  inherit (flake-parts-lib)
    mkSubmoduleOptions
    ;

  knownOptions = [
    "exampleOption1"
    "exampleOption2"
  ]; # List your known options here
  allOptions = lib.attrNames config.myModule; # Retrieve all options provided in the `myModule` namespace
  unknownOptions = lib.filter (opt: !(lib.elem opt knownOptions)) allOptions;

in
{
  options = {
    # compatibility layer for home-manager
    flake.homeConfigurations = mkOption {
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

  # config = {
  #   flake = {
  #     homeConfigurations = config.nix-config.homeConfigurations;
  #     nixosConfigurations = config.nix-config.nixosConfigurations;
  #   };
  # };

  config = lib.mkIf (!lib.isEmpty unknownOptions) (
    throw (
      lib.concatStringsSep ", " [
        "Unknown options: "
        (lib.concatStringsSep ", " unknownOptions)
      ]
    )
  );

}
