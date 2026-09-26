# Zsh with Oh My Zsh, set up the way the TIL recommends.
#
# Companion to https://abdelhousni.github.io/til/nixos/zsh-oh-my-zsh-declarative.html
# test.nix checks the behaviour described there; ci/eval-checks.sh checks the
# generated /etc/zshrc without building anything.
{ pkgs, ... }:

{
  programs.zsh = {
    # Required: without it, setting a user's shell to zsh fails evaluation.
    enable = true;
    # Oh My Zsh runs compinit itself; this stops NixOS running it a second time.
    enableGlobalCompInit = false;
    ohMyZsh = {
      enable = true;
      # The default is "", which loads no theme at all.
      theme = "robbyrussell";
      plugins = [ "git" "sudo" ];
    };
    # Shadows the git plugin's `gc` (git commit --verbose). NixOS writes its
    # aliases after Oh My Zsh, so this one wins, silently. The test checks it.
    shellAliases.gc = "sudo nix-collect-garbage -d";
  };

  users.defaultUserShell = pkgs.zsh;

  # Tools come from NixOS modules, not from the plugin list: these install the
  # package and hook it into zsh. programs.fzf also adds the "fzf" plugin.
  programs.fzf.keybindings = true;
  programs.zoxide.enable = true;
}
