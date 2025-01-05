# nix-combined-modules

A fairly opinionated nixos configuration framework.\
The goal of nix-combined-modules is to simplify the creation of multi-host, modular configurations, without a strict separation of nixos and home manager modules


## <a name="nix-config-modules"></a>nix-config-modules

This project is based on a fork of the fantastic [nix-config-modules](https://github.com/chadac/nix-config-modules) by [chadac](https://github.com/chadac). Thanks for the great work!\
Without that project I would not have known where to even begin. 

The approach of nix-config-modules is very different, being based on defining apps and tags.\
Befor commiting to using nix-combined-modules, please check out if nix-config-modules might suit you better.\

## Getting started

Similar to [nix-config-modules](#nix-config-modules), this is intended to be used with  [flake-parts](https://flake.parts).\
If you really want to avoid flake-parts for some reason, this is described in "[avoiding flake-parts](#avoiding_flake-parts)" further down.

A modular sample config may look like this:

<pre>
.
├── flake.nix
├── hosts
│   └── my-host
│       ├── default.nix
│       └── hardware-config.nix
└── modules
    └── example.nix
</pre>

**flake.nix**
```nix
{
  description =  "Nix system configuration with nix-combined-modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nix-combined-modules = {
      url = "github:FlorianNAdam/nix-combined-modules";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nix-combined-modules.flakeModule
      ];

      systems = [ ];

      nix-config = {
        specialArgs = {
          inherit inputs;
        };

        modules = [
          # <... global modules ...> 
        ]; 

        hosts = import ./hosts/my-host      
      };
    };
}
```

**hosts/my-host/default.nix**

```nix
{
  kind = "nixos";
  system = "x86_64-linux";

  username = "florian";

  modules = [
    ../../modules/example.nix
  ];
  
  nixos =
    { host, pkgs, ... }:
    {
      imports = [
        ./hardware-configuration.nix
      ];

       # <... host specific nixos config ...>
    };

  home =
    { lib, ... }:
    {
     # <... host specific nixos config ...>
    };

  stateVersion = "24.05";
}
```

**modules/example.nix**
```nix
{
  nixos = {pkgs, ...}: {
    home.packages = with pkgs; [
      firefox
    ];
  };

  home = {
     programs.alacritty = {
      enable = true;
    };
  };

  nixpkgs = {
    packages.unfree = [
      "steam"
      "steam-unwrapped"
    ];
  };
}
```

This will create a Flake, with some more or less random predefined defaults 
for a single user with home-manager enabled.

## Usage

### Creating modules

Modules are configurations that combine NixOS, home-manager and nixpkgs configurations.\
These modules are structured as follows:

```nix 
{inputs, ...}: # optional specialArgs
{
  nixos = 
  {pkgs, lib, config, ...}: # optional module args. 
  {
    # <... regular nixos config ...>
  };

  home = 
  {pkgs, lib, config, ...}: # optional module args
  {
    # <... regular home-manager config ...>
  };

  nixpkgs = 
  { pkgs, lib, config, ...}: # optional module args
  {
    packages = { # permit packages by name
      unfree = [ "..." ]; 
      insecure = [ "..."];
      nonSource = [ "..." ];
    }

    params = {
      overlays = [ ... ]; # add overlays
    
      config = {
        # <... regular nixpkgs config ...>
      };
    };
  };
}
```
A valid, empty module would simply be: `{}` 

### Importing Modules

Modules can be imported globally, by adding them to `nix-config`, such as this:
```nix
nix-config = {
  modules = [
    <path-to-module>.nix

    # <...>
  ];

  # <...>
};
```

or to a single host, like this:
```nix
host.my-host = {
  modules = [
    <path-to-module>.nix
    
    # <...>
  ];

  # <...>
};
```
To avoid writing out every path, we can use some nix features.
For example:
```nix
modules = [
  ../../modules/example1.nix
  ../../modules/example2.nix
  ../../modules/exmaple3.nix
  # <...>
];
```
can be written as:
```nix
modules =
  let
    modulesDir = ../../modules;
    modules = [
      "example1"
      "example2"
      "exmaple3"
      # <...>
    ];
  in
    map (name: "${modulesDir}/${name}.nix") modules;
```

### <a name="specialArgs"></a>Accessing inputs / specialArgs

Similar to ```lib.nixosSystem```, ```specialArgs```, can be used to pass arguments to modules.\
The most common use case for this is propagating ```inputs```, in order to access packages or modules defined by flakes.
For example: 

```nix
nix-config = {
  specialArgs = {
    inherit inputs;
  };

  <...>
};
```

These can then be used in any module:
```nix 
{inputs, ...}: # optional specialArgs
{
  nixos = {
    imports = [
      inputs.stylix.nixosModules.stylix
    ];
  }; 
  
  home = <...>
  
  nixpkgs = <...>
}
```



### Adding out-of-tree packages

Custom packages, that aren't part nixpkgs, or exported by a flake, can be added as follows:\
1. Extend the file tree:
<pre>
.
├── flake.nix
├── hosts
│   └── my-host
│       ├── default.nix
│       └── hardware-config.nix
├── modules
│   └── example.nix
└── pkgs
    ├── default.nix
    └── example.nix    <- the custom package
</pre>
2. Add a **pkgs/default.nix** file:
```nix
{ pkgs, ... }:
{
  # add any packages here
  example = pkgs.callPackage ./example.nix { };
  <...>
}
```
3. Add the pkgs to the specialArgs:
```nix
nix-config = {
  specialArgs = {
    custom-pkgs = import ./pkgs;
  };

  <...>
};
```
4. Use the packages in modules:
```nix
{custom-pkgs, ...}:
{
  nixos = {
    environment.systemPackages = [
      custom-pkgs.example
    ];
  };
};
```

## Importing existing configurations

The easiest way to migrate to nix-combined-modules is by simply importing an existing configuration and then turning everything into modules piece-by-piece. (Or just leaving it as is. You do you).\
Existing configurations can be imported from any module.\

A complete, minimal example for a flake importing an existing configuration might look like this:
```nix
{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-combined-modules.url = "github:FlorianNAdam/nix-combined-modules";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nix-combined-modules.flakeModule
      ];

      systems = [ ];

      nix-config = {
        hosts = {
          my-host = {
            kind = "nixos";
            system = "x86_64-linux";

            username = "florian";

            nixos = {
              imports = [ 
                ./configuration.nix
                ./hardware-configuration.nix
              ];
            };

            home = {
              imports = [
                ./home.nix
              ];
            };

            stateVersion = "24.05";
          };       
        };
      };
    };
}
```
If you were using packages or modules exported by flakes, you will probably need to add [specialArgs](#specialArgs).


## <a name="avoiding_flake-parts"></a>Avoiding flake-parts

It is *technically* possible to avoid using flake-parts.\
This does involve adding a lot of boilerplate code though:

```nix
  outputs =
    {
      self,
      nixpkgs,
      nix-combined-modules,
      ...
    }@inputs:
    with nixpkgs.lib;
    let
      config-module = {
        nix-config = {
          # <... add your regular config here ...> 
        };
      };

      extractor-module =
        { config, host, ... }:
        {
          options = {
            flake = mkOption {
              type = types.submodule {
                options = {
                  nixosConfigurations = mkOption {
                    type = types.raw;
                  };
                  homeConfigurations = mkOption {
                    type = types.raw;
                  };
                };
              };
            };
          };
        };
    in
    (evalModules {
      modules = [
        config-module
        extractor-module
        nix-combined-modules.flakeModule
      ];
    }).config.flake;
```

If you have found a more elegant way of doing this, feel free to update this example!
