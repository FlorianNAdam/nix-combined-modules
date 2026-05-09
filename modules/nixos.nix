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
  outer_config = config;

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
          nixosCoreModule =
            { host, ... }:
            {
              imports = [
                inputs.home-manager.nixosModules.default
              ];

              nix = {
                registry = {
                  nixpkgs.flake = inputs.nixpkgs;
                };

                settings = {
                  trusted-users = [
                    "root"
                    host.username
                  ];
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                };
              };

              users.users.${host.username} = {
                isNormalUser = true;
                home = host.homeDirectory;
                group = host.username;
                description = host.username;

                extraGroups = [
                  "wheel"
                  "input"
                ];
              };
              users.groups.${host.username} = { };

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = config._internal.extraSpecialArgs;
                users.${host.username} = {
                  imports = config._internal.homeModules;
                };
              };

              system.stateVersion = config.stateVersion;
            };
          moduleFragments = config._internal.moduleFragments;
        in
        {
          _internal.nixosModules = [
            outer_config.nixos
            config.nixos
            moduleFragments.nixos
            nixosCoreModule
            { _module.args = config._internal.moduleArgs; }
          ];
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
      imports = host._internal.nixosModules;
    }
  ) nixosHosts;
}
