# We don't want to have to keep the example in the README in sync with something
# else (i.e. an example dir with a `flake.nix` and a `flake.lock`)... so we do
# this bad hack (extract the example from the README and run it).
#
# We also don't want to have this flake depend on nixpkgs directly since that
# dep would then be passed on to our users (it's basically guaranteed that users
# of `nix-mk-shell-bin` will be pulling in `nixpkgs` anyways but even so; it's
# nicer if users don't need to remember to add a `.inputs.nixpkgs.follows = ...`
# for this dep). So, we steal the nixpkgs commit out of the `flake.lock` in the
# example.

{ system ? builtins.currentSystem }:
let
  readme = builtins.readFile ./README.md;
  extractExampleFile =
    { name
    , prefix ? ""
    , suffix ? ""
    , mapContents ? file: str: str
    }: let
      tag = "<!-- EXAMPLE: ${name} -->\n";
      res = builtins.split "${tag}${prefix}(.*)${suffix}${tag}" readme;
      contentsRaw = builtins.head (builtins.elemAt res 1);
      contents' = builtins.unsafeDiscardStringContext contentsRaw;
    in rec {
      file = builtins.toFile name contents';
      contents = mapContents file contents';
    };

  flake = extractExampleFile {
    name = "flake.nix"; prefix = "```nix\n"; suffix = "```\n";
    mapContents = f: _: import f;
  };
  lock = extractExampleFile {
    name = "flake.lock"; prefix = "<!--\n"; suffix = "-->\n";
    mapContents = _: builtins.fromJSON;
  };

  # This is like `flake-compat` but much less robust/principled; this is okay
  # because this only needs to work for our example's deps (and this will fail
  # loudly if/when we add deps that don't have the structure we expect – i.e.
  # deps that have deps).
  #
  # We'd like to just be able to do `builtins.getFlake flake.file` (or really,
  # some store path containing a dir with the flake and lock files in lieu of
  # `flake.file`) but this isn't allowed; `builtins.getFlake` cannot be given
  # a store path.
  deps = builtins.mapAttrs
    (name: { locked, ... }:
      (builtins.getFlake
        "${locked.type}:${locked.owner}/${locked.repo}/${locked.rev}"
      ).outputs
    )
    (builtins.removeAttrs lock.contents.nodes ["root"]);

  # At this point we (finally) have access to `nixpkgs`.
  np = deps.nixpkgs.legacyPackages.${system};
  lib = deps.nixpkgs.lib;
  flu = deps.flu.lib;

  # We can now invoke our example flake, passing in its flake inputs and
  # overriding `msb` for this flake:
  msb = (import ./flake.nix).outputs { self = msb; };
  example = flake.contents.outputs (deps // { self = example; inherit msb; });

  # Forward all the outputs from the example (except for those that we know
  # don't yield derivations and aren't suitable for use as `checks`):
  outputs = lib.pipe example [
    # Apps aren't derivations:
    (attrs: builtins.removeAttrs attrs ["apps"])
    # Extract the stuff for the current system:
    (builtins.mapAttrs
      (_: v: if builtins.hasAttr system v then v.${system} else v)
    )
    # Inject `recurseForDerivations` into the sets so that `flattenTree` will
    # pick them up:
    (builtins.mapAttrs (_: a: a // { recurseForDerivations = true; }))
  ];
in flu.flattenTree { example = outputs // { recurseForDerivations = true; }; }
