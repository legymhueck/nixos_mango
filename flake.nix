{
  description = "nixbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hylki = {
      url = "path:./flakes/hylki";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # no "follows" here, otherwise the Cachix binary cache cannot be used
    noctalia.url = "github:noctalia-dev/noctalia";
  };

  outputs = { nixpkgs, home-manager, mango, ... }@inputs: {
    nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        mango.nixosModules.mango
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "bak";
            extraSpecialArgs = { inherit inputs; };
            users.m = import ./home.nix;
          };
        }
      ];
    };
  };
}
