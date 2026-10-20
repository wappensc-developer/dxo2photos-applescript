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

on userConfigBase()
    return (POSIX path of (path to application support folder from user domain)) & ¬
        "de.wappensc.dxo2photos/config"
end userConfigBase

on bundleConfigBase()
    return bundleResourcePath("config")
end bundleConfigBase

-- ── Configuration ─────────────────────────────────────────────────────────────

on readConfig(keyName)
    -- Per-user setting first, then the default stored in the bundle at build time.
    -- Returns "" if the key is set in neither.
    repeat with base in {userConfigBase(), bundleConfigBase()}
        try
            set v to do shell script "defaults read " & quoted form of (contents of base) & " " & keyName
            if v is not "" then return v
        end try
    end repeat
    return ""
end readConfig

on readBoolConfig(keyName, defaultValue)
    set v to readConfig(keyName)
    if {"1", "true", "yes"} contains v then return true
    if {"0", "false", "no"} contains v then return false
    return defaultValue
end readBoolConfig

on writeConfig(keyName, typeFlag, theValue)
    -- typeFlag: "-string" or "-bool"
    do shell script "mkdir -p " & quoted form of parentDirOf(userConfigBase())
    do shell script "defaults write " & quoted form of userConfigBase() & " " & keyName & ¬
        " " & typeFlag & " " & quoted form of (theValue as text)
end writeConfig

on getOutputDir()
    set d to readConfig("outputDirectory")
    if d is not "" then return d
    return POSIX path of (path to pictures folder) & "ExportedImages"
end getOutputDir

on getRatingSettings()
    -- keepRating:   leave the DxO star rating in the file (default: true)
    -- writeKeyword: add the star keyword "0*"…"5*" (default: true)
    set keepRating to readBoolConfig("keepStarRating", true)
    set writeKeyword to readBoolConfig("writeRatingKeyword", true)
    -- Never remove a rating without writing the keyword instead.
    if not keepRating and not writeKeyword then set keepRating to true
    return {keepRating:keepRating, writeKeyword:writeKeyword}
end getRatingSettings

on ratingModeLabels()
    -- Order matches ratingModeIndex.
    return {"Keep star rating and add keyword (e.g. 4*)", ¬
        "Keep star rating only", ¬
        "Keyword only (remove star rating)"}
end ratingModeLabels

on ratingModeIndex(settings)
    if (keepRating of settings) and (writeKeyword of settings) then return 1
    if keepRating of settings then return 2
    return 3
end ratingModeIndex

on chooseRatingMode()
    set labels to ratingModeLabels()
    set currentLabel to item (ratingModeIndex(getRatingSettings())) of labels
    set picked to choose from list labels with title "dxo2photos" ¬
        with prompt "How should star ratings from DxO PhotoLab be handled?" ¬
        default items {currentLabel} OK button name "Save" cancel button name "Cancel"
    if picked is false then return
    set idx to 1
    repeat with i from 1 to count of labels
        if item i of labels is item 1 of picked then set idx to i
    end repeat
    writeConfig("keepStarRating", "-bool", (idx ≤ 2))
    writeConfig("writeRatingKeyword", "-bool", (idx ≠ 2))
    display dialog "Star ratings:" & return & (item idx of labels) buttons {"OK"} default button "OK"
end chooseRatingMode

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

on starKeywords()
    return {"0*", "1*", "2*", "3*", "4*", "5*"}
end starKeywords

on getExifMetadata(filePath, exiftool)
    -- Single exiftool call returning {rating: text, datetime: text}.
    -- rating:   star rating as text ("" = no rating); XMP preferred over EXIF
    -- datetime: "YYYY:MM:DD HH:MM:SS" or ""
    -- -m makes missing tags empty; without it exiftool drops the whole line
    -- when one tag is missing (e.g. no rating), losing the capture date too.
    try
        set raw to do shell script exiftool & ¬
            " -m -p '${XMP-xmp:Rating}|${IFD0:Rating}|${DateTimeOriginal}' " & quoted form of filePath
        set parts to splitText(raw, "|")
        if (count of parts) < 3 then return {rating:"", datetime:""}
        set ratingStr to item 1 of parts
        if ratingStr is "" then set ratingStr to item 2 of parts
        return {rating:ratingStr, datetime:item 3 of parts}
    on error
        return {rating:"", datetime:""}
    end try
end getExifMetadata

