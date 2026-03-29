{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-ruby,
    }:
    let
      appDir = "/Users/fizzy/fizzy-bea";
      system = "x86_64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      ruby = nixpkgs-ruby.lib.packageFromRubyVersionFile {
        file = ./.ruby-version;
        inherit system;
      };
      nativeBuildInputs = with pkgs; [
        cacert
        curl
        git
        icu
        libyaml
        vips

        gum
        ruby
      ];
      env = {
        ruby = rec {
          MULTI_TENANT = true;
          BUNDLE_PATH = "vendor/bundle";
          GEM_HOME = "${BUNDLE_PATH}/${ruby.rubyEngine}/${ruby.version.libDir}";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ pkgs.vips ]}";
        };
        production = {
          FORCE_SSL = false;
          RAILS_ENV = "production";
          BUNDLE_DEPLOYMENT = "1";
          BUNDLE_WITHOUT = "development:test";
        };
      };
      mkFizzyPackage =
        name: text:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = nativeBuildInputs;
          runtimeEnv = env.ruby // env.production;
          excludeShellChecks = [ "SC1091" ];
          text = ''
            echo "changing to project directory..."
            cd ${appDir}
            export PATH="$GEM_HOME/bin:$PATH"

            echo "getting secrets..."
            set -a; source .env; set +a
            ${pkgs.secretspec}/bin/secretspec check --profile production --provider env

            ${text}
          '';
        };
    in
    {
      packages.${system} = rec {
        setup = mkFizzyPackage "setup" ''
          echo "bundling..."
          bundle install       2> >(tee error.log)
          bin/rails db:prepare 2> >(tee -a error.log)

          echo "compiling assets..."
          bundle exec bootsnap precompile -j 1 app/ lib/      2> >(tee -a error.log)
          SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile 2> >(tee -a error.log)

          rm error.log
        '';

        server = mkFizzyPackage "server" ''
          bin/rails server "$@"
        '';

        restart = mkFizzyPackage "restart" ''
          bin/rails restart
        '';

        console = mkFizzyPackage "restart" ''
          bin/rails console
        '';

        deploy = pkgs.writeShellApplication {
          name = "deploy";
          text = ''
            cd ${appDir};
            ${pkgs.git}/bin/git pull --rebase

            ${setup}/bin/setup
            ${restart}/bin/restart
          '';
        };
      };
      devShell.${system} =
        with pkgs;
        mkShell {
          nativeBuildInputs = nativeBuildInputs;
          env = env.ruby;
          shellHook = ''export PATH="$GEM_HOME/bin:$PATH"'';
        };
    };
}
