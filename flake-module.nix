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

          localFlake.nixosModules.goatcounter
        ];
      };

      # generate our docs
      optionsDoc = pkgs.nixosOptionsDoc {
        inherit (eval) options;
        markdownByDefault = true;
        documentType = "none";
      };

      rendered = pkgs.runCommand "option-doc"
        {
          nativeBuildInputs = [ pkgs.libxslt.bin pkgs.pandoc ];
          inputDoc = optionsDoc.optionsDocBook;
        } ''
        xsltproc --stringparam title "$title" \
          -o options.db.xml ${./options.xsl} \
          "$inputDoc"
        mkdir $out
        pandoc --verbose --from docbook --to html options.db.xml >options.html
      '';
    in
    {
      # create a derivation for capturing the markdown output
      packages.options-doc = optionsDoc.optionsDocBook;
    };
}
