#!/usr/bin/env swift
// Posts a real HID-level mouse click at global screen coordinates (points, top-left origin).
// Usage: swift scripts/tap.swift <x> <y>
// Requires Accessibility permission for the running terminal (same as osascript clicks).
// System Events `click at` fails against the Simulator (-25204); this CGEvent approach works.
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]) else {
    FileHandle.standardError.write("usage: tap.swift <x> <y>\n".data(using: .utf8)!)
    exit(2)
}
let p = CGPoint(x: x, y: y)
let src = CGEventSource(stateID: .hidSystemState)

CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(120_000)
CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(60_000)
CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
print("tapped at \(p)")
