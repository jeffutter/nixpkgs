{ pkgs, inputs, ... }:
let
  iab = inputs.iio-ambient-brightness.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.swayidle = {
    enable = true;
    extraArgs = [ "-d" ];
    events = {
      before-sleep = "${pkgs.hyprlock}/bin/hyprlock";
      lock = "${pkgs.hyprlock}/bin/hyprlock";
    };
    timeouts = [
      {
        timeout = 60;
        # Inhibit ambient brightness daemon so it does not fight the dim at 110s
        command = "${iab}/bin/iio_ambient_brightness -i";
        resumeCommand = "${iab}/bin/iio_ambient_brightness -a";
      }
      {
        timeout = 110;
        # Save current brightness with -s so -r on resume restores the exact level
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10%";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      {
        timeout = 120;
        command = "${pkgs.hyprlock}/bin/hyprlock";
      }
      {
        timeout = 300;
        command = "[ \"$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/AC0/online)\" = \"0\" ] && ${pkgs.systemd}/bin/systemctl suspend";
      }
      {
        timeout = 180;
        command = "if ${pkgs.procps}/bin/pgrep -x hyprlock; then ${pkgs.sway}/bin/swaymsg \"output * power off\"; fi";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
      }
    ];
  };
}
