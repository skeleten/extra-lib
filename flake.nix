{
  description = "Extra library functions";

  outputs = { self, nixpkgs }: {
    lib = import ./lib { inherit self; inherit (nixpkgs) lib; };
  };
}