on writeRatingMetadata(filePath, keyword, removeRating, exiftool)
    -- keyword:      star keyword to set, e.g. "4*" ("" = leave keywords alone).
    --               Other star keywords are removed first, so exactly one remains.
    -- removeRating: also delete the star rating (XMP and EXIF), in the same call.
    -- Returns "" on success, error message on failure.
    set args to ""
    if keyword is not "" then
        repeat with k in starKeywords()
            set args to args & " " & quoted form of ("-IPTC:Keywords-=" & (contents of k))
        end repeat
        set args to args & " " & quoted form of ("-IPTC:Keywords+=" & keyword)
    end if
    if removeRating then
        set args to args & " -XMP-xmp:Rating= -IFD0:Rating= -IFD0:RatingPercent= -XMP-microsoft:RatingPercent="
    end if
    if args is "" then return ""
    try
        do shell script exiftool & " -q -overwrite_original" & args & " " & quoted form of filePath
        return ""
    on error errMsg
        return errMsg
    end try
end writeRatingMetadata

on applyRatingSettings(filePath, ratingText, keepRating, writeKeyword, exiftool)
    -- ratingText: star rating read from the file ("" = unrated → keyword "0*").
    -- Returns "" on success, otherwise an error text for the end-of-run dialog.
    if ratingText is not "" and not ({"0", "1", "2", "3", "4", "5"} contains ratingText) then
        return "(rating): unsupported value " & ratingText & ", metadata left unchanged"
    end if
    set keyword to ""
    if writeKeyword then
        if ratingText is "" then
            set keyword to "0*"
        else
            set keyword to ratingText & "*"
        end if
    end if
    set removeRating to (not keepRating) and ratingText is not "" and keyword is not ""
    set errMsg to writeRatingMetadata(filePath, keyword, removeRating, exiftool)
    if errMsg is not "" then return "(metadata): " & errMsg
    return ""
end applyRatingSettings

-- ── Path helpers ──────────────────────────────────────────────────────────────

on splitText(theText, delim)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delim
    set parts to text items of theText
    set AppleScript's text item delimiters to oldDelims
    return parts
end splitText

on pathParts(posixPath)
    return splitText(posixPath, "/")
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

on stripOpenWithSuffix(fileName)
    -- Removes _openWith only from the stem (before the extension), not mid-filename.
    set dotPos to 0
    repeat with i from (count fileName) to 1 by -1
        if character i of fileName is "." then
            set dotPos to i
            exit repeat
        end if
    end repeat
    if dotPos > 1 then
        set stem to text 1 thru (dotPos - 1) of fileName
        set ext to text dotPos thru -1 of fileName
    else
        set stem to fileName
        set ext to ""
    end if
    if stem ends with "_openWith" then
        set stem to text 1 thru -((length of "_openWith") + 1) of stem
    end if
    return stem & ext
end stripOpenWithSuffix

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
    set ratingSettings to getRatingSettings()
    set keepRating to keepRating of ratingSettings
    set writeKeyword to writeKeyword of ratingSettings

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

        -- 1. Read EXIF rating and date in a single exiftool call
        set meta to getExifMetadata(srcPath, exiftool)
        set ratingText to rating of meta
        set exifDate to datetime of meta

        -- 2. Star rating → keyword and/or removal, as configured
        set metaErr to applyRatingSettings(srcPath, ratingText, keepRating, writeKeyword, exiftool)
        if metaErr is not "" then
            set end of errors to srcName & " " & metaErr
        end if

        -- 3. Build target path
        set targetDir to buildTargetDir(srcPath, outputDir)
        set targetName to stripOpenWithSuffix(srcName)
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
    set albumName to ""
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

    -- 5. Success notification (only when all files imported without errors)
    if (count of processedFiles) > 0 and (count of errors) is 0 then
        display notification ((count of processedFiles as text) & " images → album " & quote & albumName & quote) ¬
            with title "dxo2photos" sound name "Glass"
    end if

    -- 6. Report errors
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
    set ratingLabel to item (ratingModeIndex(getRatingSettings())) of ratingModeLabels()
    set answer to button returned of (display alert titleLine ¬
        message "Author: wappensc" & return & ¬
            "https://github.com/wappensc" & return & return & ¬
            "Drop DxO PhotoLab exports here," & return & ¬
            "or add as External Program in DxO." & return & return & ¬
            "Output directory:" & return & outDir & return & return & ¬
            "Star ratings:" & return & ratingLabel ¬
        buttons {"Change output directory…", "Star ratings…", "OK"} default button "OK")
    if answer is "Change output directory…" then
        set chosen to POSIX path of (choose folder with prompt "Select output directory for dxo2photos:")
        if chosen ends with "/" then set chosen to text 1 thru -2 of chosen
        writeConfig("outputDirectory", "-string", chosen)
        display dialog "Output directory set to:" & return & chosen buttons {"OK"} default button "OK"
    else if answer is "Star ratings…" then
        chooseRatingMode()
    end if
end run
