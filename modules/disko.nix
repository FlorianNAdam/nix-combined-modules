{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    attrValues
    filterAttrs
    mapAttrs
    mkOption
    nameValuePair
    types
    ;

  hostsWithDisko = filterAttrs (_: host: host.disko != { }) config.hosts;

  diskoNixosModule =
    if inputs ? disko then
      inputs.disko.nixosModules.disko
    else
      throw ''
        nix-config uses host disko configurations in NixOS, but inputs.disko is missing.
        Add inputs.disko.url = "github:nix-community/disko".
      '';

  diskoLib =
    if inputs ? disko then
      inputs.disko.lib
    else
      throw ''
        nix-config uses host disko configurations, but inputs.disko is missing.
        Add inputs.disko.url = "github:nix-community/disko".
      '';

  evalDiskoModules =
    host: diskoModules:
    (lib.evalModules {
      modules = [
        {
          options.disko.devices = mkOption {
            type = diskoLib.toplevel;
            default = { };
          };
        }
        { _module.args = host._internal.moduleArgs; }
      ]
      ++ diskoModules;
      specialArgs = host._internal.moduleArgs;
    }).config;

  evalDiskoModule = host: diskoModule: evalDiskoModules host [ diskoModule ];

  fullDiskoConfigurations = mapAttrs (
    _: host: evalDiskoModules host (attrValues host.disko)
  ) hostsWithDisko;

  namedDiskoConfigurations = lib.concatMapAttrs (
    hostName: host:
    lib.mapAttrs' (
      diskoName: diskoModule: nameValuePair "${hostName}.${diskoName}" (evalDiskoModule host diskoModule)
    ) host.disko
  ) hostsWithDisko;

  diskoConfigurations = fullDiskoConfigurations // namedDiskoConfigurations;
in
{
  options = {
    hosts = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options = {
              disko = mkOption {
                type = types.attrsOf types.deferredModule;
                default = { };
                description = ''
                  Named disko configurations for this host.

                  Each attribute is imported into the generated NixOS configuration
                  and exported as `diskoConfigurations."<host>.<name>"`. All named
                  entries are also merged into `diskoConfigurations.<host>` for
                  full-host disko runs.
                '';
              };

              _internal.diskoNixosModules = mkOption {
                type = types.listOf types.deferredModule;
                internal = true;
              };
            };

            config._internal.diskoNixosModules =
              if config.disko == { } then [ ] else [ diskoNixosModule ] ++ attrValues config.disko;
          }
        )
      );
    };

    diskoConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = ''
        Exported disko configurations. Each host with disko entries gets a full
        `<host>` configuration and one `<host>.<name>` configuration per named entry.
      '';
    };
  };

  config = {
    inherit diskoConfigurations;
  };
}
