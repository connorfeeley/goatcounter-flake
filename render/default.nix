# SPDX-FileCopyrightText: 2023 Connor Feeley
#
# SPDX-License-Identifier: BSD-3-Clause


{ localFlake, withSystem }:

{ lib, config, self, inputs, ... }:
{
  perSystem = { system, pkgs, ... }:
    let
      # evaluate our options
      eval = lib.evalModules {
        modules = [
          # Don't check that options defined elsewhere (ie. in nixpkgs) are defined.
          { _module.check = false; }

          # NixOS module from this flake.
          localFlake.nixosModules.goatcounter
        ];
      };

      # Helper function to replace Nix store paths with relative URLs
      transformModuleOptions = { sourceName, sourcePath, baseUrl }:
        let sourcePathStr = toString sourcePath;
        in
        opt:
        let
          # Replace the Nix store path with a relative URL pointing to the repository files
          declarations = lib.concatMap
            (decl:
              if lib.hasPrefix sourcePathStr (toString decl)
              then
                let subpath = lib.removePrefix sourcePathStr (toString decl);
                in [{ url = baseUrl + subpath; name = sourceName + subpath; }]
              else [ ]
            )
            opt.declarations;
        in
        opt // { inherit declarations; };

      # Generate our docs
      optionsDoc = pkgs.nixosOptionsDoc {
        inherit (eval) options;
        markdownByDefault = true;
        warningsAreErrors = true;
        documentType = "none";
        transformOptions = transformModuleOptions {
          baseUrl = "https://github.com/connorfeeley/goatcounter-flake/blob/master"; # Replace with your actual repository URL
          sourcePath = localFlake.outPath;
          sourceName = "goatcounter-flake";
        };
      };

      rendered = pkgs.runCommand "option-doc"
        {
          nativeBuildInputs = [ pkgs.libxslt.bin pkgs.pandoc ];
          inputDoc = optionsDoc.optionsDocBook;
          title = "GoatCounter NixOS Module Options";
        } ''
        xsltproc --stringparam title "$title" \
          -o options.db.xml ${./options.xsl} \
          "$inputDoc"
        mkdir $out
        pandoc --verbose --from docbook --to html options.db.xml > $out/options.html
        pandoc --verbose --from docbook --to gfm options.db.xml > $out/options.md
        pandoc --verbose --from docbook --to org options.db.xml > $out/options.org
      '';
    in
    {
      # create a derivation for capturing the markdown output
      packages.options-doc = rendered;
    };
}
