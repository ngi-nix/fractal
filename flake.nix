{
  description = "(insert short project description here)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    fenix = {
      url = github:nix-community/fenix;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fractal-src = {
      url = git+https://gitlab.gnome.org/GNOME/fractal.git?rev=837b56978474fe512469805844b8ee234587499a;
      flake = false;
    };
  };


  outputs = { self, nixpkgs, fenix, fractal-src }:
    let

      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 fractal-src.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in
    {
      # A Nixpkgs overlay.
      overlay = final: prev:
        let
          fenix-channel = fenix.packages.${final.system}.latest;
          fenix-toolchain = (fenix-channel.withComponents [
            "rustc"
            "cargo"
          ]);
        in
        {
          fractal = with final; stdenv.mkDerivation rec {
            name = "fractal-${version}";

            src = fractal-src;

            cargoDeps = rustPlatform.fetchCargoTarball {
              inherit src;
              hash = "sha256-2mE26ES+fYSWdfMr8uTsX2VVGTNMDQ9MXEk5E/L95UI=";
            };

            nativeBuildInputs = [
              glib
              gtk4
              meson
              ninja
              pkg-config
              rustPlatform.bindgenHook
              rustPlatform.cargoSetupHook
              fenix-channel.cargo
              fenix-channel.rustc
              desktop-file-utils
              appstream-glib
              wrapGAppsHook4
            ];

            buildInputs = with gst_all_1; [
              glib
              gstreamer
              gst-plugins-base
              gst-plugins-bad
              gtk4
              gtksourceview5
              libadwaita
              libsecret
              openssl
              pipewire
              libshumate
            ];

            meta = with lib; {
              description = "Matrix group messaging app (nightly version)";
              homepage = "https://gitlab.gnome.org/GNOME/fractal";
              license = licenses.gpl3Plus;
              maintainers = with maintainers; [ yureien ];
            };
          };
        };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) fractal;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.fractal);
    };
}
