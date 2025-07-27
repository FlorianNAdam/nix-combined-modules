{
  inputs,
  lib,
  config,
  ...
}@args:
let
  inherit (lib)
    filterAttrs
    mkOption
    types
    ;

  mkModuleOption =
    description:
    mkOption {
      type = types.deferredModule;
      default = { };
      inherit description;
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
        hasSuffix = lib.strings.hasSuffix;
        addSuffixIfMissing = suffix: str: if hasSuffix suffix str then str else "${str}${suffix}";
      in
      [ "${path}/${addSuffixIfMissing ".nix" val}" ];

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
          lib.lists.flatten [
            (toModuleList newPath value)
            (addAttrNameModule path name)
            (addAttrDefaultModule path name)
          ]
        ) val
      );

    addAttrNameModule =
      path: name:
      let
        modulePath = "${path}/${name}.nix";
      in
      if builtins.pathExists modulePath then [ modulePath ] else [ ];

    addAttrDefaultModule =
      path: name:
      let
        modulePath = "${path}/${name}/default.nix";
      in
      if builtins.pathExists modulePath then [ modulePath ] else [ ];

    mkModuleList =
      path: val:
      if builtins.isPath path then
        toModuleList path val
      else
        throw "Expected module root to be a path: ${path}";
  };

  hostType = types.submoduleWith {
    specialArgs = config.specialArgs // {
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
              default = null;
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
            };

            stateVersion = mkOption {
              type = types.str;
            };

          };

          config = {
            inherit name;
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

    specialArgs = mkOption {
      type = types.raw;
    };
  };
}
