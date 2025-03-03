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
                extraSpecialArgs = {
                  inherit host;
                };
                users.${host.username} = {
                  imports = host._internal.homeModules;
                };
              };

              system.stateVersion = config.stateVersion;
            };
          homeCoreModule =
            { host, ... }:
            {
              home = {
                username = "${host.username}";
                homeDirectory = "${host.homeDirectory}";
              };

              programs.home-manager.enable = true;

              systemd.user.startServices = "sd-switch";

              home.stateVersion = config.stateVersion;
            };
          customModule2 =
            { config, host, ... }:
            {
              options = {
                nixos = mkOption {
                  type = types.deferredModule;
                  default = { };
                };
                home = mkOption {
                  type = types.deferredModule;
                  default = { };
                };
                nixpkgs = mkOption {
                  type = types.deferredModule;
                  default = { };
                };
              };
            };
          specialArgs = outer_config.specialArgs // {
            hosts = outer_config.hosts;
          };
          customModules = (
            lib.evalModules {
              modules = [ customModule2 ] ++ config.modules;
              specialArgs = specialArgs;
            }
          );
          customNixosModules = customModules.config.nixos;
          customHomeModules = customModules.config.home;
          customNixpkgsModules = customModules.config.nixpkgs;
        in
        {
          _internal.nixosModules =
            globalNixosModules
            ++ [ config.nixos ]
            ++ [ customNixosModules ]
            ++ [ nixosCoreModule ]
            ++ [ { _module.args = specialArgs; } ];
          _internal.homeModules = [ customHomeModules ] ++ [ homeCoreModule ];
          _internal.nixPkgsModules = [ customNixpkgsModules ];
          # ++ [ { _module.args = outer_config.specialArgs; } ];
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
