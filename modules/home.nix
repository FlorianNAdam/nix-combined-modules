{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkOption
    types
    ;

  hostSubmodule = types.submodule (
    { config, ... }:
    {
      options._internal.homeModules = mkOption {
        type = types.listOf types.deferredModule;
        description = ''
          Internal list of home-manager modules passed to the host.

          Don't override this unless you absolutely know what you're doing. Prefer
          using `host.<name>.home` instead.
        '';
      };
      config._internal.homeModules =
        let
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
        in
        [ config.home ] ++ [ config._internal.moduleFragments.home ] ++ [ homeCoreModule ];
    }
  );

  homeHosts = config.hosts;
in
{
  options = {
    hosts = mkOption {
      type = types.attrsOf hostSubmodule;
    };

    homeConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = ''
        Home configurations. Instantiated by home-manager build.
      '';
    };
  };

  config = {
    homeConfigurations = mapAttrs (
      _: host:
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = host._internal.pkgs;
        extraSpecialArgs = host._internal.extraSpecialArgs;
        modules = builtins.addErrorContext "while importing home-manager definitions" host._internal.homeModules;
      }
    ) homeHosts;
  };
}
