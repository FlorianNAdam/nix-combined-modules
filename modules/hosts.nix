{
  inputs,
  lib,
  config,
  ...
}@args:
let
  inherit (lib) mkOption types;

  mkModuleOption =
    description:
    mkOption {
      type = types.deferredModule;
      default = { };
      inherit description;
    };

  combinedModule =
    { ... }:
    {
      options = {
        nixos = mkModuleOption "NixOS configurations";
        home = mkModuleOption "home-manager configurations";
        nixpkgs = mkModuleOption "nixpkgs configurations";
      };
    };

  util = rec {
    toModuleList =
      path: val:
      let
        handlers = [
          {
            pred = lib.isString;
            func = stringToModuleList;
          }
          {
            pred = lib.isList;
            func = listToModuleList;
          }
          {
            pred = lib.isAttrs;
            func = attrsToModuleList;
          }
          {
            pred = lib.isPath;
            func = pathToModuleList;
          }
          {
            pred = lib.isFunction;
            func = functionToModuleList;
          }
        ];
      in
      let
        matched = lib.lists.findFirst (h: h.pred val) null handlers;
      in
      if matched != null then matched.func path val else throw "Invalid module list entry: ${val}";

    stringToModuleList =
      path: val:
      let
        modules = (parentModules path val);
      in
      if modules == [ ] then throw "No module ${path}/${val} found" else modules;

    parentModules =
      path: val:
      let
        parents = parentPaths val;
        paths = builtins.map (p: "${path}${p}") parents;
        modules = builtins.map (p: addModules p) paths;
      in
      lib.lists.flatten modules;

    parentPaths =
      path:
      let
        segments = lib.strings.splitString "/" path;

        cleanSegments = lib.lists.filter (s: s != "") segments;

        cumulativePaths = lib.lists.foldl (
          acc: seg:
          let
            prev = if acc == [ ] then "" else lib.lists.last acc;
            newPath = if prev == "" then "/${seg}" else "${prev}/${seg}";
          in
          acc ++ [ newPath ]
        ) [ ] cleanSegments;
      in
      cumulativePaths;

    pathToModuleList = _: val: [ val ];

    functionToModuleList = _: val: [ val ];

    listToModuleList = path: val: builtins.concatMap (toModuleList path) val;

    attrsToModuleList =
      path: val:
      lib.lists.flatten (
        lib.attrsets.mapAttrsToList (
          name: value:
          let
            newPath = "${path}/${name}";
          in
          (toModuleList newPath value) ++ (addModules newPath)
        ) val
      );

    addModules =
      path:
      lib.lists.flatten [
        (addNameModule path)
        (addDefaultModule path)
      ];

    addNameModule = path: existingPathOrEmpty "${path}.nix";

    addDefaultModule = path: existingPathOrEmpty "${path}/default.nix";

    existingPathOrEmpty = path: if builtins.pathExists path then [ path ] else [ ];

    mkModuleList =
      path: val:
      if builtins.isPath path then
        toModuleList path val
      else
        throw "Expected module root to be a path: ${path}";
  };

  hostType = types.submoduleWith {
    specialArgs = {
      inherit inputs;
    }
    // config.specialArgs
    // {
      hosts = config.hosts;
      inherit (util) mkModuleList;
    };

    shorthandOnlyDefinesConfig = true;

    modules = [
      (
        { name, config, ... }:
        {
          options = {
            name = mkOption {
              type = types.str;
              default = "";
              description = ''
                The name of the host, as specified in the attribute set. Use this to
                target per-host behavior. Generally you should not set this yourself;
                it will be set automatically when you define the host.
              '';
            };
            kind = mkOption {
              type = types.enum [
                "nixos"
                "home-manager"
              ];
              default = "nixos";
              description = lib.mdDoc ''
                The type of host this is. Two options:

                * `nixos`: A NixOS system configuration. Generates NixOS with
                  home-manager installed.
                * `home-manager`: A home-manager configuration. Generates only the
                  home-manager configuration for the host.
              '';
            };
            system = mkOption {
              type = types.str;
              description = lib.mdDoc ''
                The system that this host runs on. This is used to initialize
                `nixpkgs`.
              '';
            };

            nix-config = mkModuleOption ''
              additional configurations for nix-config-modules.

              Use this to add additional custom apps or customize apps
              on a per-host basis.
            '';

            nixpkgs = mkModuleOption "nixpkgs configurations";
            nixos = mkModuleOption "NixOS configurations";
            home = mkModuleOption "home-manager configurations";

            username = mkOption {
              type = types.str;
              default = "user";
              description = ''
                The username of the single user for this system.
              '';
            };
            email = mkOption {
              type = types.str;
              default = "";
              description = ''
                The email for the single user.
              '';
            };
            homeDirectory = mkOption {
              type = types.path;
              default = "/home/${config.username}";
              description = lib.mdDoc ''
                The path to the home directory for this user. Defaults to
                `/home/<username>`
              '';
            };

            modules = mkOption {
              type = types.listOf types.deferredModule;
              default = [ ];
              description = ''
                Additional combined modules to import for this host.
              '';
            };

            _internal.moduleFragments = mkOption {
              type = types.submodule {
                options = {
                  nixos = mkModuleOption "NixOS configurations extracted from combined modules";
                  home = mkModuleOption "home-manager configurations extracted from combined modules";
                  nixpkgs = mkModuleOption "nixpkgs configurations extracted from combined modules";
                };
              };
              internal = true;
            };
            _internal.moduleArgs = mkOption {
              type = types.raw;
              internal = true;
              description = ''
                Shared module arguments passed to nixos, home-manager, nixpkgs,
                and combined modules for this host.
              '';
            };
            _internal.extraSpecialArgs = mkOption {
              type = types.raw;
              internal = true;
              description = ''
                Shared module arguments safe to pass as home-manager
                extraSpecialArgs.
              '';
            };

            stateVersion = mkOption {
              type = types.str;
              description = ''
                State version used for both the NixOS and home-manager configuration.
              '';
            };

          };

          config =
            let
              host = builtins.removeAttrs config [
                "_internal"
                "nix-config"
              ];
              moduleArgs = {
                inherit inputs;
              }
              // args.config.specialArgs
              // {
                hosts = args.config.hosts;
                inherit host;
                inherit (util) mkModuleList;
              };
              moduleFragments =
                (lib.evalModules {
                  modules = [ combinedModule ] ++ args.config.modules ++ config.modules;
                  specialArgs = moduleArgs;
                }).config;
            in
            {
              inherit name;
              _internal.moduleArgs = moduleArgs;
              _internal.extraSpecialArgs = builtins.removeAttrs moduleArgs [
                "config"
                "lib"
                "options"
                "pkgs"
              ];
              _internal.moduleFragments = {
                inherit (moduleFragments) nixos home nixpkgs;
              };
            };
        }
      )
    ];
  };
in
{
  options = {
    hosts = mkOption {
      type = types.attrsOf hostType;
      default = { };
      description = ''
        Individual NixOS/home-manager configurations for individual machines or
        classes of machines.

        Each host initializes a separate copy of `nixpkgs` and has its own
        initialization of `nixosConfigurations` and `homeConfigurations`
        depending on its type.
      '';
      example = ''
        hosts.odin = {
          # specifies that this builds the entire NixOS
          kind = "nixos";
          # specifies the system to build for
          system = "x86_64-linux";
        };
      '';
    };

    nixpkgs = mkModuleOption "Global nixpkgs configurations";
    nixos = mkModuleOption "Global NixOS configurations";
    home = mkModuleOption "Global home-manager configurations";

    specialArgs = mkOption {
      type = types.raw;
      default = { };
      description = ''
        Additional arguments passed to host, NixOS, home-manager, nixpkgs, and combined modules.
      '';
    };
  };
}
