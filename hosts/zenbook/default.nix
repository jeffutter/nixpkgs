# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  imports = [
    # Hardware modules are imported via flake.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./cachix.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    useOSProber = true;
    configurationLimit = 3;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;
  #boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_16;
  boot.kernelParams = [ "i915.force_probe=7d45" ];
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=1
    options iwlwifi power_level=1
    options iwlmvm power_scheme=3
  '';
  boot.initrd =
    let
      interface = "wlo1";
    in
    {
      # crypto coprocessor and wifi modules
      availableKernelModules = [
        "ccm"
        "ctr"
        "iwlmvm"
        "iwlwifi"
      ];

      compressor = "zstd";
      compressorArgs = [ "-12" ];
      extraFirmwarePaths = [ "iwlwifi-ma-b0-gf-a0-89.ucode.zst" ];

      systemd = {
        enable = true;

        packages = [ pkgs.wpa_supplicant ];
        initrdBin = [ pkgs.wpa_supplicant ];
        targets.initrd.wants = [ "wpa_supplicant@${interface}.service" ];

        # prevent WPA supplicant from requiring `sysinit.target`.
        services."wpa_supplicant@".unitConfig.DefaultDependencies = false;

        users.root.shell = "/bin/systemd-tty-ask-password-agent";

        network.enable = true;
        network.networks."10-wlan" = {
          matchConfig.Name = interface;
          networkConfig.DHCP = "yes";
        };
      };

      secrets."/etc/wpa_supplicant/wpa_supplicant-${interface}.conf" = /root/secrets/wpa_supplicant.conf;

      network.enable = true;
      network.ssh = {
        enable = true;
        port = 22;
        hostKeys = [ "/etc/ssh/ssh_host_ed25519_key" ];
        authorizedKeys = config.users.users.jeffutter.openssh.authorizedKeys.keys;
      };
    };

  networking.hostName = "zenbook";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;
  };

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = false;
    dpi = 255;
    upscaleDefaultCursor = true;
    videoDrivers = [ "modesetting" ];
  };

  services.libinput = {
    touchpad = {
      scrollMethod = "twofinger";
      naturalScrolling = true;
    };
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  programs.sway.enable = true;
  # programs.hyprland.enable = true;
  programs.ydotool.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "colemak";
      options = "ctrl:swapcaps";
    };
  };

  console.useXkbConfig = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.jeffutter = {
    isNormalUser = true;
    description = "Jeffery Utter";
    extraGroups = [
      "networkmanager"
      "wheel"
      "ydotool"
    ];
    shell = pkgs.fish;
    packages = with pkgs; [
      #  thunderbird
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdcZzshajKcShGRcADGbH2V3Dzjv+C65imbg2/B6gkh jeffery.utter" # Work
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFkj8dAsJdep7a3LWx2mETXV5OXzoPVXcPU3e3zCoUhCqmMhB8hdCwMJjLXYfbinujAe7idPwWB0BPywrVHjaQBxSSRtLVdzCMBKBCrblAig/KXF9y96crtAH/Z4lk8Xmh1hEMDFTIHrAfNgXNKQccNUB9z77jFUjJEypSksUc/2A3a0aWJWkBvALsYiYQ5vBDyGPHr6WGr3+fVNZMtWcjx3rRJHF00c48NXLOLTsqRcHYYJt4q2xzFnPCjr+r+iaUqodu30edu9KlJlO4kQZszlQCHz42o7NWSs1qglTr5FbsCZdQnUPGSLXCFsNQ1KGLxGFoMdshTEsaS8iMUSYT jeffutter" # Workstation
    ];
  };

  # home-manager is configured via flake.nix

  programs.fish.enable = true;

  # nixpkgs configuration
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.input-fonts.acceptLicense = true;
  nixpkgs.config.permittedInsecurePackages = [ "p7zip-16.02" ];

  # Install firefox.
  # programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    file
    ripgrep
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.variables = {
    GDK_SCALE = "2.2"; # default 1 I think
    GDK_DPI_SCALE = "0.4"; # default 1 I think
    _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2.2"; # default 1 I think
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    XCURSOR_SIZE = "48";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = true;
  };

  services.tailscale.enable = true;

  # Enable systemd-resolved (required for initrd network)
  services.resolved.enable = true;

  # Open ports in the firewall.
  networking.firewall = {
    allowedTCPPorts = [ 22 ];
    # Or disable the firewall altogether.
    enable = true;
  };
  # networking.firewall.allowedUDPPorts = [ ... ];

  hardware.graphics = {
    enable = true;
    # extraPackages = with pkgs; [
    #   vaapiIntel
    #   vaapiVdpau
    #   libvdpau-va-gl
    # ];
  };

  hardware.sensor.iio.enable = true;

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 80;

      #Optional helps save long term battery health
      START_CHARGE_THRESH_BAT0 = 40; # 40 and bellow it starts to charge
      STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging
    };
  };
  services.upower.enable = true;
  # systemd.sleep.extraConfig = ''
  # MemorySleepMode=deep
  # '';

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "jeffutter" ];
  };

  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        zen
        .zen-wrapped
      '';
      mode = "0755";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
