(*
  dxo2photos.applescript  –  v2  pure-AppleScript architecture

  Replaces the Python/osascript chain so that this droplet itself holds the
  Automation permission for Photos.app.  macOS grants that permission to the
  process that issues the Apple Event – no subprocess can inherit it.

  External dependency: exiftool  (brew install exiftool)
*)

-- ── Bundle helpers ────────────────────────────────────────────────────────────

on bundleResourcePath(fileName)
    return (POSIX path of (path to me)) & "Contents/Resources/" & fileName
end bundleResourcePath

on readResourceFile(fileName)
    try
        set p to bundleResourcePath(fileName)
        return do shell script "cat " & quoted form of p
    on error
        return ""
    end try
end readResourceFile

on getOutputDir()
    set d to readResourceFile("output_dir.txt")
    if d is "" then
        return POSIX path of (path to pictures folder) & "ExportedImages"
    end if
    return d
end getOutputDir

on getAppVersion()
    try
        set plistPath to POSIX path of (path to me) & "Contents/Info.plist"
        return do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & quoted form of plistPath
    on error
        return ""
    end try
end getAppVersion

-- ── Tool discovery ────────────────────────────────────────────────────────────

on findExiftool()
    try
        set p to do shell script ¬
            "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; command -v exiftool"
        if p is not "" then return p
    on error
    end try
    return "/opt/homebrew/bin/exiftool"
end findExiftool

-- ── EXIF operations ───────────────────────────────────────────────────────────

on getExifRating(filePath, exiftool)
    try
        set r to do shell script exiftool & " -Rating -b " & quoted form of filePath
        if r is "" then return 0
        return r as integer
    on error
        return 0
    end try
end getExifRating

on getExifDatetime(filePath, exiftool)
    -- Returns "YYYY:MM:DD HH:MM:SS" or ""
    try
        return do shell script exiftool & " -DateTimeOriginal -b " & quoted form of filePath
    on error
        return ""
    end try
end getExifDatetime

on setExifKeyword(filePath, keyword, exiftool)
    -- Removes then adds the keyword to guarantee exactly one occurrence.
    try
        do shell script exiftool & " -overwrite_original " & ¬
            quoted form of ("-Keywords-=" & keyword) & " " & ¬
            quoted form of ("-Keywords+=" & keyword) & " " & ¬
            quoted form of filePath
    on error errMsg
        log "setExifKeyword error for " & filePath & ": " & errMsg
    end try
end setExifKeyword

-- ── Path helpers ──────────────────────────────────────────────────────────────

on pathParts(posixPath)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "/"
    set parts to text items of posixPath
    set AppleScript's text item delimiters to oldDelims
    return parts
end pathParts

on joinParts(partsList, delim)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delim
    set joined to partsList as text
    set AppleScript's text item delimiters to oldDelims
    return joined
end joinParts

on fileNameOf(posixPath)
    set parts to pathParts(posixPath)
    return item -1 of parts
end fileNameOf

on parentDirOf(posixPath)
    set parts to pathParts(posixPath)
    return joinParts(items 1 thru -2 of parts, "/") & "/"
end parentDirOf

on replaceText(theText, searchStr, replaceStr)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to searchStr
    set parts to text items of theText
    set AppleScript's text item delimiters to replaceStr
    set theResult to parts as text
    set AppleScript's text item delimiters to oldDelims
    return theResult
end replaceText

on buildTargetDir(srcPath, outputDir)
    -- Mirrors the Python logic: outputDir/<grandparent>/<parent>/
    set parts to pathParts(srcPath)
    set n to count of parts
    set parentName to item (n - 1) of parts
    set grandparentName to item (n - 2) of parts
    if not outputDir ends with "/" then set outputDir to outputDir & "/"
    if grandparentName is not "" and grandparentName is not "." then
        return outputDir & grandparentName & "/" & parentName & "/"
    else if parentName is not "" and parentName is not "." then
        return outputDir & parentName & "/"
    else
        return outputDir
    end if
end buildTargetDir

on exifDateToTouchFormat(exifDate)
    -- Input:  "YYYY:MM:DD HH:MM:SS"
    -- Output: "YYYYMMDDHHmm.SS"  (touch -t format)
    if length of exifDate < 19 then return ""
    return (text 1 thru 4 of exifDate) & ¬
        (text 6 thru 7 of exifDate) & ¬
        (text 9 thru 10 of exifDate) & ¬
        (text 12 thru 13 of exifDate) & ¬
        (text 15 thru 16 of exifDate) & ¬
        "." & (text 18 thru 19 of exifDate)
