# Agent mode

BamboOS can run as a headless box for AI coding agents: a VM or a spare machine with a terminal, Docker and language runtimes, and no desktop using RAM.

## Turn it on

```bash
bambo-agent on
```

What it does:

- Creates `~/.config/bambo/headless`. With this file present, tty1 login gives you a shell and Hyprland does not start.
- Enables and starts `sshd` and `docker.socket`.
- Enables linger for your user, so tmux sessions survive logout.
- Starts a tmux session named `agents`.

Reboot, or log out of Hyprland, to release the desktop's memory.

## Use it

```bash
ssh you@machine
bambo-agent shell           # attach to the "agents" tmux session
bambo-agent install-claude  # npm install -g @anthropic-ai/claude-code into ~/.local
claude
```

tmux prefix is `Ctrl-a`. Detach with `Ctrl-a d`. The session keeps running.

Other commands:

- `bambo-agent status`: mode, service state, memory in use
- `bambo-agent off`: desktop starts again on the next login

## What is preinstalled

- Docker (your user is in the `docker` group after `bambo-install`)
- Node.js LTS and npm. Global installs go to `~/.local`, no sudo.
- Python and uv
- git, ripgrep, fzf, jq, curl, wget, tmux
- Chromium, for agents that drive a headless browser: `chromium --headless=new`

Go is not preinstalled. Add it with `sudo pacman -S go`.

## Security notes

- `sshd` uses the stock Arch config: password login is allowed. Add your key to `~/.ssh/authorized_keys` and set `PasswordAuthentication no` in `/etc/ssh/sshd_config.d/` before exposing the machine.
- Membership of the `docker` group is equivalent to root on the machine.
