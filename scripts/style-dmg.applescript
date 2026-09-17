on run arguments
    set mountPath to item 1 of arguments
    set backgroundFile to POSIX file (mountPath & "/.background/install-layout.pdf") as alias
    tell application "Finder"
        set diskFolder to POSIX file mountPath as alias
        open diskFolder
        set installerWindow to container window of diskFolder
        set current view of installerWindow to icon view
        set toolbar visible of installerWindow to false
        set statusbar visible of installerWindow to false
        set pathbar visible of installerWindow to false
        set bounds of installerWindow to {200, 160, 800, 558}
        set options to icon view options of installerWindow
        set arrangement of options to not arranged
        set icon size of options to 96
        set text size of options to 13
        set shows item info of options to false
        set shows icon preview of options to true
        set background picture of options to backgroundFile
        set position of item "Get Clean Text.app" of diskFolder to {155, 190}
        set position of item "Applications" of diskFolder to {445, 190}
        close installerWindow
        open diskFolder
        update diskFolder without registering applications
        delay 2
        close container window of diskFolder
    end tell
end run
