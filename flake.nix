{
  description = "A library OS for Linux multi-process applications, with Intel SGX support";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:

    flake-utils.lib.eachSystem ["x86_64-linux"] (
      system: let
        #pkgs = import nixpkgs { };
        pkgs = nixpkgs.legacyPackages.${system};

        owner = "sbellem";
        pname = "gramine";
        version = "ca2320a8b9c883eb5c17c344dda0d10784f50fc2";

        #src = builtins.path {
        #  path = ./.;
        #  name = "${pname}-${version}";
        #};

        src = pkgs.fetchFromGitHub {
          owner = owner;
          repo = pname;
          rev = version;
          fetchSubmodules = true;
          sha256 = "sha256-LkOBTfZg2nIMNgCF1tZluKLe9JWOVZG8PIB+XPPXEQo=";
        };

        sgxdriver = pkgs.fetchFromGitHub {
          owner = "intel";
          repo = "linux-sgx-driver";
          rev = "sgx_diver_2.14";
          sha256 = "sha256-sY7CBuMtx1ynuR5YqqseWJqxZjXiRVQpIZd7ZaNwa00=";
        };

        # gramine (pre-patched) wrapped subprojects
        #cjson-patched = pkgs.fetchFromGitHub {
        #  owner = "sbellem";
        #  repo = "cjson";
        #  rev = "319cca8f031e2cd615145ad9f427c94bec530583";
        #  sha256 = "sha256-RoD+V6bPhRpI4Iv+7WxA/C1DYJx6PgmGF+wjW858O0o=";
        #};

        #curl-patched = pkgs.fetchFromGitHub {
        #  owner = "sbellem";
        #  repo = "curl";
        #  rev = "172fd98eead2ad006f7dfc684ed83223738ad9a6";
        #  sha256 = "sha256-MKlRvgB4YYtqcKchy6NG3YKg17/RQQ4hwqiQ9OAhLOg=";
        #};
        #
        #glibc-patched = pkgs.fetchFromGitHub {
        #  owner = "sbellem";
        #  repo = "gramine-glibc";
        #  rev = "a0d6113dea0c5fd5fb82e0d2a3c431e8fefdc26d";
        #  sha256 = "sha256-h+uliNnsbfR887he4xHDVVpXsdbyoq4bxpmTGPwj7ZI=";
        #};

        #mbedtls-patched = pkgs.fetchFromGitHub {
        #  owner = "sbellem";
        #  repo = "mbedtls-gramine";
        #  rev = "3972d8eefc81838fb612ecc6e45118990f8c17c3";
        #  fetchSubmodules = true;
        #  sha256 = "sha256-5rRi9fTCu70qzb4q7PxnVgVt7nbur3lCD0Uv19SxAAM=";
        #};
        #
        #musl-patched = pkgs.fetchFromGitHub {
        #  owner = "sbellem";
        #  repo = "gramine-musl";
        #  rev = "8bf5cd7e09879b3cc9886cf29a2538220875e9b4";
        #  sha256 = "sha256-XooRQMmLQda/uYbU0t0aCHTghM4UJYfACG5fj5+Gr+M=";
        #};
        #
        #uthash-patched = pkgs.fetchFromGitHub {
        #  owner = "sbellem";
        #  repo = "uthash";
        #  rev = "c70c610befc8b2f033ad73ba64e0c8a9b0509443";
        #  sha256 = "sha256-hwexk2zR8APYwYD2mhB7xtmICCJ5A5M4F7yZ6IA78uU=";
        #};

        #tomlc99-patched = pkgs.fetchFromGitHub {
        #  owner = "sbellem";
        #  repo = "tomlc99";
        #  rev = "98a4344e4cbea6c551c1ff4e595d30d11f09d98b";
        #  sha256 = "sha256-Qz8w0XxrPxr3MO43J7ifiAZZXscWTg0WC4zFH3vKg/E=";
        #};

        _nativeBuildInputs = with pkgs; [
          meson
          ninja
          pkg-config
          cmake
          cjson
          ############
          autoconf
          bison
          gawk
          glibc
          #libcurl4-openssl-dev
          protobuf
          protobufc
          python3
          libunwind
          nasm
          #protobuf-compiler
          #protobuf-c-compiler
          #musl-tools
          musl
          #### python
          python310Packages.click
          python310Packages.cryptography
          #python310Packages.protobuf
          python310Packages.jinja2
          python310Packages.pyelftools
          python310Packages.pytest
          python310Packages.toml
          python310Packages.tomli
          python310Packages.tomli-w
        ];
      in
        with pkgs; {
          packages.${pname} = stdenv.mkDerivation rec {
            inherit pname src sgxdriver _nativeBuildInputs;
            name = pname;

            nativeBuildInputs = _nativeBuildInputs;
            buildInputs = with pkgs; [ cjson ];
            enableParallelBuilding = true;
            mesonBuildType = "release";
            mesonFlags = [
              "-Ddirect=enabled"
              "-Dsgx=enabled"
              "-Dsgx_driver=oot"
              "-Dsgx_driver_include_path=${sgxdriver}"
            ];

            # TODO: revert back to nodownload
            #mesonWrapMode = "default";

            #dontUseMesonConfigure = true;
            #dontUseNinjaBuild = true;
            #dontUseNinjaInstall = true;
            #dontUseNinjaCheck = true;

            # TODO must apply patches
            # see https://github.com/mesonbuild/meson/blob/b30cd5d2d587546eac8b560a8c311a52d69fb53e/mesonbuild/wrap/wrap.py#L770-L810`
            # see https://nixos.org/manual/nixpkgs/stable/#ssec-patch-phase
            #
            # there are 2 main steps involved:
            #
            # 1. copy patch dir files into the subproject repo -- there may be more than
            #    just patch files, like a meson.build file, and other files
            # 2. apply patches
            #
            #
            # TODO: no need to delete the .wrap files
            #postUnpack = ''
            #  cp -r ${cjson-patched} source/subprojects/cJSON-1.7.12
            #  cp -r ${curl-patched} source/subprojects/curl-7.84.0
            #  cp -r ${glibc-patched} source/subprojects/glibc-2.36-1
            #  cp -r ${mbedtls-patched} source/subprojects/mbedtls-mbedtls-3.3.0
            #  cp -r ${musl-patched} source/subprojects/musl-1.2.2
            #  cp -r ${tomlc99-patched} source/subprojects/tomlc99-208203af46bdbdb29ba199660ed78d09c220b6c5
            #  cp -r ${uthash-patched} source/subprojects/uthash-2.1.0
            #'';
              
              #rm -rf source/subprojects/gcc-10.2.0.wrap
              #ln -s ${gcc1020} source/subprojects/gcc-10.2.0
              #
              #rm -rf source/subprojects/glibc-2.36-1.wrap
              #ln -s ${glibc2361} source/subprojects/glibc-2.36-1
              #
              #rm -rf source/subprojects/musl-1.2.2.wrap
              #ln -s ${musl122} source/subprojects/musl-1.2.2


            #configurePhase = ''
            #  runHook preConfigure
            #  meson setup build/
            #    -Ddirect=enabled
            #    -Dsgx=enabled
            #    -Dsgx_driver=oot
            #    -Dsgx_driver_include_path=${sgxdriver}

            #  runHook postConfigure
            #'';

            #postBuild = ''
            #'';

            #installPhase = ''
            #  runHook preInstall

            #  mkdir -p $out/bin
            #  cp target/x86_64-fortanix-unknown-sgx/release/cipher-paratime.sgxs $out/bin/

            #  runHook postInstall
            #'';

            #meta = with pkgs.lib; {
            #  homepage = "https://github.com/gramineproject/gramine";
            #  license = with licenses; [ gpl3Only ];
            #  maintainers = [ "sbellem" ];
            #};
          };

          defaultPackage = self.packages.${system}.${pname};

          devShell = mkShell {
            inherit _nativeBuildInputs;

            buildInputs = _nativeBuildInputs ++ [ exa ];

            shellHook = ''
              alias ls=exa
              alias find=fd
            '';
          };
        }
    );
}
