# ~/.config.fish/config.fish - Fish shell configuration

if not status is-interactive
	exit
end

# --- Auto-Refresh (Once per session) ---
set -l marker_file "$HOME/.dotfiles_initialized_"(id -u)
if not test -f "$marker_file"
	if not command -v zoxide >/dev/null 2>&1
		echo "[Auto-Setup] Essential tools missing. Running setup..."
		set -l S_SCRIPT "$HOME/.dotfiles/.setup.sh"
		if test -f "$S_SCRIPT"
			bash "$S_SCRIPT"
		else
			echo "[Auto-Setup] Error: Could not find .setup.sh"
		end
	end
	touch "$marker_file"
end

# --- Environment Variables (Global, Exported) ---
set -gx TERMINAL kitty
set -gx EDITOR nvim
set -gx BROWSER brave
set -gx MAIL erkka@ervice.fi

# --- Disable Fish Greeting ---
function fish_greeting
end

# --- PATH Modifications (Secure Append) ---
if test -d "$HOME/.local/bin"
	fish_add_path --append "$HOME/.local/bin"
end
if test -d "$HOME/.cargo/bin"
	fish_add_path --append "$HOME/.cargo/bin"
end
if test -d "/var/lib/flatpak/exports/bin"
	fish_add_path --append "/var/lib/flatpak/exports/bin"
end

# --- Command Color Settings ---
alias ls='ls --color=auto'
alias grep='grep --color=auto'
if command -v ip > /dev/null
	alias ip='ip -color=auto'
end
alias rm='rm -I'

# --- Disk Usage ---
alias df='df -h'
alias free='free -m'

# --- Processes ---
alias psa="ps auxf"
alias psgrep="ps aux | grep -v grep | grep -i -e VSZ -e"
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# --- Git Aliases ---
# All Git aliases have been moved to ~/.gitconfig

# --- Modern Tool Aliases ---
if command -v batcat > /dev/null
	alias cat='batcat --paging=never'
else if command -v bat > /dev/null
	alias cat='bat --paging=never'
end

if command -v fdfind > /dev/null
	alias find='fdfind'
else if command -v fd > /dev/null
	alias find='fd'
end

if command -v rg > /dev/null
	alias grep='rg'
end

if command -v flatpak > /dev/null
	if test -d "/var/lib/flatpak/app/com.visualstudio.code"; or test -d "$HOME/.local/share/flatpak/app/com.visualstudio.code"
		alias code='flatpak run com.visualstudio.code'
	end
end

# Fallback alias for neovim (uses Flatpak if nvim is not in PATH)
if not command -v nvim > /dev/null; and command -v flatpak > /dev/null
	if test -d "/var/lib/flatpak/app/io.neovim.nvim"; or test -d "$HOME/.local/share/flatpak/app/io.neovim.nvim"
		alias nvim='flatpak run io.neovim.nvim'
	end
end

# --- Functions ---

function mkcd
	mkdir -p $argv[1]
	and cd $argv[1]
end

function fish_prompt
	set -l user_name "ervice"
	set -l c_cyan (set_color cyan)
	set -l c_magenta (set_color magenta)
	set -l c_norm (set_color normal)
	echo -n $c_cyan"["$user_name"@"(prompt_hostname)(prompt_pwd)"]"$c_norm
	set -l g_branch (git symbolic-ref --short HEAD 2> /dev/null)
	if test -n "$g_branch"
		set -l g_status (git status --porcelain 2> /dev/null)
		set -l u ""
		set -l s ""
		if string match -q -- "* M *" $g_status; or string match -q -- "*??*" $g_status; or string match -q -- "* D *" $g_status
			set u "U"
		end
		if string match -q -- "M *" $g_status; or string match -q -- "A *" $g_status; or string match -q -- "D *" $g_status
			set s "+"
		end
		echo -n $c_magenta(string trim -- "("$g_branch$u$s")")$c_norm
	end
	if fish_is_root_user
		echo -n "# "
	else
		echo -n "> "
	end
end

function compile
	if test -z "$argv[1]"
		return 1
	end
	
	set -l f (basename "$argv[1]")
	set -l o (mktemp "/tmp/$f.XXXXXX")
	if test -z "$o"
		echo "Failed to create temp file" >&2
		return 1
	end
	
	if gcc "$argv[1]" -Wall -Wextra -Werror -o "$o"
		"$o"
		set -l ret_code $status
		rm -f "$o"
		return $ret_code
	else
		rm -f "$o"
		return 1
	end
end

function extract
	for i in $argv
		if not test -f "$i"
			echo "extract: File '$i' does not exist." >&2
			continue
		end

		if command -v bsdtar > /dev/null
			switch "$i"
				case '*.tar.bz2' '*.tar.gz' '*.tar.xz' '*.tbz2' '*.tgz' '*.txz' '*.tar'
					bsdtar xvf "$i"
				case '*.zip'
					unzip "$i"
				case '*.rar'
					unrar x "$i"
				case '*.7z'
					7z x "$i"
				case '*.gz'
					gunzip "$i"
				case '*.xz'
					unxz "$i"
				case '*.zst'
					unzstd "$i"
				case '*'
					echo "extract: Skipped '$i' (unknown extension)." >&2
			end
		else
			# Fallback to standard native tools if bsdtar is missing
			switch "$i"
				case '*.tar.bz2' '*.tbz2'
					tar xvjf "$i"
				case '*.tar.gz' '*.tgz'
					tar xvzf "$i"
				case '*.tar.xz' '*.txz'
					tar xvJf "$i"
				case '*.tar'
					tar xvf "$i"
				case '*.zip'
					unzip "$i"
				case '*.rar'
					unrar x "$i"
				case '*.7z'
					7z x "$i"
				case '*.gz'
					gunzip "$i"
				case '*.xz'
					unxz "$i"
				case '*.zst'
					unzstd "$i"
				case '*'
					echo "extract: Skipped '$i' (unknown extension or missing tool)." >&2
			end
		end
	end
