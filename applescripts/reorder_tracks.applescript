on run argv
    set playlistName to item 1 of argv

    tell application "Music"
        set thePlaylist to playlist playlistName
        repeat with i from 2 to (count of argv)
            set theID to (item i of argv) as integer
            move (track id theID of thePlaylist) to end of thePlaylist
        end repeat
    end tell
end run
