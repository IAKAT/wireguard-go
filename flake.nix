{
  description = "WireGuard-Go implementation with DAITA support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in
      {
        packages = {
          default = pkgs.wireguard-go-daita;
          wireguard-go-daita = pkgs.wireguard-go-daita;
          maybenot-ffi = pkgs.maybenot-ffi;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            wireguard-go-daita
            go
            rustc
            cargo
          ];
        };
      })
    // {
      overlays.default = import ./overlay.nix;

      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.wireguard-go-daita;
        in
        {
          options.services.wireguard-go-daita = {
            enable = mkEnableOption "WireGuard-Go with DAITA support";

            package = mkOption {
              type = types.package;
              default = pkgs.wireguard-go-daita;
              description = "The wireguard-go-daita package to use";
            };
          };

          config = mkIf cfg.enable {
            nixpkgs.overlays = [ self.overlays.default ];
            environment.systemPackages = [ cfg.package ];

            # Ensure TUN/TAP support
            boot.kernelModules = [ "tun" ];
          };
        };
    };
}
