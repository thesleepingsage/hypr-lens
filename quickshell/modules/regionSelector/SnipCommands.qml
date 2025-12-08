pragma Singleton
import QtQuick
import Quickshell
import "../common"
import "../common/functions"

// Command builders for snip actions
// Centralizes shell command construction for screenshot/recording operations
Singleton {
    id: root

    // Build ImageMagick crop command base
    function buildCropBase(screenshotPath: string, rx: int, ry: int, rw: int, rh: int): string {
        return `magick ${StringUtils.shellSingleQuoteEscape(screenshotPath)} -crop ${rw}x${rh}+${rx}+${ry}`;
    }

    // Build cleanup command
    function buildCleanup(screenshotPath: string): string {
        return `rm '${StringUtils.shellSingleQuoteEscape(screenshotPath)}'`;
    }

    // Copy to clipboard (with optional save to disk)
    function buildCopyCommand(screenshotPath: string, rx: int, ry: int, rw: int, rh: int, saveDir: string): list<string> {
        const cropBase = buildCropBase(screenshotPath, rx, ry, rw, rh);
        const cropToStdout = `${cropBase} -`;
        const cleanup = buildCleanup(screenshotPath);

        if (saveDir === "") {
            return ["bash", "-c", `${cropToStdout} | wl-copy && ${cleanup}`];
        }

        return [
            "bash", "-c",
            `mkdir -p '${StringUtils.shellSingleQuoteEscape(saveDir)}' && \
            saveFileName="screenshot-$(date '+%Y-%m-%d_%H.%M.%S').png" && \
            savePath="${saveDir}/$saveFileName" && \
            ${cropToStdout} | tee >(wl-copy) > "$savePath" && \
            ${cleanup}`
        ];
    }

    // Edit with swappy
    function buildEditCommand(screenshotPath: string, rx: int, ry: int, rw: int, rh: int): list<string> {
        const cropBase = buildCropBase(screenshotPath, rx, ry, rw, rh);
        const cropToStdout = `${cropBase} -`;
        const cleanup = buildCleanup(screenshotPath);
        return ["bash", "-c", `${cropToStdout} | swappy -f - && ${cleanup}`];
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
