{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    modules = mkOption {
      type = types.listOf types.deferredModule;
      default = [ ];
      description = ''
        Global combined modules to add to each host.
      '';
    };
  };
}
