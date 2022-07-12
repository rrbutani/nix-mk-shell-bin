# `nix-mk-shell-bin`

`nix develop`, but at build time.

## what

This is a nix expression that replicates the [transformation `nix develop` does on derivations](https://github.com/NixOS/nix/blob/4248174e7165f48f92416d13b862e3ef8192a34b/src/nix/develop.cc#L464-L569), ultimately yielding a script that, when run, drops you into a `nix develop`-like shell.

## but why?

Mostly for [`nix-bundle`](https://github.com/matthewbauer/nix-bundle).

I wanted to be able to package a `mkShell` derivation as a self-contained executable; you can't do this directly since `mkShell` doesn't actually produce a binary that you can run (`mkShell` [used to](https://github.com/NixOS/nixpkgs/pull/153194) actually produce derivations that you [couldn't](https://github.com/NixOS/nixpkgs/blob/c524608dca14c8716eaefa88d2aa8c757af48daa/pkgs/build-support/mkshell/default.nix#L44-L49) even build normally).

`mkShell` instead relies on `nix develop` (or `nix-shell`) to extract information from the derivation and construct an environment from it. `mkShellBin` does more or less the same steps to construct this environment but does so as part of building its derivation.

## do you have an example?

Sure. This repo is packaged as a [flake](https://nixos.wiki/wiki/Flakes), so:

```nix
{
  # Add to your flake's inputs:
  inputs.msb = github:rrbutani/nix-mk-shell-bin;

  # Use `mkShellBin`, exposed under `lib`:
  outputs = { msb, .. }: let
    mkShellBin = msb.lib.mkShellBin;
  in {
    # ...
  };
}
```

`mkShellBin` takes:
```nix
{ drv
, nixpkgs
, bashPrompt ? null
, bashPromptPrefix ? null
, bashPromptSuffix ? null
}
```

Here's an example flake that you can run:
```nix
{
  inputs = {
    msb.url = github:rrbutani/nix-mk-shell-bin;
    nixpkgs.url = github:nixOS/nixpkgs/22.05;
    flu.url = github:numtide/flake-utils;
  };

  outputs = { msb, nixpkgs, flu, ... }: with msb.lib; with flu.lib; eachDefaultSystem(system: let
    np = import nixpkgs { inherit system; };

    # Like `nix-shell`, this will build the dependencies of `pkg` but not
    # `pkg` itself.
    pkg = np.hello;
    pkgShellBin = mkShellBin { drv = pkg; nixpkgs = np; };

    # Here, `shellBin` *will* build `pkg`. This is like `nix develop`.
    shell = np.mkShell { name = "example"; nativeBuildInputs = [pkg]; };
    shellBin = msb.lib.mkShellBin { drv = shell; nixpkgs = np; bashPrompt = "[hello]$ "; };

  in {
    # You can run `nix bundle` and get a self-contained executable that,
    # when run, drops you into a shell containing `pkg`.
    packages.default = shellBin;
    packages.pkgShellBin = pkgShellBin;

    # You can run the derivations `mkShellBin` produces:
    apps.default = { type = "app"; program = "${shellBin}/bin/${shellBin.name}"; };

    # The above is more or less equivalent to:
    devShells.default = shell;
  });
}
```

## anything else?

This repo makes use of [source code](get-env.sh) from the [`nix` repo](https://github.com/NixOS/nix) and, like the `nix` repo, is licensed under the LGPLv2.
