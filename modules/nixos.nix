{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkOption
    types
    ;
  globalNixosModules = config.modules.nixos;

  hostSubmodule = types.submodule (
    { config, ... }:
    {
      options._internal.nixosModules = mkOption {
        type = types.listOf types.deferredModule;
        description = ''
          List of NixOS modules used by the host.

          Don't override this unless you absolutely know what you're doing. Prefer
          using `host.<name>.nixos` instead.
        '';
      };

      config =
        let
          customModule2 =
            { config, host, ... }:
            {
              options = {
                nix-config2 = mkOption {
                  type = types.deferredModule;
                  default = [ ];
                };
              };
            };
          customModules =
            (lib.evalModules {
              modules = [ customModule2 ] ++ config.modules2;
            }).config.nix-config2;
        in
        {
          _internal.nixosModules = globalNixosModules ++ [ config.nixos ] ++ [ customModules ];
        };
    }
  );

  nixosHosts = filterAttrs (_: host: host.kind == "nixos") config.hosts;
in
{
  options = {
    hosts = mkOption { type = types.attrsOf hostSubmodule; };
    nixosConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = ''
        Exported NixOS configurations, which can be used in your flake.
      '';
    };
  };
  config.nixosConfigurations = mapAttrs (
    _: host:
    host._internal.pkgs.nixos {
      imports = host._internal.nixosModules ++ [
        { _module.args.host = host; }
      ];
    }
  ) nixosHosts;
}
