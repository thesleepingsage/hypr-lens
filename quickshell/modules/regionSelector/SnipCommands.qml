pragma Singleton
import QtQuick
import Quickshell
import "../common"
import "../common/functions"

// Command builders for snip actions
// Centralizes shell command construction for screenshot/recording operations
Singleton {
    id: root

    // Expand ~ to actual home directory (bash doesn't expand ~ in single quotes)
    function expandTilde(path: string): string {
        if (path.startsWith("~/")) {
            return Directories.home + path.slice(1);
        }
        if (path === "~") {
            return Directories.home;
        }
        return path;
    }

    // Build ImageMagick crop command base
    function buildCropBase(screenshotPath: string, rx: int, ry: int, rw: int, rh: int): string {
        return `magick ${StringUtils.shellSingleQuoteEscape(screenshotPath)} -crop ${rw}x${rh}+${rx}+${ry}`;
    }

    // Build cleanup command
    function buildCleanup(screenshotPath: string): string {
        return `rm '${StringUtils.shellSingleQuoteEscape(screenshotPath)}'`;
    }

    // Default save location when savePath is empty
    readonly property string defaultSavePath: Directories.home + "/Pictures/hypr-lens"

    // Resolve and expand save directory path
    function resolveSavePath(saveDir: string): string {
        const targetDir = saveDir !== "" ? saveDir : defaultSavePath;
        return expandTilde(targetDir);
    }

    // Build shell commands for save directory setup and filename generation
    function buildSaveSetup(expandedDir: string): string {
        return `mkdir -p '${StringUtils.shellSingleQuoteEscape(expandedDir)}' && \
            saveFileName="screenshot-$(date '+%Y-%m-%d_%H.%M.%S').png" && \
            savePath="${expandedDir}/$saveFileName"`;
    }

    // Build notification command (follows record.sh pattern)
    // Uses & disown to background notification properly
    function buildNotify(title: string, body: string): string {
        return `notify-send '${title}' "${body}" -a 'hypr-lens' & disown`;
    }

    // Copy to clipboard (optionally also saves to disk if copyAlsoSaves is true)
    function buildCopyCommand(screenshotPath: string, rx: int, ry: int, rw: int, rh: int, saveDir: string, alsoSave: bool): list<string> {
        const cropBase = buildCropBase(screenshotPath, rx, ry, rw, rh);
        const cropToStdout = `${cropBase} -`;
        const cleanup = buildCleanup(screenshotPath);

        if (!alsoSave) {
            return ["bash", "-c", `${cropToStdout} | wl-copy && \
            { ${buildNotify("Copied to clipboard", "")}; } && \
            ${cleanup}`];
        }

        const expandedSaveDir = resolveSavePath(saveDir);
        return [
            "bash", "-c",
            `${buildSaveSetup(expandedSaveDir)} && \
            ${cropToStdout} | tee >(wl-copy) > "$savePath" && \
            if [ -f "$savePath" ]; then \
                ${buildNotify("Copied & saved", "$savePath")}; \
            else \
                ${buildNotify("Copy failed", "")}; \
            fi && \
            ${cleanup}`
        ];
    }

    // Edit action: annotate with satty (preferred) or swappy.
    // satty runs under a bundled config (~/.config/hypr-lens/satty.toml via -c) plus per-mode
    // flags, so it saves to the hypr-lens dir, copies to the clipboard and discards on Escape -
    // with NO XDG_CONFIG_HOME override, so GTK theming stays native. satty shows its own
    // notifications. Falls back to a bare swappy invocation (end-4 style) when satty is disabled
    // or not installed.
    function buildEditCommand(screenshotPath: string, rx: int, ry: int, rw: int, rh: int, saveDir: string, alsoSave: bool): list<string> {
        const cropBase = buildCropBase(screenshotPath, rx, ry, rw, rh);
        const cropToStdout = `${cropBase} -`;
        const cleanup = buildCleanup(screenshotPath);

        // Annotation tool disabled: bare swappy (end-4 style; swappy owns its own save/copy).
        if (!Config.options.regionSelector.annotation.useSatty) {
            return ["bash", "-c", `${cropToStdout} | swappy -f -; ${cleanup}`];
        }

        const sattyCfg = StringUtils.shellSingleQuoteEscape(Directories.shellConfig + "/satty.toml");
        if (!alsoSave) {
            const sattyCmd = `satty -c '${sattyCfg}' -f - --copy-command 'wl-copy' --actions-on-escape exit`;
            return [
                "bash", "-c",
                `${cropToStdout} | if command -v satty >/dev/null 2>&1; then ${sattyCmd}; else swappy -f -; fi; \
                ${cleanup}`
            ];
        }

        const expandedSaveDir = resolveSavePath(saveDir);
        // Save mode: satty writes the annotated image to $savePath on its save action.
        // The swappy fallback is bare and saves via its own mechanism (ignores $savePath).
        const sattyCmd = `satty -c '${sattyCfg}' -f - -o "$savePath" --copy-command 'wl-copy' --actions-on-enter save-to-clipboard,save-to-file --actions-on-escape exit`;
        return [
            "bash", "-c",
            `${buildSaveSetup(expandedSaveDir)} && \
            ${cropToStdout} | if command -v satty >/dev/null 2>&1; then ${sattyCmd}; else swappy -f -; fi; \
            ${cleanup}`
        ];
    }

    // Image search (clipboard-based: copy to clipboard + open search page)
    function buildSearchCommand(screenshotPath: string, rx: int, ry: int, rw: int, rh: int,
                                 searchPageUrl: string): list<string> {
        const cropBase = buildCropBase(screenshotPath, rx, ry, rw, rh);
        const cropToStdout = `${cropBase} -`;
        const cleanup = buildCleanup(screenshotPath);
        // Copy to clipboard AND open search page - user pastes with Ctrl+V
        return ["bash", "-c", `${cropToStdout} | wl-copy && xdg-open "${searchPageUrl}" && ${cleanup}`];
    }

    // OCR with tesseract
    function buildOcrCommand(screenshotPath: string, rx: int, ry: int, rw: int, rh: int): list<string> {
        const cropBase = buildCropBase(screenshotPath, rx, ry, rw, rh);
        const cropInPlace = `${cropBase} '${StringUtils.shellSingleQuoteEscape(screenshotPath)}'`;
        const cleanup = buildCleanup(screenshotPath);
        const tesseractLangs = `$(tesseract --list-langs | awk 'NR>1{print $1}' | tr '\\n' '+' | sed 's/\\+$/\\n/')`;
        return ["bash", "-c", `${cropInPlace} && tesseract '${StringUtils.shellSingleQuoteEscape(screenshotPath)}' stdout -l ${tesseractLangs} | wl-copy && ${cleanup}`];
    }

    // Screen recording
    function buildRecordCommand(recordScriptPath: string, absX: int, absY: int, rw: int, rh: int, withSound: bool): list<string> {
        const recordRegion = `${absX},${absY} ${rw}x${rh}`;
        if (withSound) {
            return ["bash", "-c", `${recordScriptPath} --region '${recordRegion}' --sound`];
        }
        return ["bash", "-c", `${recordScriptPath} --region '${recordRegion}'`];
    }
}
