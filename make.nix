{ drv
, nixpkgs
, bashPrompt ? null
, bashPromptPrefix ? null
, bashPromptSuffix ? null
}:
let
  # https://github.com/NixOS/nix/blob/94cf0da7b2955d5b54a142b9e920332746a61033/src/nix/develop.cc#L190
  scrubbed = (builtins.removeAttrs drv.drvAttrs [
    "allowedReferences"
    "allowedRequisites"
    "disallowedReferences"
    "disallowedRequisites"
    "name"
  ]) // { name = "${drv.name}-env"; };
  envDetails = let
    outputs' = builtins.map (n:
      { name = n; value = builtins.placeholder n; }
    ) (scrubbed.outputs or ["out"]);
    outputs = builtins.listToAttrs outputs';
  in
    derivation (scrubbed // {
      args = [./get-env.sh];
    } // outputs);

  ifNotNull = attrs: let
    keysToKeep = builtins.filter (
      n: attrs.${n} != null
    ) (builtins.attrNames attrs);
  in
    builtins.listToAttrs (builtins.map (
      n: { name = n; value = attrs.${n}; }
    ) keysToKeep);
  promptAttrs = ifNotNull {
    inherit bashPrompt bashPromptPrefix bashPromptSuffix;
  };

  envScript = nixpkgs.stdenvNoCC.mkDerivation ({
    name = scrubbed.name + "-gen-bashrc";
    envInp = "${envDetails}";
    unpackPhase = "true";
    buildPhase = ''
      ${nixpkgs.python3}/bin/python3 ${./gen.py} > $out
    '';
    installPhase = "true";
  } // promptAttrs);
in
  nixpkgs.stdenvNoCC.mkDerivation {
    name = scrubbed.name + "-shell";
    unpackPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      echo "#!/usr/bin/env ${nixpkgs.bash}/bin/bash" >> $out/bin/$name
      echo "exec ${nixpkgs.bashInteractive}/bin/bash --rcfile ${envScript}" >> $out/bin/$name

      chmod +x $out/bin/$name
    '';
  }
