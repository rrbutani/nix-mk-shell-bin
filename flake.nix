{
  description = "`nix develop`, but at build time.";

  outputs = { self }: {
    lib = { mkShellBin = import ./make.nix; };

    checks = builtins.listToAttrs (
      builtins.map
        (s: { name = s; value = import ./test.nix { system = s; }; })
        ["aarch64-linux" "aarch64-darwin" "x86_64-linux" "x86_64-darwin"]
    );
  };
}
