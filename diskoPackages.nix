{
  config,
  inputs,
  lib,
}:
let
  flakeRef = inputs.self.outPath or inputs.self;

  mkDiskoPackage =
    system: packages:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      mkDiskoWrapper =
        name:
        let
          scriptName = "disko-${lib.replaceStrings [ "." ] [ "-" ] name}";
        in
        pkgs.writeShellScriptBin scriptName ''
          exec ${packages.disko}/bin/disko --flake "${flakeRef}#${name}" "$@"
        '';

      diskoWrappers = lib.mapAttrs (
        hostName: host:
        (mkDiskoWrapper hostName).overrideAttrs (old: {
          passthru =
            (old.passthru or { })
            // lib.mapAttrs' (
              diskoName: _: lib.nameValuePair diskoName (mkDiskoWrapper "${hostName}.${diskoName}")
            ) host.disko;
        })
      ) (lib.filterAttrs (_: host: host.disko != { }) config.nix-config.hosts);
    in
    packages.disko.overrideAttrs (old: {
      passthru = (old.passthru or { }) // diskoWrappers;
    });

  mkDiskoPackages = system: packages: {
    disko = lib.mkDefault (mkDiskoPackage system packages);
  };
in
lib.mkIf (inputs ? disko) (lib.mapAttrs mkDiskoPackages inputs.disko.packages)
