{
  description = "sci-hub-now — open the current page's paper on Sci-Hub";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-webext.url = "github:rivavolt/nix-webext";
  };

  outputs = { self, nixpkgs, nix-webext }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          manifest = builtins.fromJSON (builtins.readFile ./manifest.json);

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
          # Chrome-only (no gecko id). The build feeds nix-webext a pre-assembled
          # `extension` derivation; nix-webext emits the keyless external-extension
          # manifest (CRX signed at activation from the sops key). extId is the
          # stable Chrome ID the old committed key derived.
          built = nix-webext.lib.mkBrowserExtension {
            inherit pkgs extension;
            pname = "sci-hub-now";
            version = manifest.version;
            extId = "njiodifcdjlgicogmdibllagbcaohako";
            firefox = false;
            # service_worker already in Chrome form; nothing to project.
            transformManifest = false;
          };
        in
        # mkBrowserExtension returns the derivations alongside metadata leaves
        # (extId/geckoId/version) — re-export only the derivation members so the
        # cache CI can enumerate packages without coercing a bare string store
        # path with no context.
        {
          inherit (built) chrome chromeContent default release;
        });
    };
}
