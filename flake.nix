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

        owner = "gramineproject";
        pname = "gramine";
        version = "v1.4";

        #src = builtins.path {
        #  path = ./.;
        #  name = "${pname}-${version}";
        #};

        src = pkgs.fetchFromGitHub {
          owner = owner;
          repo = pname;
          rev = version;
          sha256 = "sha256-jq1GMxgJO2ij4f+G5GWn++F+eDyMS9sO4wZw/X65TMc=";
        };

        sgxdriver = pkgs.fetchFromGitHub {
          owner = "intel";
          repo = "linux-sgx-driver";
          rev = "sgx_diver_2.14";
          sha256 = "sha256-sY7CBuMtx1ynuR5YqqseWJqxZjXiRVQpIZd7ZaNwa00=";
        };
        
        tomlc99 = pkgs.fetchFromGitHub {
          owner = "cktan";
          repo = "tomlc99";
          rev = "208203af46bdbdb29ba199660ed78d09c220b6c5";
          sha256 = "sha256-LTl9czE3+Bysp4MaM7GpTOuNjpYuYWa3l03t7g3AKmM=";
          #sha256 = pkgs.lib.fakeSha256;
        };

        _nativeBuildInputs = with pkgs; [
          meson
          ninja
          pkg-config
          ############
          autoconf
          bison
          gawk
          glibc
          #libcurl4-openssl-dev
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
          python310Packages.protobuf
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
            inherit pname src sgxdriver _nativeBuildInputs tomlc99;
            name = pname;

            nativeBuildInputs = _nativeBuildInputs;
            #buildInputs = with pkgs; [ libadwaita ];
            enableParallelBuilding = true;
            mesonBuildType = "release";
            mesonFlags = [
              "-Ddirect=enabled"
              "-Dsgx=enabled"
              "-Dsgx_driver=oot"
              "-Dsgx_driver_include_path=${sgxdriver}"
            ];

            # TODO: revert back to nodownload
            mesonWrapMode = "default";

            #dontUseMesonConfigure = true;
            dontUseNinjaBuild = true;
            dontUseNinjaInstall = true;
            dontUseNinjaCheck = true;

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
            postUnpack = ''
              ln -s ${tomlc99} source/subprojects/tomlc99-208203af46bdbdb29ba199660ed78d09c220b6c5
              ln -s ${uthash} source/subprojects/uthash-2.1.0
              ln -s ${mbedtls} source/subprojects/mbedtls-mbedtls-3.3.0
              ln -s ${curl} source/subprojects/curl-7.84.0
              ln -s ${cjson} source/subprojects/cJSON-1.7.12
            '';
              
              #rm -rf source/subprojects/gcc-10.2.0.wrap
              #ln -s ${gcc1020} source/subprojects/gcc-10.2.0
              #
              #rm -rf source/subprojects/glibc-2.36-1.wrap
              #ln -s ${glibc2361} source/subprojects/glibc-2.36-1
              #
              #rm -rf source/subprojects/musl-1.2.2.wrap
              #ln -s ${musl122} source/subprojects/musl-1.2.2


            buildPhase = ''
              runHook preBuild
              meson setup build/

              runHook postBuild
            '';

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
