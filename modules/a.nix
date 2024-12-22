{ lib, config, ... }:
let
  cfg = config.myModule;
in
{
  options = {
    myModule.enable = lib.mkEnableOption "Enable Module";
  };

  config = lib.mkIf cfg.enable {
    #config contents
    test = builtins.trace "hi";
  };
}
