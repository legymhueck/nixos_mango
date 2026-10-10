{
  description = "BiBox Westermann Linux client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    version = "3.0.4";

    src = pkgs.fetchurl {
      name = "BiBox-${version}.deb";
      url = "https://static.bibox2.westermann.de/electron/autoUpdate/BiBox%203.0.4.deb";
      hash = "sha256-nrmi+pgQfJFY2qLrDPLlUY9TeH21ihTR0xAXYhCKw14=";
    };

    runtimeLibs = with pkgs; [
      gtk3
      pango
      libx11
      libxrandr
      libsecret
      nss
      nspr
      libgbm
      stdenv.cc.cc.lib
      glib
      atk
      at-spi2-atk
      at-spi2-core
      cups
      dbus
      expat
      fontconfig
      freetype
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrender
      libxtst
      libuuid
      libxcb
      libxshmfence
      alsa-lib
      libdrm
      cairo
      libxkbcommon
      gdk-pixbuf
      systemd
      libGL
      libva
    ];

  in
  {
    packages.${system} = rec {
      bibox = pkgs.stdenv.mkDerivation {
        pname = "bibox";
        inherit version src;

        nativeBuildInputs = with pkgs; [
          dpkg
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = runtimeLibs;

        unpackPhase = ''
          runHook preUnpack

          dpkg-deb -x "$src" .

          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
        
          mkdir -p "$out/opt/bibox"
        
          if [ -d "opt/BiBox 2.0" ]; then
            cp -a "opt/BiBox 2.0/." "$out/opt/bibox/"
          elif [ -d "opt/bibox" ]; then
            cp -a "opt/bibox/." "$out/opt/bibox/"
          else
            cp -a opt/* "$out/opt/bibox/"
          fi
        
          mkdir -p "$out/bin"
          mkdir -p "$out/libexec/bibox"
        
          cat > "$out/libexec/bibox/xdg-open" <<EOF
        #!${pkgs.runtimeShell}
        unset LD_LIBRARY_PATH
        exec ${pkgs.xdg-utils}/bin/xdg-open "\$@"
        EOF
        
          chmod 755 "$out/libexec/bibox/xdg-open"
        
          makeWrapper "$out/opt/bibox/bibox" "$out/bin/bibox" \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}" \
            --prefix PATH : "$out/libexec/bibox:${pkgs.lib.makeBinPath [ pkgs.inetutils pkgs.xdg-utils pkgs.glib ]}" \
            --set APPIMAGE "$out/opt/bibox/bibox"
        
          if [ -f usr/share/applications/bibox.desktop ]; then
            install -Dm644 usr/share/applications/bibox.desktop \
              "$out/share/applications/bibox.desktop"
        
            sed -i "s|Exec=\"/opt/BiBox 2.0/bibox\" %U|Exec=$out/bin/bibox %U|g" \
              "$out/share/applications/bibox.desktop"
        
            sed -i "s|Exec=\"/opt/bibox/bibox\" %U|Exec=$out/bin/bibox %U|g" \
              "$out/share/applications/bibox.desktop"
        
            sed -i "s|Icon=/usr/share/icons/hicolor/0x0/apps/bibox2.png|Icon=bibox|g" \
              "$out/share/applications/bibox.desktop"
          fi
        
          if [ -f usr/share/icons/hicolor/0x0/apps/bibox.png ]; then
            install -Dm644 usr/share/icons/hicolor/0x0/apps/bibox.png \
              "$out/share/icons/hicolor/512x512/apps/bibox.png"
          fi
        
          runHook postInstall
        '';
        
        meta = with pkgs.lib; {
          description = "Official client for Westermann textbooks";
          homepage = "https://www.bibox.schule";
          license = licenses.unfree;
          platforms = [ "x86_64-linux" ];
          mainProgram = "bibox";
        };
      };

      default = bibox;
    };

    apps.${system}.default = {
      type = "app";
      program = "${self.packages.${system}.bibox}/bin/bibox";
      meta = {
        description = "Run BiBox Westermann Linux client";
      };
    };
  };
}
