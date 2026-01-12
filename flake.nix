{
  description = "jeffutter's NixOS and home-manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    expert = {
      url = "github:elixir-lang/expert";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zenbook-specific flakes
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    iio-ambient-brightness = {
      url = "github:jeffutter/iio_ambient_brightness/v0.2.16";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tokyonight = {
      url = "github:folke/tokyonight.nvim";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      nixos-hardware,
      nixvim,
      expert,
      ...
    }@inputs:
    let
      mkHome =
        {
          system,
          username,
          homeDirectory,
          extraModules ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            config.input-fonts.acceptLicense = true;
            config.permittedInsecurePackages = [ "p7zip-16.02" ];
          };
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./modules/home/common.nix
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        zenbook = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/zenbook/default.nix
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-gpu-intel
            home-manager.nixosModules.home-manager
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.input-fonts.acceptLicense = true;
              nixpkgs.config.permittedInsecurePackages = [ "p7zip-16.02" ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.jeffutter = {
                imports = [
                  ./modules/home/common.nix
                  ./modules/home/linux.nix
                  ./hosts/zenbook/home.nix
                ];
              };
            }
          ];
        };

        workstation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/workstation/default.nix
            home-manager.nixosModules.home-manager
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.input-fonts.acceptLicense = true;
              nixpkgs.config.permittedInsecurePackages = [ "p7zip-16.02" ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.jeffutter = {
                imports = [
                  ./modules/home/common.nix
                  ./modules/home/linux.nix
                  ./hosts/workstation/home.nix
                ];
              };
            }
          ];
        };
      };

      darwinConfigurations = {
        work = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/work/default.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.input-fonts.acceptLicense = true;
              nixpkgs.config.permittedInsecurePackages = [ "p7zip-16.02" ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = false; # Keep packages in ~/.nix-profile/bin/
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users."jeffery.utter" = {
                imports = [
                  ./modules/home/common.nix
                  ./modules/home/darwin.nix
                  ./hosts/work/home.nix
                ];
              };
            }
          ];
        };

        personal = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/personal/default.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.input-fonts.acceptLicense = true;
              nixpkgs.config.permittedInsecurePackages = [ "p7zip-16.02" ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = false; # Keep packages in ~/.nix-profile/bin/
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.jeffutter = {
                imports = [
                  ./modules/home/common.nix
                  ./modules/home/darwin.nix
                  ./hosts/personal/home.nix
                ];
              };
            }
          ];
        };
      };

      homeConfigurations = {
        "jeffutter@personal" = mkHome {
          system = "aarch64-darwin";
          username = "jeffutter";
          homeDirectory = "/Users/jeffutter";
          extraModules = [
            ./modules/home/darwin.nix
            ./hosts/personal/home.nix
          ];
        };

        "jeffery.utter@work" = mkHome {
          system = "aarch64-darwin";
          username = "jeffery.utter";
          homeDirectory = "/Users/Jeffery.Utter";
          extraModules = [
            ./modules/home/darwin.nix
            ./hosts/work/home.nix
          ];
        };
      };
    };
}
