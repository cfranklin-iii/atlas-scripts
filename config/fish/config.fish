## Custom Fish configuration file
# Function to randomize the greeting message
function fish_greeting
    echo "   ===   Welcome to the Fish $FISH_VERSION!   ==="
    echo "   ===   Logging in to '"(hostname)"' as '$USER'...   ==="

    set greetings \
"   ===   Loading fish $FISH_VERSION... Don't mess anything up :)   ===" \
"   ===   Warning: Unauthorized access detected. Just kidding, Welcome back, $USER.   ===" \
"   ===   Initializing terminal...   ===" \
"   ===   Setting up environment...   ===" \
"   ===   Patching up some wires...   ===" \
"   ===   Connecting to System Secure Shell...   ===" \
"   ===   Making sure everything is ready...   ===" \
"   ===   Flipping pancakes and bacon...   ===" \
"   ===   Terminal Runtime Loaded.   ==="

    set random_greet $greetings[(math (random 1 (count $greetings)))]
    echo " $random_greet "
end

# CI Helper
if test -d ~/.local/bin
    fish_add_path -gp ~/.local/bin
end

# Make a call to fastfetch (if applicable)
if status is-interactive; and command -q fastfetch
    fastfetch
end

# Load machine-specific config overrides
if test -f "$__fish_config_dir/config.local.fish"
    source "$__fish_config_dir/config.local.fish"
end

