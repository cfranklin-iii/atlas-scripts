function fish_greeting
    echo "   ===   Logging in to ""(hostname)"" as '$USER'...   ===   "

    set greetings \
"   ===   Loading fish $FISH_VERSION... Don't fuck anything up :)   ===   " \
"   ===   Warning: Unauthorized access detected. Just kidding, Welcome back, $USER.   ===   " \
"   ===   Getting ready for some bullshit...   ===   " \
"   ===   Connecting to System Secure Shell...   ===
     ===   Making sure everything is ready...   ===
       ===   Flipping pancakes and bacon...   ===
          ===   Terminal Runtime Loaded.   ==="

    set random_greet $greetings[(math (random 1 (count $greetings)))]
    echo " $random_greet "
end

if status is-interactive; and command -q fastfetch
    fastfetch
end

# Load machine-specific config overrides if they exist.
if test -f "$__fish_config_dir/config.local.fish"
    source "$__fish_config_dir/config.local.fish"
end

