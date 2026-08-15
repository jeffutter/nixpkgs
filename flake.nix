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
    iio-ambient-brightness = {
      url = "github:jeffutter/iio_ambient_brightness/v0.2.17";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-tail = {
      url = "github:jeffutter/claude-tail/v0.2.4";
    };

    herdr = {
      url = "github:ogulcancelik/herdr/v0.8.0";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Intentionally NOT following nixpkgs: numtide builds and caches these
    # packages (agent-browser, pi, rtk) against their own pinned nixpkgs.
    # Making them follow our nixpkgs changes the derivation hashes, so they
    # miss numtide's binary cache and rebuild locally -- agent-browser's
    # pnpm-deps step in particular gets OOM-killed. Using numtide's pin makes
    # these pure cache downloads.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-options-search = {
      url = "github:madsbv/nix-options-search";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tinted-theming-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };

    # Vale prose linting styles
    vale-proselint = {
      url = "github:vale-cli/proselint/v0.3.4";
      flake = false;
    };
    vale-write-good = {
      url = "github:vale-cli/write-good/v0.4.1";
      flake = false;
    };
    vale-alex = {
      url = "github:vale-cli/alex/v0.2.3";
      flake = false;
    };

    stop-slop = {
      url = "github:hardikpandya/stop-slop";
      flake = false;
    };

    humanizer = {
      url = "github:blader/humanizer";
      flake = false;
    };

    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    apollo_skills = {
      url = "github:apollographql/skills";
      flake = false;
    };

    ast-grep-skill = {
      url = "github:ast-grep/agent-skill";
      flake = false;
    };

    matt-pocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    excalidraw-diagram-skill = {
      url = "github:coleam00/excalidraw-diagram-skill";
      flake = false;
    };

    # Fish plugins
    fish-plugin-fenv = {
      url = "github:oh-my-fish/plugin-foreign-env/7f0cf099ae1e1e4ab38f46350ed6757d54471de7";
      flake = false;
    };

    fish-plugin-autopair = {
      url = "github:jorgebucaran/autopair.fish/1.0.4";
      flake = false;
    };

    the-elements-of-style = {
      url = "github:obra/the-elements-of-style";
      flake = false;
    };

    backlog-md = {
      url = "github:MrLesk/Backlog.md";
    };

    kami = {
      url = "github:tw93/kami";
      flake = false;
    };

    screenpipe-src = {
      url = "github:screenpipe/screenpipe";
      flake = false;
    };

    # Source for the worktrunk plugin's Claude Code skill/hook assets, not
    # installed as a Claude plugin -- see modules/home/languages/ai.nix.
    worktrunk-plugin = {
      url = "github:max-sixty/worktrunk";
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
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      # allowUnfree here (not just in the home/nixos configs' own pkgs) so
      # unfree packages exposed via the `packages` output -- e.g. moshi-hook,
      # consumed externally by the colmena repo's hermes-agent VM -- build
      # standalone without every consumer needing its own override.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    let
      nixpkgsConfig = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
        permittedInsecurePackages = [ "p7zip-16.02" ];
      };

      claudeCodeOverlay =
        final: prev:
        let
          claudeCodeVersion = "2.1.228";
          claudeCodeBaseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
          # Run `nix-prefetch-url <url>` for your platform to get the correct hash
          # URL format: ${claudeCodeBaseUrl}/${claudeCodeVersion}/<platform>/claude
          # Platforms: darwin-arm64, darwin-x64, linux-arm64, linux-x64
          claudeCodeChecksums = {
            "darwin-arm64" = "sha256-Q0hLE1LO8DoING827wQ3dVsarWRquTE84YeFe3lLckc=";
            "darwin-x64" = "sha256-eFLxrg77ZNRtd6V9iFLa3cSm/7WK7aYme9PzQorcCbM=";
            "linux-arm64" = "sha256-JmQAYhlJe/cCGsQxVlGc1C7aZM6ypm9DTsq4Pngx+UI=";
            "linux-x64" = "sha256-1TWYXmlBo+sAF5zNf1LOsMZiOgMFpRjrxOZRT4SpTJk=";
          };
          platformKey = "${final.stdenv.hostPlatform.parsed.kernel.name}-${
            if final.stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
          }";
        in
        {
          claude-code = prev.claude-code.overrideAttrs (oldAttrs: {
            version = claudeCodeVersion;
            src = final.fetchurl {
              url = "${claudeCodeBaseUrl}/${claudeCodeVersion}/${platformKey}/claude";
              hash = claudeCodeChecksums.${platformKey};
            };
          });
        };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config = nixpkgsConfig;
          overlays = [
            claudeCodeOverlay
          ];
        };

      # Every host in this flake has the same shape: pkgs pinned through
      # mkPkgs, `inputs` threaded into specialArgs, stylix at both the system
      # and home level, and home-manager importing common.nix + the platform
      # module + the host's own home.nix. mkSystem holds that shape so the
      # per-host entries below carry only what actually differs.
      #
      # `platform` supplies the NixOS/darwin differences; see mkNixos/mkDarwin.
      mkSystem =
        platform:
        {
          system,
          username,
          host,
          extraModules ? [ ],
        }:
        platform.builder {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.pkgs = mkPkgs system; }
            ./hosts/${host}/default.nix
          ]
          ++ extraModules
          ++ [
            platform.stylixModule
            platform.homeManagerModule
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = platform.useUserPackages;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.sharedModules = [ inputs.stylix.homeModules.stylix ];
              home-manager.users.${username} = {
                imports = [
                  ./modules/home/common.nix
                  platform.homeModule
                  ./hosts/${host}/home.nix
                ];
              };
            }
          ];
        };

      mkNixos = mkSystem {
        builder = nixpkgs.lib.nixosSystem;
        stylixModule = inputs.stylix.nixosModules.stylix;
        homeManagerModule = home-manager.nixosModules.home-manager;
        homeModule = ./modules/home/linux.nix;
        useUserPackages = true;
      };

      mkDarwin = mkSystem {
        builder = nix-darwin.lib.darwinSystem;
        stylixModule = inputs.stylix.darwinModules.stylix;
        homeManagerModule = home-manager.darwinModules.home-manager;
        homeModule = ./modules/home/darwin.nix;
        # Keep packages in ~/.nix-profile/bin/
        useUserPackages = false;
      };

      mkHome =
        {
          system,
          username,
          homeDirectory,
          extraModules ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = { inherit inputs; };
          modules = [
            inputs.stylix.homeModules.stylix
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
        zenbook = mkNixos {
          system = "x86_64-linux";
          username = "jeffutter";
          host = "zenbook";
          extraModules = [
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-gpu-intel
          ];
        };

        workstation = mkNixos {
          system = "x86_64-linux";
          username = "jeffutter";
          host = "workstation";
        };
      };

      darwinConfigurations = {
        work = mkDarwin {
          system = "aarch64-darwin";
          username = "jeffery.utter";
          host = "work";
        };

        personal = mkDarwin {
          system = "aarch64-darwin";
          username = "jeffutter";
          host = "personal";
        };

        mbp16 = mkDarwin {
          system = "aarch64-darwin";
          username = "jeffutter";
          host = "mbp16";
        };
      };

      packages = forAllSystems (system: {
        actual-cli = (pkgsFor system).callPackage ./pkgs/actual-cli { };
        screenpipe = (pkgsFor system).callPackage ./pkgs/screenpipe { src = inputs.screenpipe-src; };
        colgrep = (pkgsFor system).callPackage ./pkgs/colgrep { };
        datadog-pup = (pkgsFor system).callPackage ./pkgs/datadog-pup { };
        moshi-hook = (pkgsFor system).callPackage ./pkgs/moshi-hook { };
      });

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

        "jeffutter@mbp16" = mkHome {
          system = "aarch64-darwin";
          username = "jeffutter";
          homeDirectory = "/Users/jeffutter";
          extraModules = [
            ./modules/home/darwin.nix
            ./hosts/mbp16/home.nix
          ];
        };
      };
    };
}
