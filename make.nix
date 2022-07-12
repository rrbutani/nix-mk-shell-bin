{ drv
, nixpkgs
, bashPrompt ? null
, bashPromptPrefix ? null
, bashPromptSuffix ? null
}:
let
  # https://github.com/NixOS/nix/blob/155c57c17131770a33dbd86055684d3605a0d505/src/nix/develop.cc#L178
  scrubbed = builtins.removeAttrs drv.drvAttrs [
    "allowedReferences"
    "allowedRequisites"
    "disallowedReferences"
    "disallowedRequisites"
  ];
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
    script = ./gen.py;
    envInp = "${envDetails}";
    unpackPhase = "true";
    buildPhase = ''
      ${nixpkgs.python3}/bin/python3 $script > $out
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
