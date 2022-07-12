{
  description = "`nix develop`, but at build time.";

  outputs = { self }: {
    lib = { mkShellBin = import ./make.nix; };
  };
}
