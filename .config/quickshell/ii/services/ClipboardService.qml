pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Temporary, isolated clipboard service for Dynamic Island
// Does NOT touch system clipboard/history
Singleton {
    id: clip

    // Public state
    property bool hasItem: false
    // one of: "none","text","urls","image","binary"
    property string kind: "none"
    property string text: ""
    // List<string> file:// or http(s) URLs
    property var urls: []
    // For quick preview when possible
    property url imageUrl: "" // points to an image if detected
    // Raw mime map for custom data
    property var mime: ({})

    signal changed()
    signal cleared()

    // Lightweight generic drag image for text/urls as SVG data URL
    function _genericTextDragImage() {
        // Small rounded rect with a glyph-like indicator
        const svg = `<?xml version='1.0' encoding='UTF-8'?>
<svg xmlns='http://www.w3.org/2000/svg' width='64' height='40' viewBox='0 0 64 40'>
  <rect x='2' y='2' rx='6' ry='6' width='60' height='36' fill='#303446' stroke='#8c8fa1' stroke-width='2'/>
  <path d='M20 26 L20 15 L16 15 L16 12 L28 12 L28 15 L24 15 L24 26 Z' fill='#c6d0f5'/>
  <rect x='30' y='18' width='18' height='3' rx='1' fill='#c6d0f5'/>
  <rect x='30' y='23' width='14' height='3' rx='1' fill='#c6d0f5'/>
  <rect x='30' y='28' width='10' height='3' rx='1' fill='#c6d0f5'/>
  <rect x='12' y='8' width='12' height='3' rx='1.5' fill='#c6d0f5' opacity='0.6'/>
  <rect x='16' y='6' width='12' height='3' rx='1.5' fill='#c6d0f5' opacity='0.4'/>
  <rect x='20' y='4' width='12' height='3' rx='1.5' fill='#c6d0f5' opacity='0.2'/>
  <rect x='10' y='32' width='44' height='2' rx='1' fill='#8c8fa1' opacity='0.35'/>
</svg>`
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg)
    }

    function clear() {
        hasItem = false
        kind = "none"
        text = ""
        urls = []
        imageUrl = ""
        mime = ({})
        cleared()
        changed()
    }

    // Heuristics to decide item type from a DropEvent-like object
    function _inferKindFromDrop(drop) {
        // Qt Quick DropEvent has: text, urls, formats
        const u = (drop.urls || []).filter(u => !!u)
        const t = (drop.text || "").trim()
        const fmts = drop.formats || []
        // Image if any url ends with image extensions or format contains image/*
        const hasImageFmt = fmts.some(f => String(f).startsWith("image/"))
        const imgUrl = u.find(v => /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(String(v)))
        if (hasImageFmt || imgUrl) return { kind: "image", imageUrl: imgUrl || "" }
        if (u.length > 0) return { kind: "urls" }
        if (t.length > 0) return { kind: "text" }
        return { kind: "binary" }
    }

    // Store from a Qt Quick DropEvent
    function storeFromDrop(drop) {
        const inf = _inferKindFromDrop(drop)
        kind = inf.kind
        if (kind === "image") {
            // Prefer explicit image URL if present; else if only a file URL is provided, keep it
            const u = (drop.urls || []).filter(u => !!u)
            urls = u
            imageUrl = inf.imageUrl || (u.length > 0 ? u[0] : "")
            text = ""
        } else if (kind === "urls") {
            urls = (drop.urls || []).filter(u => !!u)
            text = ""
            imageUrl = ""
        } else if (kind === "text") {
            text = drop.text || ""
            urls = []
            imageUrl = ""
        } else {
            // Capture minimal mime map for debug/reference
            urls = []
            text = ""
            imageUrl = ""
            const m = {}
            const fmts = drop.formats || []
            for (let i = 0; i < fmts.length; i++) m[fmts[i]] = true
            mime = m
        }
        hasItem = true
        changed()
    }

    // Build Drag attached data for dragging out
    function buildDragData(target) {
        if (!hasItem) return
        console.log("ClipboardService.buildDragData kind=", kind)
        if (kind === "text") {
            // Populate MIME payload for maximum compatibility
            const md = target.Drag.mimeData
            if (md && text && text.length > 0) {
                md.setData("text/plain", text)
                // Some targets prefer UTF-8 explicit
                md.setData("text/plain;charset=utf-8", text)
                // Also provide text/html minimal fragment for apps that sniff it
                const safe = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                md.setData("text/html", `<p>${safe}</p>`)
            }
            // Provide a generic drag image for visual feedback
            target.Drag.imageSource = _genericTextDragImage()
        } else if (kind === "urls" || kind === "image") {
            const md = target.Drag.mimeData
            if (md && urls && urls.length > 0) {
                // RFC 2483 text/uri-list requires CRLF line endings
                const uriList = urls.join("\r\n") + "\r\n"
                md.setData("text/uri-list", uriList)
                // Provide plain text fallback of URLs
                md.setData("text/plain", urls.join("\n"))
            }
            if (kind === "urls") {
                // Provide a generic drag image for URLs as well
                target.Drag.imageSource = _genericTextDragImage()
            }
            // If we have an image, provide a drag image for visual feedback
            if (kind === "image" && imageUrl && String(imageUrl).length > 0) {
                target.Drag.imageSource = imageUrl
            }
        } else {
            // Fallback: no-op, keep drag disabled
        }
    }
}
