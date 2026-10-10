{
  description = "A flake for mtplayer - Media player for public German/AT/CH broadcasters";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      # Using modernized package names to remove deprecation warnings
      runtimeLibs = with pkgs; [
        libx11
        libxext
        libxi
        libxrender
        libxtst
        libxxf86vm
        glib
        gtk3
        cairo
        pango
        gdk-pixbuf
        atk
        alsa-lib
        libGL
        freetype
        fontconfig
        libxkbcommon
      ];
    in {
      packages.${system} = rec {
        mtplayer = pkgs.stdenv.mkDerivation rec {
          pname = "mtplayer";
          version = "21__2026.01.23";

          src = pkgs.fetchurl {
            url = "https://www.p2tools.de/download/mtplayer/act/MTPlayer-${version}.zip";
            hash = "sha256-Dyu6ee/rS/RC2k3VUkdBtP6qMnvn6tiax751zDkDEu8="; 
          };

          nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];
          buildInputs = [ pkgs.temurin-bin-17 pkgs.vlc pkgs.ffmpeg ] ++ runtimeLibs;

          unpackPhase = ''
            unzip $src -d source
            cd source
          '';

          installPhase = ''
            mkdir -p $out/share/mtplayer
            cp -r * $out/share/mtplayer/

            # Correctly escaping the Bash variables below using double-dollars or backslashes
            JAR_PATH=$(find $out/share/mtplayer -iname "mtplayer.jar" | head -n 1)

            if [ -z "$JAR_PATH" ]; then
              echo "Error: Could not find MTPlayer.jar inside the archive!"
              exit 1
            fi

            mkdir -p $out/bin
            
            # The wrapper injects both the binaries (PATH) and the GUI components (LD_LIBRARY_PATH)
            makeWrapper ${pkgs.temurin-bin-17}/bin/java $out/bin/mtplayer \
              --add-flags "-jar $JAR_PATH" \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.vlc pkgs.ffmpeg ]} \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs}

            mkdir -p $out/share/applications
            cat <<EOF > $out/share/applications/mtplayer.desktop
            [Desktop Entry]
            Name=MTPlayer
            Comment=Access to Mediathek of public tv stations
            Exec=$out/bin/mtplayer
            Icon=video-player
            Type=Application
            Categories=AudioVideo;Player;
            EOF
          '';
        };

        default = mtplayer;
      };
    };
}
