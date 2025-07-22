# Configuration to add to /home/mark/etc/nixos/modules/hosts/king.nix
# Add this networking.hosts section to your existing king.nix file

{
  # Web server hosts configuration
  networking.hosts = {
    "127.0.0.1" = [ "localhost" "dashboard.local" "phpmyadmin.local" "sample1.local" "sample2.local" "sample3.local" ];
    "127.0.0.2" = [ "king" ];
  };
}