end

alias ipinfo='ipinformation'
function ipinformation
	if test -z "$argv[1]"
		curl https://ipinfo.io | grep -v '"readme":'
	else
		curl "https://ipinfo.io/$argv[1]" | grep -v '"readme":'
	end
	echo
end

# --- Dotfiles Management Wrappers ---
function __get_dotfiles_repo_root
	cat "$HOME/.dotfiles-path" 2>/dev/null
	or echo "$HOME/.dotfiles"
end

function refresh
	set -l REPO_ROOT (__get_dotfiles_repo_root)
	bash "$REPO_ROOT/.scripts/refresh.sh" $argv
end

function cleanup
	set -l REPO_ROOT (__get_dotfiles_repo_root)
	bash "$REPO_ROOT/.scripts/cleanup.sh" $argv
end

function startfresh
	set -l REPO_ROOT (__get_dotfiles_repo_root)
	bash "$REPO_ROOT/.scripts/startfresh.sh" $argv
end

# --- Security Aliases & Functions ---
function networkscan
	nmap -T4 -F $argv
end
if command -v sudo > /dev/null; and sudo -n true 2>/dev/null
	alias audit='sudo lynis audit system'
else
	alias audit='lynis audit system'
end

# --- Load Local Secrets (Ignored by Git) ---
if test -f "$HOME/.config/shell_secrets"
	source "$HOME/.config/shell_secrets"
end

# --- Init Integrations ---

# This logic MUST only run in interactive shells, otherwise it breaks login.
if status is-interactive
	# Prompt for SSH keys if the agent is empty
	if not ssh-add -l > /dev/null 2>&1
		ssh-add
	end

	# Tmux Auto-Attach Logic: Removed the TERM_PROGRAM check to allow it in VS Code
	if command -v tmux > /dev/null; and not set -q TMUX; and test -z "$VSCODE_RESOLVING_ENVIRONMENT"
		if tmux has-session -t main 2>/dev/null
			exec tmux attach-session -t main
		else
			exec tmux new-session -s main
		end
	end
end

# --- SSH Agent ---
set -l HOST_ID (uname -n)
set -l SSH_ENV_FISH "$HOME/.ssh/agent-info-$HOST_ID.fish"

# 1. Try to load existing agent
if test -f "$SSH_ENV_FISH"
	source "$SSH_ENV_FISH"
end

# 2. Check if agent is actually alive
# ssh-add -l returns 0 if good, 1 if empty, 2 if dead/unreachable
ssh-add -l > /dev/null 2>&1
if test $status -eq 2
	# Agent is dead. Run the POSIX init script to start it.
	sh "$HOME/.ssh_agent_init"
	# Reload the valid variables
	source "$SSH_ENV_FISH"
end

# These will run on the first prompt, *after* the shell is fully interactive.
if command -v zoxide > /dev/null
	function __zoxide_init --on-event fish_prompt
		zoxide init fish | source
		functions -e __zoxide_init
	end
end

if command -v fzf > /dev/null
	function __fzf_init --on-event fish_prompt
		fzf --fish | source
		functions -e __fzf_init
	end
end

if command -v direnv > /dev/null
	function __direnv_init --on-event fish_prompt
		direnv hook fish | source
		functions -e __direnv_init
	end
end

# --- Auto-configure Git GPG Signing ---
if command -v git > /dev/null; and test -n "$GPG_SIGNING_KEY"
	# Safely assign to a variable to prevent Fish syntax crashes on empty strings
	set -l current_key (git config --global user.signingkey 2>/dev/null)
	if test "$current_key" != "$GPG_SIGNING_KEY"
		git config --global user.signingkey "$GPG_SIGNING_KEY"
		git config --global commit.gpgsign true
		git config --global tag.gpgSign true
		echo "[INFO] Git GPG signing configured."
	end
end

# --- VS Code Flatpak Shell Integration ---
# Enables VS Code terminal integration when running via Flatpak (host-spawn)
if test "$TERM_PROGRAM" = "vscode"
	# Zero-cost check: Only run flatpak queries if the VS Code flatpak is actually installed
	if test -d "/var/lib/flatpak/app/com.visualstudio.code"; or test -d "$HOME/.local/share/flatpak/app/com.visualstudio.code"
		# 1. Ask VS Code where the script is (returns /app/...)
		set -l script_in_fp (flatpak run com.visualstudio.code --locate-shell-integration-path fish 2>/dev/null)
		
		# 2. Ask Flatpak where the app is stored on the host (returns /var/lib/...)
		set -l fp_location (flatpak info -l com.visualstudio.code 2>/dev/null)
		
		# 3. Replace '/app' with the real host path
		if test -n "$fp_location"
			set -l real_path (string replace "/app" "$fp_location/files" "$script_in_fp")
			
			if test -f "$real_path"
				source "$real_path"
			end
		end
	end
end
