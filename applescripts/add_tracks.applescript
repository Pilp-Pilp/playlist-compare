on run argv
    set destName to item 1 of argv
    set sourceName to item 2 of argv

    tell application "Music"
        set destPlaylist to playlist destName
        set sourcePlaylist to playlist sourceName
        repeat with i from 3 to (count of argv)
            set theID to (item i of argv) as integer
            duplicate (track id theID of sourcePlaylist) to destPlaylist
        end repeat
    end tell
end run
