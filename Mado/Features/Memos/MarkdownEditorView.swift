#if os(macOS)
import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.insertionPointColor = NSColor(MadoColors.accent)
        textView.font = .systemFont(ofSize: 15)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 4)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        textView.defaultParagraphStyle = paragraphStyle

        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.textView = textView

        textView.string = text
        context.coordinator.applyMarkdownStyling(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyMarkdownStyling(textView)
            textView.selectedRanges = selectedRanges
            context.coordinator.isUpdating = false
        }

        let action = NotesViewModel.shared.markdownAction
        if action != .none && !context.coordinator.isProcessingAction {
            context.coordinator.isProcessingAction = true
            Task { @MainActor in
                NotesViewModel.shared.markdownAction = .none
                context.coordinator.isProcessingAction = false
            }
            switch action {
            case .togglePrefix(let prefix):
                context.coordinator.toggleLinePrefix(prefix)
            case .wrapSelection(let marker):
                context.coordinator.wrapSelection(marker)
            case .none:
                break
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditorView
        var isUpdating = false
        var isProcessingAction = false
        weak var textView: MarkdownTextView?

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isUpdating else { return }
            isUpdating = true
            parent.text = textView.string
            applyMarkdownStyling(textView)
            parent.onChange()
            isUpdating = false
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            return false
        }

        // MARK: - Markdown Styling Engine

        func applyMarkdownStyling(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let fullText = storage.string
            let fullRange = NSRange(location: 0, length: storage.length)

            storage.beginEditing()

            let baseFont = NSFont.systemFont(ofSize: 15)
            let baseParagraph = NSMutableParagraphStyle()
            baseParagraph.lineSpacing = 4

            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: baseParagraph,
                .strikethroughStyle: 0
            ], range: fullRange)

            let lines = fullText.components(separatedBy: "\n")
            var lineStart = 0
            var collapsedRanges: [(start: Int, end: Int)] = []

            for (i, line) in lines.enumerated() {
                let lineLength = (line as NSString).length
                let lineRange = NSRange(location: lineStart, length: lineLength)

                styleHeading(storage: storage, line: line, lineRange: lineRange)
                styleBullet(storage: storage, line: line, lineRange: lineRange)
                styleCheckbox(storage: storage, line: line, lineRange: lineRange)
                styleToggle(storage: storage, line: line, lineRange: lineRange)
                styleInlineFormatting(storage: storage, fullText: fullText, lineRange: lineRange)

                let trimmedForToggle = line.drop(while: { $0 == " " })
                let toggleIndent = line.count - trimmedForToggle.count
                if trimmedForToggle.hasPrefix("▶ ") {
                    let childStart = i + 1
                    var childEnd = childStart
                    while childEnd < lines.count {
                        let child = lines[childEnd]
                        let childIndent = child.count - child.drop(while: { $0 == " " }).count
                        if child.isEmpty || childIndent > toggleIndent {
                            childEnd += 1
                        } else {
                            break
                        }
                    }
                    if childEnd > childStart {
                        collapsedRanges.append((childStart, childEnd))
                    }
                }

                lineStart += lineLength + 1
            }

            if !collapsedRanges.isEmpty {
                let hiddenParagraph = NSMutableParagraphStyle()
                hiddenParagraph.maximumLineHeight = 0.01
                hiddenParagraph.minimumLineHeight = 0.01
                hiddenParagraph.lineSpacing = 0
                hiddenParagraph.paragraphSpacing = 0
                hiddenParagraph.paragraphSpacingBefore = 0
                let hiddenAttrs: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: hiddenParagraph,
                    .font: NSFont.systemFont(ofSize: 0.01),
                    .foregroundColor: NSColor.clear
                ]

                var pos = 0
                for (i, line) in lines.enumerated() {
                    let lineLen = (line as NSString).length
                    let isHidden = collapsedRanges.contains { i >= $0.start && i < $0.end }
                    if isHidden {
                        let newlineBefore = pos > 0 ? pos - 1 : pos
                        let hideLen = pos > 0 ? lineLen + 1 : lineLen
                        let hideRange = NSRange(location: newlineBefore, length: min(hideLen, storage.length - newlineBefore))
                        if hideRange.length > 0 {
                            storage.addAttributes(hiddenAttrs, range: hideRange)
                        }
                    }
                    pos += lineLen + 1
                }
            }

            storage.endEditing()
        }

        private func styleHeading(storage: NSTextStorage, line: String, lineRange: NSRange) {
            let level: Int
            let prefixLen: Int
            if line.hasPrefix("### ") {
                level = 3; prefixLen = 4
            } else if line.hasPrefix("## ") {
                level = 2; prefixLen = 3
            } else if line.hasPrefix("# ") {
                level = 1; prefixLen = 2
            } else {
                return
            }

            let fontSize: CGFloat = level == 1 ? 26 : level == 2 ? 22 : 18
            let weight: NSFont.Weight = level <= 2 ? .bold : .semibold
            let headingFont = NSFont.systemFont(ofSize: fontSize, weight: weight)

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            paragraph.paragraphSpacingBefore = level == 1 ? 12 : 8

            storage.addAttributes([
                .font: headingFont,
                .paragraphStyle: paragraph
            ], range: lineRange)

            let prefixRange = NSRange(location: lineRange.location, length: prefixLen)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: prefixRange)
        }

        private func styleBullet(storage: NSTextStorage, line: String, lineRange: NSRange) {
            guard lineRange.length > 0 else { return }
            let trimmed = line.drop(while: { $0 == " " })
            guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else { return }
            if trimmed.hasPrefix("- [") { return }

            let indentSpaces = line.count - trimmed.count
            let depthLevel = indentSpaces / 2
            let indent = CGFloat(20 + indentSpaces * 5)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            paragraph.headIndent = indent
            paragraph.firstLineHeadIndent = CGFloat(indentSpaces * 5)
            storage.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)

            let markerOffset = line.count - trimmed.count
            let markerRange = NSRange(location: lineRange.location + markerOffset, length: 2)
            if markerRange.location + markerRange.length <= lineRange.location + lineRange.length {
                let markerColors: [NSColor] = [.labelColor, .secondaryLabelColor, .tertiaryLabelColor, .quaternaryLabelColor]
                let color = markerColors[min(depthLevel, markerColors.count - 1)]
                let sizes: [CGFloat] = [15, 14, 13, 12]
                let size = sizes[min(depthLevel, sizes.count - 1)]
                storage.addAttributes([
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: size)
                ], range: markerRange)
            }
        }

        private func styleCheckbox(storage: NSTextStorage, line: String, lineRange: NSRange) {
            let trimmed = line.drop(while: { $0 == " " })
            let offset = line.count - trimmed.count

            if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let prefixRange = NSRange(location: lineRange.location + offset, length: 6)
                if prefixRange.location + prefixRange.length <= lineRange.location + lineRange.length {
                    storage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: prefixRange)
                }
                let contentStart = lineRange.location + offset + 6
                let contentLen = lineRange.length - offset - 6
                if contentLen > 0 {
                    let contentRange = NSRange(location: contentStart, length: contentLen)
                    storage.addAttributes([
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: NSColor.tertiaryLabelColor
                    ], range: contentRange)
                }
            } else if trimmed.hasPrefix("- [ ] ") {
                let prefixRange = NSRange(location: lineRange.location + offset, length: 6)
                if prefixRange.location + prefixRange.length <= lineRange.location + lineRange.length {
                    storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: prefixRange)
                }
            }
        }

        private func styleToggle(storage: NSTextStorage, line: String, lineRange: NSRange) {
            let isCollapsed = line.hasPrefix("▶ ")
            let isExpanded = line.hasPrefix("▼ ")
            guard isCollapsed || isExpanded else { return }

            let triangleRange = NSRange(location: lineRange.location, length: 2)
            let triangleColor = isCollapsed ? NSColor.secondaryLabelColor : NSColor.labelColor
            storage.addAttributes([
                .foregroundColor: triangleColor,
                .font: NSFont.systemFont(ofSize: 15, weight: .medium)
            ], range: triangleRange)

            if lineRange.length > 2 {
                let titleRange = NSRange(location: lineRange.location + 2, length: lineRange.length - 2)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .semibold), range: titleRange)
            }
        }

        private func styleInlineFormatting(storage: NSTextStorage, fullText: String, lineRange: NSRange) {
            guard let lineSubstring = (fullText as NSString?)?.substring(with: lineRange) else { return }
            let nsLine = lineSubstring as NSString

            stylePattern(storage: storage, text: nsLine, base: lineRange.location,
                         pattern: "\\*\\*(.+?)\\*\\*", markerLen: 2,
                         innerAttrs: [.font: NSFont.systemFont(ofSize: 15, weight: .bold)])

            let italicDescriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
                .withSymbolicTraits(.italic)
            let italicFont = NSFont(descriptor: italicDescriptor, size: 15) ?? NSFont.systemFont(ofSize: 15)
            stylePattern(storage: storage, text: nsLine, base: lineRange.location,
                         pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", markerLen: 1,
                         innerAttrs: [.font: italicFont])

            styleCodeSpans(storage: storage, text: nsLine, base: lineRange.location)
        }

        private func stylePattern(storage: NSTextStorage, text: NSString, base: Int,
                                  pattern: String, markerLen: Int,
                                  innerAttrs: [NSAttributedString.Key: Any]) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let matches = regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))
            for match in matches {
                let fullRange = NSRange(location: base + match.range.location, length: match.range.length)
                let innerRange = NSRange(location: fullRange.location + markerLen,
                                         length: fullRange.length - markerLen * 2)
                storage.addAttributes(innerAttrs, range: innerRange)

                let openRange = NSRange(location: fullRange.location, length: markerLen)
                let closeRange = NSRange(location: fullRange.location + fullRange.length - markerLen, length: markerLen)
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
            }
        }

        private func styleCodeSpans(storage: NSTextStorage, text: NSString, base: Int) {
            guard let regex = try? NSRegularExpression(pattern: "`(.+?)`") else { return }
            let matches = regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))
            let codeFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let codeBg = NSColor.quaternaryLabelColor
            for match in matches {
                let fullRange = NSRange(location: base + match.range.location, length: match.range.length)
                let innerRange = NSRange(location: fullRange.location + 1, length: fullRange.length - 2)
                storage.addAttributes([.font: codeFont, .backgroundColor: codeBg], range: innerRange)

                let openRange = NSRange(location: fullRange.location, length: 1)
                let closeRange = NSRange(location: fullRange.location + fullRange.length - 1, length: 1)
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
            }
        }
    }
}

