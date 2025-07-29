# Default.nix for easy installation
{ pkgs ? import <nixpkgs> {} }:

pkgs.callPackage ./package.nix {}
