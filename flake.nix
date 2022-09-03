{
  description = "Matrix group messaging app (nightly version)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    fenix = {
      url = github:nix-community/fenix;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    libadwaita-src = {
      url = "git+https://gitlab.gnome.org/GNOME/libadwaita.git?ref=main&tag=1.2.beta";
      flake = false;
    };

    fractal-src = {
      url = "git+https://gitlab.gnome.org/GNOME/fractal.git?ref=main";
      flake = false;
    };
  };


  outputs = { self, nixpkgs, fenix, libadwaita-src, fractal-src }:
    let
      version = builtins.substring 0 8 fractal-src.lastModifiedDate;

      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in
    {
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
              hash = "sha256-CJD9YmL06ELR3X/gIrsVCpDyJnWPbH/JF4HlXvWjiZ8=";
            };

            nativeBuildInputs = [
              appstream-glib
              desktop-file-utils
              fenix-channel.cargo
              fenix-channel.rustc
              glib
              gtk4
              meson
              ninja
              pkg-config
              rustPlatform.bindgenHook
              rustPlatform.cargoSetupHook
              wrapGAppsHook4
            ];

            buildInputs = with gst_all_1; [
              (libadwaita.overrideAttrs (old: { version = "1.2.beta"; src = libadwaita-src; }))
              glib
              gst-plugins-bad
              gst-plugins-base
              gstreamer
              gtk4
              gtksourceview5
              libsecret
              libshumate
              openssl
              pipewire
            ];

            meta = with lib; {
              description = "Matrix group messaging app (nightly version)";
              homepage = "https://gitlab.gnome.org/GNOME/fractal";
              license = licenses.gpl3Plus;
              maintainers = with maintainers; [ yureien ];
            };
          };
        };

      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) fractal;
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.fractal);
    };
}
