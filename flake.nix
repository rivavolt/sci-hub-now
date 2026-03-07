{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          extension = pkgs.stdenv.mkDerivation {
            pname = "sci-hub-now";
            version = "0-unstable";
            src = self;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out/share/chromium-extension
              cp -r manifest.json service_worker.js options.html options.js \
                    browser-polyfill.js icons data helper_js \
                    $out/share/chromium-extension/
            '';
          };

          manifest = builtins.fromJSON (builtins.readFile "${extension}/share/chromium-extension/manifest.json");

          extId = builtins.readFile (pkgs.runCommand "sci-hub-now-ext-id" {
            nativeBuildInputs = [ pkgs.python3 pkgs.openssl ];
          } ''
            python3 ${./nix/crx-id.py} ${./keys/signing.pem} > $out
          '');

          crx = pkgs.runCommand "sci-hub-now-crx" {
            nativeBuildInputs = [ pkgs.python3 pkgs.openssl ];
          } ''
            mkdir -p $out
            python3 ${./nix/pack-crx3.py} ${extension}/share/chromium-extension ${./keys/signing.pem} $out/extension.crx
          '';

        in {
          inherit extension;
          default = pkgs.linkFarm "sci-hub-now" [
            { name = "share/chromium/extensions/${extId}.json";
              path = pkgs.writeText "${extId}.json" (builtins.toJSON {
                external_crx = "${crx}/extension.crx";
                external_version = manifest.version;
              });
            }
          ];
        });
    };
}
