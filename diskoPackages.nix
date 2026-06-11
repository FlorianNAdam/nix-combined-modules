{
  config,
  inputs,
  lib,
}:
let
  flakeRef = inputs.self.outPath or inputs.self;
  diskoHosts = lib.filterAttrs (_: host: host.disko != { }) config.nix-config.hosts;

  scriptName = name: lib.replaceStrings [ "." ] [ "-" ] name;

  mkDiskoWrapper =
    pkgs: disko: name:
    let
      name' = scriptName name;
    in
    pkgs.writeShellScriptBin "disko-${name'}" ''
      exec ${disko}/bin/disko --flake "${flakeRef}#${name}" "$@"
    '';

  mkDiskoInstallWrapper =
    pkgs: disko-install: hostName:
    let
      name' = scriptName hostName;
    in
    pkgs.writeShellScriptBin "disko-install-${name'}" ''
      exec ${disko-install}/bin/disko-install --flake "${flakeRef}#${hostName}" "$@"
    '';

  mkDiskoPackage =
    system: packages:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      makeDiskoWrapper = mkDiskoWrapper pkgs packages.disko;

      diskoWrappers = lib.mapAttrs (
        hostName: host:
        (makeDiskoWrapper hostName).overrideAttrs (old: {
          passthru =
            (old.passthru or { })
            // lib.mapAttrs' (
              diskoName: _: lib.nameValuePair diskoName (makeDiskoWrapper "${hostName}.${diskoName}")
            ) host.disko;
        })
      ) diskoHosts;
    in
    packages.disko.overrideAttrs (old: {
      passthru = (old.passthru or { }) // diskoWrappers;
    });

  mkDiskoInstallPackage =
    system: packages:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      makeDiskoInstallWrapper = mkDiskoInstallWrapper pkgs packages.disko-install;
    in
    packages.disko-install.overrideAttrs (old: {
      passthru =
        (old.passthru or { }) // lib.mapAttrs (hostName: _: makeDiskoInstallWrapper hostName) diskoHosts;
    });

in
lib.mkIf (inputs ? disko) (
  lib.mapAttrs (
    system: packages:
    {
      disko = lib.mkDefault (mkDiskoPackage system packages);
    }
    // lib.optionalAttrs (packages ? disko-install) {
      disko-install = lib.mkDefault (mkDiskoInstallPackage system packages);
    }
  ) inputs.disko.packages
)