// MARK: - Clickable Checkbox Support

final class MarkdownTextView: NSTextView {

    private static let bulletPrefixPattern = try! NSRegularExpression(pattern: "^(\\s*)(- \\[[ xX]\\] |[\\-\\*] |▶ |▼ )")

    override func keyDown(with event: NSEvent) {
        let isTab = event.keyCode == 48
        let isEnter = event.keyCode == 36
        let isShift = event.modifierFlags.contains(.shift)

        if isTab {
            handleTab(indent: !isShift)
            return
        }

        if isEnter && !isShift {
            if handleEnterContinuation() { return }
        }

        super.keyDown(with: event)
    }

    private func handleTab(indent: Bool) {
        let text = string as NSString
        let sel = selectedRange()
        let lineRange = text.lineRange(for: sel)
        let line = text.substring(with: lineRange).replacingOccurrences(of: "\n", with: "")

        if indent {
            textStorage?.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: "  ")
            setSelectedRange(NSRange(location: sel.location + 2, length: 0))
        } else {
            if line.hasPrefix("  ") {
                textStorage?.replaceCharacters(in: NSRange(location: lineRange.location, length: 2), with: "")
                setSelectedRange(NSRange(location: max(sel.location - 2, lineRange.location), length: 0))
            } else if line.hasPrefix(" ") {
                textStorage?.replaceCharacters(in: NSRange(location: lineRange.location, length: 1), with: "")
                setSelectedRange(NSRange(location: max(sel.location - 1, lineRange.location), length: 0))
            }
        }
        didChangeText()
    }

    private func handleEnterContinuation() -> Bool {
        let text = string as NSString
        let sel = selectedRange()
        let lineRange = text.lineRange(for: sel)
        let line = text.substring(with: lineRange).replacingOccurrences(of: "\n", with: "")

        guard let match = Self.bulletPrefixPattern.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) else {
            return false
        }

        let indentRange = match.range(at: 1)
        let prefixRange = match.range(at: 2)
        let indent = (line as NSString).substring(with: indentRange)
        let prefix = (line as NSString).substring(with: prefixRange)

        let contentStart = indentRange.length + prefixRange.length
        let content = String(line.dropFirst(contentStart)).trimmingCharacters(in: .whitespaces)

        if content.isEmpty {
            let fullLineRange = text.lineRange(for: sel)
            textStorage?.replaceCharacters(in: fullLineRange, with: "\n")
            setSelectedRange(NSRange(location: fullLineRange.location + 1, length: 0))
            didChangeText()
            return true
        }

        let newPrefix: String
        if prefix.hasPrefix("- [") {
            newPrefix = "\(indent)- [ ] "
        } else {
            newPrefix = "\(indent)\(prefix)"
        }

        let insertion = "\n\(newPrefix)"
        insertText(insertion, replacementRange: sel)
        didChangeText()
        return true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)
        let text = string as NSString

        if charIndex < text.length {
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            let line = text.substring(with: lineRange)
            let trimmed = line.drop(while: { $0 == " " })
            let offset = line.count - trimmed.count

            if trimmed.hasPrefix("▶ ") && charIndex >= lineRange.location && charIndex < lineRange.location + offset + 2 {
                let triangleRange = NSRange(location: lineRange.location + offset, length: 1)
                textStorage?.replaceCharacters(in: triangleRange, with: "▼")
                didChangeText()
                return
            } else if trimmed.hasPrefix("▼ ") && charIndex >= lineRange.location && charIndex < lineRange.location + offset + 2 {
                let triangleRange = NSRange(location: lineRange.location + offset, length: 1)
                textStorage?.replaceCharacters(in: triangleRange, with: "▶")
                didChangeText()
                return
            }

            if trimmed.hasPrefix("- [ ] ") {
                let bracketStart = lineRange.location + offset + 2
                let bracketRange = NSRange(location: bracketStart, length: 3)
                if charIndex >= lineRange.location + offset && charIndex < lineRange.location + offset + 6 {
                    textStorage?.replaceCharacters(in: bracketRange, with: "[x]")
                    didChangeText()
                    return
                }
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let bracketStart = lineRange.location + offset + 2
                let bracketRange = NSRange(location: bracketStart, length: 3)
                if charIndex >= lineRange.location + offset && charIndex < lineRange.location + offset + 6 {
                    textStorage?.replaceCharacters(in: bracketRange, with: "[ ]")
                    didChangeText()
                    return
                }
            }
        }

        super.mouseDown(with: event)
    }
}

