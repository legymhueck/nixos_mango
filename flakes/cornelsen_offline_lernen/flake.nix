{
  description = "A flake for Cornelsen Offline Lernen Electron App";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      runtimeLibs = with pkgs; [
        alsa-lib atk cairo cups dbus expat fontconfig freetype gdk-pixbuf
        glib gtk3 libx11 libxcomposite libxdamage libxext libxfixes libxi
        libxrandr libxrender libxtst libdrm libnotify libsecret libuuid
        libxcb libxshmfence mesa nspr nss pango systemd
      ];
    in {
      packages.${system} = rec {
        cornelsen-offline-lernen = pkgs.stdenv.mkDerivation rec {
          pname = "cornelsen-offline-lernen-bin";
          version = "37.10.2";

          src = pkgs.fetchurl {
            url = "https://ebook.cornelsen.de/uma20/public/v2/uma/offline/win";
            hash = "sha512-yZzR5LaV2RkHERcVE9i6GuvavVkfIZSONtUfa+qwMz9qYQUIS4jAzGi0yk9L1MDxkjAUGJfLfhE10LK50R3hOg=="; 
          };

          nativeBuildInputs = [ pkgs.unzip pkgs.asar pkgs.nodejs pkgs.makeWrapper ];
          buildInputs = [ pkgs.electron ];

          unpackPhase = ''
            unzip $src -d source
            cd source
          '';

          buildPhase = ''
            ASAR_PATH=$(find . -type f -path "*/resources/app.asar" | head -n 1)
            if [ -z "$ASAR_PATH" ]; then
              echo "ERROR: source app.asar not found!"
              exit 1
            fi

            asar extract "$ASAR_PATH" unpacked_asar

            node - unpacked_asar <<'NODE'
            const fs = require('fs');
            const path = require('path');
            const root = process.argv[2];

            const distDir = path.join(root, 'dist');
            if (!fs.existsSync(distDir)) {
                console.error('ERROR: unpacked asar does not contain a dist directory');
                process.exit(1);
            }

            function collectJsFiles(dir, out = []) {
                for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
                    const p = path.join(dir, ent.name);
                    if (ent.isDirectory()) { collectJsFiles(p, out); }
                    else if (ent.isFile() && ent.name.endsWith('.js')) { out.push(p); }
                }
                return out;
            }

            const jsFiles = collectJsFiles(distDir);
            const DOL = '$' + '{';

            const patches = [
                {
                    name: 'annotations-404-fallback',
                    from: 'getProductAnnotations(r,s=!1){return this.http.get(`' + DOL + 's?os.getSyncApiBaseUrl():os.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'r}`).pipe(ip(y=>r0(()=>y)),Jl(y=>this.mapOfflinePdfIds(y)))}',
                    fromAlt: 'getProductAnnotations(r,s=!1){return this.http.get(`' + DOL + 's?ls.getSyncApiBaseUrl():ls.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'r}`).pipe(nc(y=>this.mapOfflinePdfIds(y)))}',
                    toAlt: 'getProductAnnotations(r,s=!1){return this.http.get(`' + DOL + 's?ls.getSyncApiBaseUrl():ls.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'r}`).pipe(op(y=>s&&y.status===404?fs({}):r0(()=>y)),nc(y=>this.mapOfflinePdfIds(y)))}',
                    fromAlt2: 'getProductAnnotations(r,s=!1){return this.http.get(`' + DOL + 's?cs.getSyncApiBaseUrl():cs.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'r}`).pipe(nc(y=>this.mapOfflinePdfIds(y)))}',
                    toAlt2: 'getProductAnnotations(r,s=!1){return this.http.get(`' + DOL + 's?cs.getSyncApiBaseUrl():cs.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'r}`).pipe(op(y=>s&&y.status===404?Es({}):r0(()=>y)),nc(y=>this.mapOfflinePdfIds(y)))}',
                    fromAlt3: 'getProductAnnotations(i,s=!1){return this.http.get(`' + DOL + 's?cs.getSyncApiBaseUrl():cs.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'i}`).pipe(nc(y=>this.mapOfflinePdfIds(y)))}',
                    toAlt3: 'getProductAnnotations(i,s=!1){return this.http.get(`' + DOL + 's?cs.getSyncApiBaseUrl():cs.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'i}`).pipe(ip(y=>{if(s&&y.status===404)return _s({});throw y}),nc(y=>this.mapOfflinePdfIds(y)))}',
                    to: 'getProductAnnotations(r,s=!1){return this.http.get(`' + DOL + 's?os.getSyncApiBaseUrl():os.getApiBaseUrl()}/pspdf/annotations/' + DOL + 'r}`).pipe(ip(y=>s&&y.status===404?hs({}):r0(()=>y)),Jl(y=>this.mapOfflinePdfIds(y)))}',
                    required: false
                },
                {
                    name: 'compatibility-401-fallback',
                    from: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'os.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'GE}`).pipe(sa(r=>r.isCompatible))}',
                    fromAlt: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'ls.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'qE}`).pipe(sa(r=>r.isCompatible))}',
                    toAlt: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'ls.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'qE}`).pipe(sa(r=>r.isCompatible),op(r=>r.status===401?fs(!0):r0(()=>r)))}',
                    fromAlt2: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'cs.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'ZE}`).pipe(sa(r=>r.isCompatible))}',
                    toAlt2: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'cs.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'ZE}`).pipe(sa(r=>r.isCompatible),op(r=>r.status===401?Es(!0):r0(()=>r)))}',
                    fromAlt3: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'cs.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'QE}`).pipe(ta(i=>i.isCompatible))}',
                    toAlt3: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'cs.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'QE}`).pipe(ta(i=>i.isCompatible),ip(r=>{if(r.status===401)return _s(!0);throw r}))}',
                    to: 'isCompatibleWithOnline$(){return this.http.get(`' + DOL + 'os.getSyncApiBaseUrl()}/compatibility/offlineClients/' + DOL + 'GE}`).pipe(sa(r=>r.isCompatible),ip(r=>r.status===401?hs(!0):r0(()=>r)))}',
                    required: false
                }
            ];

            const applied = new Set();
            for (const p of patches) {
                for (const filePath of jsFiles) {
                    let txt = fs.readFileSync(filePath, 'utf8');
                    if (txt.includes(p.from)) {
                        txt = txt.replace(p.from, p.to);
                        fs.writeFileSync(filePath, txt);
                        applied.add(p.name);
                        break;
                    }
                    if (p.fromAlt && p.toAlt && txt.includes(p.fromAlt)) {
                        txt = txt.replace(p.fromAlt, p.toAlt);
                        fs.writeFileSync(filePath, txt);
                        applied.add(p.name);
                        break;
                    }
                    if (p.fromAlt2 && p.toAlt2 && txt.includes(p.fromAlt2)) {
                        txt = txt.replace(p.fromAlt2, p.toAlt2);
                        fs.writeFileSync(filePath, txt);
                        applied.add(p.name);
                        break;
                    }
                    if (p.fromAlt3 && p.toAlt3 && txt.includes(p.fromAlt3)) {
                        txt = txt.replace(p.fromAlt3, p.toAlt3);
                        fs.writeFileSync(filePath, txt);
                        applied.add(p.name);
                        break;
                    }
                }
            }

            for (const p of patches) {
                if (!applied.has(p.name)) {
                    console.error('WARNING: patch ' + p.name + ' did not apply (minified names changed?)');
                    if (p.required) { process.exit(1); }
                }
            }
            NODE

            asar pack unpacked_asar app.asar
          '';

          installPhase = ''
            mkdir -p $out/share/cornelsen-offline-lernen
            cp app.asar $out/share/cornelsen-offline-lernen/app.asar

            mkdir -p $out/bin
            
            cat << 'EOF' > $out/bin/cornelsen-offline-lernen-bin
            #!/bin/sh
            if [ -n "$XDG_DATA_HOME" ]; then
                USER_APP_DIR="$XDG_DATA_HOME/cornelsen-offline-lernen-bin"
            else
                USER_APP_DIR="$HOME/.local/share/cornelsen-offline-lernen-bin"
            fi

            if [ -n "$XDG_CONFIG_HOME" ]; then
                CONFIG_DIR="$XDG_CONFIG_HOME/CornelsenOfflineLernen"
            else
                CONFIG_DIR="$HOME/.config/CornelsenOfflineLernen"
            fi

            SYSTEM_ASAR="@out@/share/cornelsen-offline-lernen/app.asar"
            USER_ASAR="$USER_APP_DIR/app.asar"

            mkdir -p "$USER_APP_DIR" "$CONFIG_DIR"

            if [ ! -f "$USER_ASAR" ] || [ "$(cat "$USER_APP_DIR/.from" 2>/dev/null)" != "@out@" ]; then
                cp -f "$SYSTEM_ASAR" "$USER_ASAR"
                chmod u+w "$USER_ASAR"
                echo "@out@" > "$USER_APP_DIR/.from"
            fi

            exec @electron@/bin/electron \
              "$USER_ASAR" \
              --user-data-dir="$CONFIG_DIR" \
              --ozone-platform-hint=auto \
              "$@"
            EOF
            
            substituteInPlace $out/bin/cornelsen-offline-lernen-bin \
              --subst-var-by out "$out" \
              --subst-var-by electron "${pkgs.electron}"

            chmod +x $out/bin/cornelsen-offline-lernen-bin

            wrapProgram $out/bin/cornelsen-offline-lernen-bin \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs} \
              --set NODE_OPTIONS "--no-warnings"

            # --- ICONS IN HICOLOR-THEME INTEGRIEREN ---
            # Wir nutzen die Nix-Pfad-Antworten, um deine lokalen Dateien in den Build zu holen
            mkdir -p $out/share/icons/hicolor/16x16/apps
            mkdir -p $out/share/icons/hicolor/32x32/apps
            mkdir -p $out/share/icons/hicolor/96x96/apps

            cp ${./icon16.png} $out/share/icons/hicolor/16x16/apps/cornelsen-offline-lernen.png
            cp ${./icon32.png} $out/share/icons/hicolor/32x32/apps/cornelsen-offline-lernen.png
            cp ${./icon96.png} $out/share/icons/hicolor/96x96/apps/cornelsen-offline-lernen.png

            # --- DESKTOP-DATEI MIT ICON-NAME ERSTELLEN ---
            mkdir -p $out/share/applications
            cat <<EOF > $out/share/applications/cornelsen-offline-lernen-bin.desktop
            [Desktop Entry]
            Name=Cornelsen Offline Lernen
            Exec=$out/bin/cornelsen-offline-lernen-bin %U
            Icon=cornelsen-offline-lernen
            Terminal=false
            Type=Application
            Categories=Education;
            MimeType=x-scheme-handler/uma-offline;
            Comment=Cornelsen Offline Lernen Electron Application
            EOF
          '';
        };

        default = cornelsen-offline-lernen;
      };
    };
}