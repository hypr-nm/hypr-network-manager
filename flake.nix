{
  description = "A GTK4-based network manager for Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        hypr-network-manager = pkgs.stdenv.mkDerivation {
          pname = "hypr-network-manager";
          version = "0.2.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            meson
            ninja
            pkg-config
            vala
            glib
            wrapGAppsHook4
          ];

          buildInputs = with pkgs; [
            gtk4
            gtk4-layer-shell
            json-glib
            networkmanager
          ];

          meta = {
            description = "A GTK4-based network manager for Hyprland";
            homepage = "https://github.com/hypr-nm/hypr-network-manager";
            license = pkgs.lib.licenses.gpl3Plus;
            platforms = supportedSystems;
            mainProgram = "hypr-network-manager";
          };
        };

        default = self.packages.${pkgs.stdenv.hostPlatform.system}.hypr-network-manager;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.hypr-network-manager ];

          packages = with pkgs; [
            vala-language-server
            uncrustify
          ];
        };
      });
    };
}
