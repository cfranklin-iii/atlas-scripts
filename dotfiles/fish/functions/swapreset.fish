function swapreset
    if sudo swapoff -a; and sudo swapon -a
        echo "Swap reset successfully."
    else
        echo "Failed to reset swap."
    end
end