end exifDateToTouchFormat

-- ── Photos import ─────────────────────────────────────────────────────────────

on importToPhotos(albumName, fileList)
    -- fileList: list of POSIX path strings
    if (count of fileList) is 0 then return
    set fileRefs to {}
    repeat with aPath in fileList
        if (aPath as text) is not "" then
            set end of fileRefs to POSIX file (aPath as text)
        end if
    end repeat
    tell application "Photos"
        activate
        if not (exists album named albumName) then
            set theAlbum to make new album named albumName
        else
            set theAlbum to album named albumName
        end if
        import fileRefs into theAlbum skip check duplicates false
    end tell
end importToPhotos

-- ── Main handlers ─────────────────────────────────────────────────────────────

on open droppedFiles
    set exiftool to findExiftool()
    set outputDir to getOutputDir()

    set processedFiles to {}  -- POSIX path strings
    set targetDirs to {}      -- unique target directories
    set errors to {}

    set totalFiles to count of droppedFiles
    set progress total steps to totalFiles + 1  -- +1 for the Photos import step
    set progress completed steps to 0
    set progress description to "Verarbeite Bilder…"
    set progress additional description to "0 von " & totalFiles

    set fileIndex to 0
    repeat with aFile in droppedFiles
        set fileIndex to fileIndex + 1
        set srcPath to POSIX path of aFile
        set srcName to fileNameOf(srcPath)

        set progress additional description to srcName & " (" & fileIndex & " von " & totalFiles & ")"

        -- 1. EXIF keyword
        set rating to getExifRating(srcPath, exiftool)
        setExifKeyword(srcPath, (rating as text) & "*", exiftool)

        -- 2. Read EXIF date before moving
        set exifDate to getExifDatetime(srcPath, exiftool)

        -- 3. Build target path
        set targetDir to buildTargetDir(srcPath, outputDir)
        set targetName to replaceText(srcName, "_openWith", "")
        set targetPath to targetDir & targetName

        try
            do shell script "mkdir -p " & quoted form of targetDir
            do shell script "mv " & quoted form of srcPath & " " & quoted form of targetPath
            if exifDate is not "" then
                set touchStr to exifDateToTouchFormat(exifDate)
                if touchStr is not "" then
                    do shell script "touch -t " & touchStr & " " & quoted form of targetPath
                end if
            end if
            set end of processedFiles to targetPath
            if targetDirs does not contain targetDir then
                set end of targetDirs to targetDir
            end if
        on error errMsg
            set end of errors to srcName & ": " & errMsg
        end try

        set progress completed steps to fileIndex
    end repeat

    -- 4. Import into Photos
    if (count of processedFiles) > 0 then
        -- Mirror Python: 1 unique dir → import it; multiple → import parent of first
        if (count of targetDirs) is 1 then
            set importDir to item 1 of targetDirs
        else
            set importDir to parentDirOf(item 1 of targetDirs)
        end if
        -- Album name = last non-empty path component
        set importDirTrimmed to importDir
        if importDirTrimmed ends with "/" then
            set importDirTrimmed to text 1 thru -2 of importDirTrimmed
        end if
        set albumName to item -1 of pathParts(importDirTrimmed)

        set progress description to "Importiere in Photos…"
        set progress additional description to "Album: " & albumName
        importToPhotos(albumName, processedFiles)
        set progress completed steps to totalFiles + 1
    end if

    set progress description to ""
    set progress additional description to ""

    -- 5. Report errors
    if (count of errors) > 0 then
        set errText to ""
        repeat with msg in errors
            set errText to errText & (msg as text) & return
        end repeat
        display dialog "dxo2photos – Errors:" & return & return & errText ¬
            buttons {"OK"} default button "OK" with icon caution
    end if
end open

on run
    set outDir to getOutputDir()
    set appVersion to getAppVersion()
    if appVersion is not "" then
        set titleLine to "dxo2photos v" & appVersion
    else
        set titleLine to "dxo2photos"
    end if
    display dialog titleLine & return & return & ¬
        "Output directory: " & outDir & return & return & ¬
        "Drop images exported from DxO PhotoLab onto this app," & return & ¬
        "or register it as an External Program in DxO PhotoLab." & return & return & ¬
        "Author: wappensc" & return & ¬
        "https://github.com/wappensc/dxo2photos" ¬
        buttons {"OK"} default button "OK"
end run