// MARK: - Formatting Actions

extension MarkdownEditorView.Coordinator {
    func toggleLinePrefix(_ prefix: String) {
        guard let textView = textView else { return }
        let text = textView.string as NSString
        let selectedRange = textView.selectedRange()
        guard selectedRange.location <= text.length else { return }
        let lineRange = text.lineRange(for: selectedRange)
        let line = text.substring(with: lineRange).replacingOccurrences(of: "\n", with: "")
        let nsPrefix = prefix as NSString

        isUpdating = true
        if line.hasPrefix(prefix) {
            let removeLen = min(nsPrefix.length, lineRange.length)
            let removeRange = NSRange(location: lineRange.location, length: removeLen)
            textView.textStorage?.replaceCharacters(in: removeRange, with: "")
        } else {
            let allPrefixes = ["# ", "## ", "### ", "- ", "* ", "- [ ] ", "- [x] ", "- [X] ", "▶ ", "▼ "]
            var insertionPoint = lineRange.location
            var removeLen = 0
            for p in allPrefixes {
                if line.hasPrefix(p) {
                    removeLen = (p as NSString).length
                    break
                }
            }
            if removeLen > 0 {
                textView.textStorage?.replaceCharacters(in: NSRange(location: insertionPoint, length: removeLen), with: prefix)
            } else {
                textView.insertText(prefix, replacementRange: NSRange(location: insertionPoint, length: 0))
            }
        }
        parent.text = textView.string
        applyMarkdownStyling(textView)
        parent.onChange()
        isUpdating = false
    }

    func wrapSelection(_ marker: String) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else { return }
        let text = textView.string as NSString
        let selected = text.substring(with: selectedRange)

        isUpdating = true
        if selected.hasPrefix(marker) && selected.hasSuffix(marker) && selected.count > marker.count * 2 {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            textView.textStorage?.replaceCharacters(in: selectedRange, with: inner)
        } else {
            let wrapped = "\(marker)\(selected)\(marker)"
            textView.textStorage?.replaceCharacters(in: selectedRange, with: wrapped)
        }
        parent.text = textView.string
        applyMarkdownStyling(textView)
        parent.onChange()
        isUpdating = false
    }
}
#endif
