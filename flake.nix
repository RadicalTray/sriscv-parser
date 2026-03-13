{
  description = "";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls = {
      url = "github:zigtools/zls/0.15.x";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-overlay.follows = "zig-overlay";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      lib = inputs.nixpkgs.lib;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSupportedSystem =
        f:
        lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
            };
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              inputs.zig-overlay.packages.${pkgs.stdenv.hostPlatform.system}."0.15.2"
              inputs.zls.packages.${pkgs.stdenv.hostPlatform.system}.default
            ];

            inputsFrom = with pkgs; [
            ];
          };
        }
      );
    };
}
