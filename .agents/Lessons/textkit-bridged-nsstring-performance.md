---
id: "lesson-textkit-bridged-nsstring-performance"
version: 1
date: "2026-11-21"
source_change: "016-yaml-native-support-frontmatter-properties-and-perf"
tags: ["performance", "textkit2", "swift-string", "nsstring-bridging"]
---

# Lesson: Normalize `NSTextView.string` to native UTF-8 at the TextKit boundary

## Context
`NSTextView.string` returns a Swift `String` lazily backed by the text storage's `NSString`. Storing it in
`DocumentSession` made every keystroke on a 1 MB buffer cost ~25 ms (bridged `==`), and every later scan
(gutter 9.3 ms vs 1.7, status bar 10.4 ms vs 0.55, lint 37 ms vs 18) ran 2–19x slower.

## Rule
- Convert once with `NativeTextNormalizer.native(_:)` (`String(decoding: Array(s.utf8), as: UTF8.self)`, ~2 ms/MB).
  Do NOT use `makeContiguousUTF8()` on bridged strings: it measured ~17 ms/MB.
- Inside the editor coordinator, keep a native mirror (`nativeTextMirror`) and compare/index from it instead of
  re-reading `textView.string`; fall back to the storage string only on a UTF-16 length mismatch.
- Microbenchmarks that feed native literals hide this cost: always benchmark with text read back from an `NSTextView`
  (`PerfBench016.bridgedFromTextView`).
