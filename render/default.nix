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

      # Helper function to transform module options by replacing Nix store paths
      # with relative URLs. It ensures that if the sourcePath is a directory, links
      # point to `DIRECTORY/default.nix`.
      transformModuleOptions = { sourceName, sourcePath, baseUrl }:
        let
          # Convert the sourcePath to a string for comparison operations.
          sourcePathStr = toString sourcePath;
        in
        # Function that accepts module option set and returns modified option set.
        opt:
        let
          # Process each `declaration` in the module options, appending `default.nix`
          # if the declaration is determined to be a directory.
          declarations = lib.concatMap
            (decl:
              if lib.hasPrefix sourcePathStr (toString decl)
              then
                let
                  # Remove the Nix store path prefix to get the relative path.
                  subpath = lib.removePrefix sourcePathStr (toString decl);
                  # Append `default.nix` if subpath ends with a slash (indicating dir).
                  fullPath = if lib.pathIsDirectory decl then subpath + "/default.nix" else subpath;
                in
                [{ url = baseUrl + fullPath; name = sourceName + fullPath; }]
              # If the declaration does not start with source path, return empty.
              else [ ]
            )
            # List of declarations to process, obtained from the `opt` input argument.
            opt.declarations;
        in
        # Return the original module option set merged with the new declarations that
          # contain the relative URLs or `default.nix` for directories.
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
