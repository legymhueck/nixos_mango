{
  description = "Hylki – a fast, GNOME-native email client (Rust + libadwaita)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream source, tracked via flake.lock. Update with:
    #   nix flake update hylki-src
    # Pin a release instead with e.g. "github:hyprlab/hylki/v1.42.0".
    hylki-src = {
      url = "github:hyprlab/hylki";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, hylki-src }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      mkHylki =
        pkgs:
        let
          cargoToml = builtins.fromTOML (builtins.readFile "${hylki-src}/Cargo.toml");
        in
        pkgs.rustPlatform.buildRustPackage {
          pname = "hylki";
          version = cargoToml.package.version;

          src = hylki-src;

          cargoLock.lockFile = "${hylki-src}/Cargo.lock";

          nativeBuildInputs = with pkgs; [
            pkg-config
            glib # glib-compile-resources, used by build.rs (glib-build-tools)
            gettext # msgfmt for .desktop file and translations
            wrapGAppsHook4
          ];

          buildInputs = with pkgs; [
            gtk4
            libadwaita
            webkitgtk_6_0
            poppler # poppler-glib
            cairo
            pango
            gdk-pixbuf
            glib
            openssl
            dbus
            wayland
            gettext
            adwaita-icon-theme
            glib-networking # TLS for WebKit
            gsettings-desktop-schemas
          ];

          # Tests expect a display / session bus.
          doCheck = false;

          postInstall = ''
            appid=co.hyprlab.Hylki

            # Icons
            for size in 256x256 512x512; do
              install -Dm644 data/icons/hicolor/$size/apps/$appid.png \
                $out/share/icons/hicolor/$size/apps/$appid.png
            done
            install -Dm644 data/icons/hicolor/scalable/apps/$appid.svg \
              $out/share/icons/hicolor/scalable/apps/$appid.svg
            install -Dm644 data/icons/hicolor/symbolic/apps/$appid-symbolic.svg \
              $out/share/icons/hicolor/symbolic/apps/$appid-symbolic.svg

            # Desktop entry (with translations merged in)
            install -d $out/share/applications
            msgfmt --desktop --template=data/$appid.desktop -d po \
              -o $out/share/applications/$appid.desktop

            # Translations
            for po in po/*.po; do
              [ -e "$po" ] || continue
              lang=$(basename "$po" .po)
              install -d $out/share/locale/$lang/LC_MESSAGES
              msgfmt -o $out/share/locale/$lang/LC_MESSAGES/hylki.mo "$po"
            done
          '';

          # gnupg is used for OpenPGP sign/encrypt/decrypt.
          preFixup = ''
            gappsWrapperArgs+=(
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.gnupg ]}
            )
          '';

          meta = {
            description = "Fast, GNOME-native email client built with Rust and libadwaita";
            homepage = "https://hylki.hyprlab.co";
            license = pkgs.lib.licenses.agpl3Plus;
            mainProgram = "hylki";
            platforms = systems;
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hylki = mkHylki pkgs;
        in
        {
          inherit hylki;
          default = hylki;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.hylki}/bin/hylki";
        };
      });

      overlays.default = final: _prev: { hylki = mkHylki final; };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.hylki ];
            packages = with pkgs; [
              cargo
              rustc
              rust-analyzer
              clippy
              rustfmt
              gnupg
            ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
