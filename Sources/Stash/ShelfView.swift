import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct NotchTabStrip: View {
    @ObservedObject var workspace: NotchShelfController
    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workspace.tabs) { shelf in
                        HStack(spacing: 4) {
                            Button { workspace.selectTab(shelf.id) } label: {
                                HStack(spacing: 3) {
                                    if shelf.isPinned { Image(systemName: "pin.fill") }
                                    Text(shelf.title).lineLimit(1)
                                    Text("\(shelf.items.count)").foregroundStyle(.secondary)
                                }
                            }.accessibilityLabel("Open \(shelf.title), \(shelf.items.count) items")
                            Button { workspace.closeTab(shelf.id) } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                                .help(shelf.isPinned ? "Close tab; pinned Stash stays saved" : "Close Stash tab")
                                .accessibilityLabel("Close \(shelf.title)")
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.primary.opacity(workspace.selectedTabID == shelf.id ? 0.13 : 0.04), in: Capsule())
                    }
                }
            }
            Button { workspace.newTab() } label: { Image(systemName: "plus") }
                .help("New Stash").accessibilityLabel("New Stash tab")
        }.buttonStyle(.borderless).font(.caption).frame(height: 28)
    }
}

struct ShelfView: View {
    @ObservedObject var controller: ShelfWindowController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @ObservedObject private var preferences = NotchPreferences.shared
    @State private var isTargeted = false
    @State private var isShelfHovered = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var activeAction: SmartActionID?
    @FocusState private var isTitleFocused: Bool
    private var columns: [GridItem] {
        if controller.isNotchShelf {
            // The notch shelf deliberately fills across before it grows down:
            // three tiles at rest, then four through six on the same row.
            let count = min(max(controller.shelf.items.count, 1), 6)
            return Array(repeating: GridItem(.flexible(minimum: 82, maximum: 108), spacing: 8), count: count)
        }
        return [GridItem(.adaptive(minimum: 82, maximum: 108), spacing: 8)]
    }

    var body: some View {
        VStack(spacing: 8) {
            if controller.isNotchShelf { Color.clear.frame(height: 18).accessibilityHidden(true) }
            shelfHeader
            if let workspace = controller.notchWorkspace { NotchTabStrip(workspace: workspace) }
            shelfContent
            shelfFooter
        }
        .padding(11)
        .frame(minWidth: 326, idealWidth: 346, maxWidth: .infinity, minHeight: 176, idealHeight: 196, maxHeight: .infinity)
        .background(glassShell)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scaleEffect(isTargeted && motionEnabled ? 1.008 : 1)
        .shadow(color: .black.opacity(isTargeted ? 0.22 : 0.15), radius: isTargeted ? 18 : 13, x: 0, y: isTargeted ? 8 : 6)
        .padding(EdgeInsets(top: controller.isNotchShelf ? 0 : 7, leading: 7, bottom: 7, trailing: 7))
        .onHover { isShelfHovered = $0; controller.updatePointerInside($0) }
        .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: $isTargeted, perform: controller.acceptDrop)
        .animation(reduceMotion ? nil : StashMotion.shelf(preferences.animationIntensity), value: isTargeted)
        .animation(reduceMotion ? nil : StashMotion.insertion(preferences.animationIntensity), value: controller.shelf.items.map(\.id))
        .ignoresSafeArea()
        .sheet(item: $activeAction) { action in
            if action == .createZip { ArchiveActionSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else if action == .batchRename { BatchRenameSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else if action == .mergePDFs { PDFMergeSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else { ImageActionSheet(action: action, selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
        }
    }

    private var shelfHeader: some View {
        VStack(spacing: 4) {
            if !controller.isNotchShelf {
                ShelfWindowDragHandle()
                    .frame(width: 38, height: 6)
                    .help("Drag to move shelf")
                    .accessibilityLabel("Move shelf")
            }
            HStack(spacing: 6) {
                if controller.isNotchShelf {
                    Text(controller.shelf.title).font(.callout.weight(.semibold)).lineLimit(1).accessibilityAddTraits(.isHeader)
                    Button { controller.togglePin() } label: { Image(systemName: controller.shelf.isPinned ? "pin.fill" : "pin") }
                        .buttonStyle(GlassIconButtonStyle(emphasized: controller.shelf.isPinned))
                        .help(controller.shelf.isPinned ? "Unpin Stash" : "Save Stash for next launch")
                        .accessibilityLabel(controller.shelf.isPinned ? "Unpin Stash" : "Pin Stash")
                } else {
                    TextField("Shelf name", text: $controller.shelf.title)
                        .textFieldStyle(.plain).font(.callout.weight(.semibold)).accessibilityLabel("Shelf name")
                        .focused($isTitleFocused)
                        .onSubmit {
                            controller.persistIfNeeded()
                            isTitleFocused = false
                        }
                }
                Spacer(minLength: 2)
                Text("\(controller.shelf.items.count)")
                    .font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.primary.opacity(0.065), in: Capsule())
                    .accessibilityLabel("\(controller.shelf.items.count) items")
                Menu {
                    let actions = controller.availableActions(for: selectedIDs)
                    if actions.isEmpty { Text(selectedIDs.isEmpty ? "Select files to see actions" : "No actions for this selection") }
                    else { ForEach(actions) { action in Button(action.title) { activeAction = action.id } } }
                } label: { Image(systemName: "sparkles").frame(width: 24, height: 24).background(Color.primary.opacity(0.055), in: Circle()) }
                    .menuStyle(.borderlessButton).fixedSize().disabled(controller.isPerformingAction || controller.shelf.items.isEmpty)
                    .help("Smart Actions").accessibilityLabel("Actions for selected items")
                if !controller.isNotchShelf {
                    Button { controller.toggleExpansion() } label: { Image(systemName: controller.isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(GlassIconButtonStyle()).help(controller.isExpanded ? "Restore previous shelf size" : "Expand shelf")
                        .accessibilityLabel(controller.isExpanded ? "Restore previous shelf size" : "Expand shelf")
                    Button { controller.togglePin() } label: { Image(systemName: controller.shelf.isPinned ? "pin.fill" : "pin") }
                        .buttonStyle(GlassIconButtonStyle(emphasized: controller.shelf.isPinned)).help(controller.shelf.isPinned ? "Unpin shelf" : "Pin shelf")
                        .accessibilityLabel(controller.shelf.isPinned ? "Unpin shelf" : "Pin shelf")
                }
                Button { controller.dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(GlassIconButtonStyle()).help("Dismiss shelf").accessibilityLabel("Dismiss shelf")
            }
        }
    }

    @ViewBuilder private var shelfContent: some View {
        if controller.shelf.items.isEmpty {
            VStack(spacing: 5) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 23, weight: .light)).foregroundStyle(isTargeted ? Color.indigo : Color.secondary)
                Text(isTargeted ? "Release to stash" : "Drop files here").font(.callout.weight(.semibold))
                Text("Files, folders, text or links").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(Color.primary.opacity(isTargeted ? 0.065 : 0.028), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(controller.shelf.items) { item in
                        ShelfItemTile(
                            item: item,
                            isSelected: selectedIDs.contains(item.id),
                            select: { toggleSelection(item.id) },
                            remove: { selectedIDs.remove(item.id); controller.remove(item) },
                            preview: { controller.preview(selectedIDs: [item.id]) },
                            reveal: { controller.revealInFinder(selectedIDs: [item.id]) },
                            copyPath: { controller.copyPaths(selectedIDs: [item.id]) },
                            beginDrag: controller.noteItemDragStarted
                        )
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }.padding(.horizontal, 2).padding(.vertical, 3)
            }
            .scrollIndicators(.automatic)
            .frame(minHeight: 72, maxHeight: .infinity)
            .layoutPriority(1)
            .clipped()
        }
    }

    private var shelfFooter: some View {
        VStack(spacing: 4) {
            if controller.isPerformingAction { ProgressView("Working…").controlSize(.small).frame(maxWidth: .infinity, alignment: .leading) }
            if let message = controller.actionMessage { Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel("Action status: \(message)") }
            if !selectedIDs.isEmpty {
                HStack(spacing: 10) {
                    Button { controller.preview(selectedIDs: selectedIDs) } label: { Label("Preview", systemImage: "eye") }
                        .disabled(selectedFileIDs.isEmpty).keyboardShortcut(.space, modifiers: [])
                    Button { controller.revealInFinder(selectedIDs: selectedIDs) } label: { Label("Reveal", systemImage: "folder") }
                        .disabled(selectedFileIDs.isEmpty)
                    Button { controller.copyPaths(selectedIDs: selectedIDs) } label: { Label("Copy Path", systemImage: "doc.on.doc") }
                        .disabled(selectedFileIDs.isEmpty)
                    Spacer()
                }
                .font(.caption).buttonStyle(.borderless)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            HStack {
                Button { selectedIDs.removeAll(); controller.clear() } label: { Label("Clear", systemImage: "trash") }
                    .buttonStyle(.borderless).disabled(controller.shelf.items.isEmpty)
                Spacer()
                if !selectedIDs.isEmpty { Text("\(selectedIDs.count) selected").font(.caption.weight(.medium)).foregroundStyle(.indigo) }
                Text("⌃⌥Space").font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
        }
    }

    private var selectedFileIDs: Set<UUID> {
        Set(controller.shelf.items.filter { selectedIDs.contains($0.id) && $0.fileURL != nil && $0.isAvailable }.map(\.id))
    }

    private var motionEnabled: Bool { !reduceMotion && preferences.animationIntensity != .off }

    private var glassShell: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.regularMaterial)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(nsColor: .windowBackgroundColor).opacity(colorSchemeContrast == .increased ? 0.82 : 0.64)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LinearGradient(colors: [.white.opacity(isShelfHovered ? 0.09 : 0.055), .clear, .indigo.opacity(isTargeted ? 0.08 : 0.012)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(isTargeted ? Color.indigo.opacity(0.78) : Color.primary.opacity(colorSchemeContrast == .increased ? 0.30 : 0.14), lineWidth: isTargeted || differentiateWithoutColor ? 1.5 : 0.75))
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
}

private struct ShelfWindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> ShelfWindowDragNSView { ShelfWindowDragNSView() }
    func updateNSView(_ nsView: ShelfWindowDragNSView, context: Context) {}
}

private final class ShelfWindowDragNSView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 2, yRadius: 2).fill()
    }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

private enum StashMotion {
    static func hover(_ intensity: NotchAnimationIntensity) -> Animation? { animation(intensity, response: 0.18, damping: 0.86) }
    static func selection(_ intensity: NotchAnimationIntensity) -> Animation? { animation(intensity, response: 0.22, damping: 0.84) }
    static func insertion(_ intensity: NotchAnimationIntensity) -> Animation? { animation(intensity, response: 0.28, damping: 0.82) }
    static func shelf(_ intensity: NotchAnimationIntensity) -> Animation? { animation(intensity, response: 0.30, damping: 0.88) }
    private static func animation(_ intensity: NotchAnimationIntensity, response: Double, damping: Double) -> Animation? {
        switch intensity {
        case .off: return nil
        case .subtle: return .easeOut(duration: min(response, 0.18))
        case .standard: return .spring(response: response, dampingFraction: damping)
        }
    }
}

private struct GlassIconButtonStyle: ButtonStyle {
    var emphasized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 24, height: 24)
            .foregroundStyle(emphasized ? Color.indigo : Color.primary.opacity(0.82))
            .background(Color.primary.opacity(configuration.isPressed ? 0.15 : 0.07), in: Circle())
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.94 : 1)
    }
}

private struct PDFMergeSheet: View {
    let selectedIDs: Set<UUID>
    @ObservedObject var controller: ShelfWindowController
    let onSubmitted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inputs: [PDFInputInfo] = []
    @State private var outputName = "Merged Document"
    @State private var destination: OutputDestination = .currentShelf

    private var valid: Bool { inputs.count >= 2 && inputs.allSatisfy(\.isValid) && !outputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Merge PDFs").font(.title3.bold())
            Text("Pages are merged in this order. Source PDFs are never changed.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(inputs.enumerated()), id: \.element.id) { index, input in
                        HStack(spacing: 8) {
                            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(input.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                if input.isValid {
                                    Text("\(input.pageCount) page\(input.pageCount == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text(input.validationMessage ?? "Invalid PDF").font(.caption).foregroundStyle(.red)
                                }
                            }
                            Spacer()
                            Button { move(from: index, to: index - 1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.borderless).disabled(index == 0).help("Move document earlier")
                            Button { move(from: index, to: index + 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.borderless).disabled(index == inputs.count - 1).help("Move document later")
                        }.padding(7).background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }.frame(height: 190)
            Text("Output filename").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField("Merged Document", text: $outputName).textFieldStyle(.roundedBorder)
            Text(".pdf is added automatically. Output uses durable Stash storage before any export.").font(.caption).foregroundStyle(.secondary)
            Picker("Result", selection: $destination) { ForEach(OutputDestination.allCases) { Text($0.title).tag($0) } }
            if !valid, !inputs.isEmpty { Text(inputs.first(where: { !$0.isValid })?.validationMessage ?? "Enter an output name and select at least two valid PDFs.").font(.caption).foregroundStyle(.red) }
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Merge PDFs") { controller.performPDFMerge(orderedInputs: inputs.map(\.url), request: PDFMergeRequest(outputName: outputName), destination: destination); onSubmitted(); dismiss() }.keyboardShortcut(.defaultAction).disabled(!valid) }
        }
        .stashActionPanel(width: 520)
        .onAppear { inputs = controller.pdfInputs(selectedIDs: selectedIDs) }
    }

    private func move(from source: Int, to target: Int) {
        guard source != target, inputs.indices.contains(source), inputs.indices.contains(target) else { return }
        let item = inputs.remove(at: source); inputs.insert(item, at: target)
    }
}

private struct BatchRenameSheet: View {
    let selectedIDs: Set<UUID>
    @ObservedObject var controller: ShelfWindowController
    let onSubmitted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = RenameConfiguration()
    @State private var showConfirmation = false

    private var plan: RenamePlan { controller.renamePlan(selectedIDs: selectedIDs, configuration: configuration) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Batch Rename").font(.title3.bold())
            Text("Renames originals in place. Stash will not overwrite existing files.").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                labeledField("Prefix", text: $configuration.prefix)
                labeledField("Suffix", text: $configuration.suffix)
            }
            HStack(alignment: .top, spacing: 12) {
                labeledField("Find", text: $configuration.find)
                labeledField("Replace", text: $configuration.replace)
            }
            Toggle("Match case", isOn: $configuration.caseSensitive).font(.caption)
            Toggle("Sequential numbering", isOn: $configuration.sequentialNumbering)
            if configuration.sequentialNumbering {
                HStack {
                    TextField("Start", value: $configuration.startingNumber, format: .number).frame(width: 80)
                    TextField("Increment", value: $configuration.increment, format: .number).frame(width: 95)
                    TextField("Padding", value: $configuration.zeroPadding, format: .number).frame(width: 85)
                    TextField("Separator", text: $configuration.numberSeparator).frame(width: 80)
                }.font(.caption)
            }
            HStack { Text("Original filename").frame(maxWidth: .infinity, alignment: .leading); Text("Proposed filename").frame(maxWidth: .infinity, alignment: .leading) }
                .font(.caption.bold()).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(plan.entries) { entry in
                        HStack(alignment: .top, spacing: 10) {
                            Text(entry.originalName).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.proposedName).lineLimit(1).truncationMode(.middle).foregroundStyle(entry.changesName ? .primary : .secondary)
                                if let error = entry.error { Text(error).font(.caption2).foregroundStyle(.red) }
                                else if !entry.changesName { Text("Unchanged").font(.caption2).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(.vertical, 3)
                    }
                }
            }.frame(height: 180).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            Text(plan.isValid ? "\(plan.changedCount) of \(plan.entries.count) item(s) will be renamed." : (plan.errors.first ?? "The rename plan is invalid."))
                .font(.caption).foregroundStyle(plan.isValid ? Color.secondary : Color.red)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Review Rename…") { showConfirmation = true }.keyboardShortcut(.defaultAction).disabled(!plan.isValid || plan.changedCount == 0) }
        }
        .stashActionPanel(width: 650)
        .confirmationDialog("Rename \(plan.changedCount) original item(s)?", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("Rename Originals", role: .destructive) { controller.performRenameAction(selectedIDs: selectedIDs, configuration: configuration); onSubmitted(); dismiss() }
        } message: {
            Text("This changes the selected filenames in Finder. The operation is staged to avoid overwriting files.")
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.roundedBorder)
        }
    }
}

private struct ArchiveActionSheet: View {
    let selectedIDs: Set<UUID>
    @ObservedObject var controller: ShelfWindowController
    let onSubmitted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Stash Archive"
    @State private var omitTopLevel = false
    @State private var destination: OutputDestination = .currentShelf

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create ZIP").font(.title3.bold())
            Text("Archive name").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField("Stash Archive", text: $name).textFieldStyle(.roundedBorder)
            Text(".zip is added automatically. Names cannot contain path separators or '..'.").font(.caption).foregroundStyle(.secondary)
            Toggle("Omit the selected folder’s top level", isOn: $omitTopLevel)
            Text("Available only for a single selected folder; its contents remain structured.").font(.caption).foregroundStyle(.secondary)
            Text("Compression: Default (libarchive ZIP)").font(.callout)
            Picker("Result", selection: $destination) { ForEach(OutputDestination.allCases) { Text($0.title).tag($0) } }
            Text("Source files are read only. Stash rejects symbolic links and verifies the ZIP before showing it.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Create") { controller.performArchiveAction(selectedIDs: selectedIDs, request: ArchiveRequest(archiveName: name, omitSingleTopLevelFolder: omitTopLevel), destination: destination); onSubmitted(); dismiss() }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.stashActionPanel(width: 440)
    }
}

private struct ShelfItemTile: View {
    let item: ShelfItem
    let isSelected: Bool
    let select: () -> Void
    let remove: () -> Void
    let preview: () -> Void
    let reveal: () -> Void
    let copyPath: () -> Void
    let beginDrag: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @ObservedObject private var preferences = NotchPreferences.shared
    @State private var isHovering = false
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                FileThumbnailView(item: item, size: 48).foregroundStyle(item.isAvailable ? Color.accentColor : Color.red)
                    .shadow(color: .black.opacity(isHovering ? 0.22 : 0.10), radius: isHovering ? 5 : 2, y: isHovering ? 3 : 1)
                    .frame(maxWidth: .infinity)
                if isHovering || isSelected {
                    Button(action: remove) { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical) }
                        .buttonStyle(.borderless)
                        .help("Remove from shelf").accessibilityLabel("Remove \(item.displayName) from shelf")
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            Text(item.displayName)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
            if !item.isAvailable { Text("Missing").font(.caption2).foregroundStyle(.red) }
        }
        .padding(7)
        .frame(minHeight: 82, maxHeight: item.isAvailable ? 88 : 102, alignment: .top)
        .background(tileBackground)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(borderColor, lineWidth: isSelected || differentiateWithoutColor ? 1.6 : 0.8))
        .shadow(color: .black.opacity(isHovering || isSelected ? 0.18 : 0.07), radius: isHovering || isSelected ? 9 : 3, y: isHovering || isSelected ? 5 : 2)
        .scaleEffect(motionEnabled && isHovering ? 1.03 : 1)
        .offset(y: motionEnabled && (isHovering || isSelected) ? -1.5 : 0)
        .contentShape(Rectangle()).onTapGesture(perform: select)
        .onDrag { beginDrag(); return dragProvider(for: item) }
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : StashMotion.hover(preferences.animationIntensity), value: isHovering)
        .animation(reduceMotion ? nil : StashMotion.selection(preferences.animationIntensity), value: isSelected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.displayName), \(item.kind.rawValue)\(item.isAvailable ? "" : ", missing")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Remove from Shelf", remove)
        .help(item.displayName)
        .contextMenu {
            if item.fileURL != nil && item.isAvailable {
                Button("Quick Look", action: preview)
                Button("Reveal in Finder", action: reveal)
                Button("Copy Path", action: copyPath)
                Divider()
            }
            Button("Remove from Shelf", role: .destructive, action: remove)
        }
    }

    private var motionEnabled: Bool { !reduceMotion && preferences.animationIntensity != .off }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(isSelected ? AnyShapeStyle(Color.indigo.opacity(0.18)) : AnyShapeStyle(.thinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(isHovering ? 0.10 : 0.035)))
    }

    private var borderColor: Color {
        if isSelected { return .indigo.opacity(0.92) }
        if !item.isAvailable { return .red.opacity(0.65) }
        return .white.opacity(isHovering ? 0.42 : 0.20)
    }

    private func dragProvider(for item: ShelfItem) -> NSItemProvider {
        switch item.kind {
        case .file: return NSItemProvider(object: item.fileURL! as NSURL)
        case .url: return NSItemProvider(object: URL(string: item.value)! as NSURL)
        case .text: return NSItemProvider(object: item.value as NSString)
        }
    }
}

private struct ImageActionSheet: View {
    let action: SmartActionID
    let selectedIDs: Set<UUID>
    @ObservedObject var controller: ShelfWindowController
    let onSubmitted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var format: ImageOutputFormat = .png
    @State private var sizeText = "1600"
    @State private var resizeMode: ImageResizeMode = .maximumWidth
    @State private var jpegQuality = 0.9
    @State private var stripMetadata = false
    @State private var destination: OutputDestination = .currentShelf

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(action == .convertImages ? "Convert Images" : "Resize Images").font(.title3.bold())
            if action == .convertImages { Picker("Format", selection: $format) { ForEach(ImageOutputFormat.available) { Text($0.title).tag($0) } } }
            if action == .resizeImages {
                Picker("Resize", selection: $resizeMode) { ForEach(ImageResizeMode.allCases) { Text($0.title).tag($0) } }
                HStack { Text(resizeMode == .percentage ? "Scale (%)" : "Pixels"); TextField("1600", text: $sizeText).frame(width: 90) }
            }
            if format == .jpeg { HStack { Text("JPEG quality"); Slider(value: $jpegQuality, in: 0.1...1) } }
            if format == .jpeg { Text("JPEG does not preserve transparency.").font(.caption).foregroundStyle(.orange) }
            Toggle("Strip metadata", isOn: $stripMetadata)
            Picker("Result", selection: $destination) { ForEach(OutputDestination.allCases) { Text($0.title).tag($0) } }
            Text("Generated files are stored safely in Stash’s Application Support folder. Sources are never changed.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Run") { run(); dismiss() }.keyboardShortcut(.defaultAction) }
        }.stashActionPanel(width: 430)
        .onAppear { if !ImageOutputFormat.available.contains(format) { format = ImageOutputFormat.available.first ?? .png } }
    }

    private func run() {
        let value = Double(sizeText).flatMap { $0 > 0 ? $0 : nil }
        let request = ImageActionRequest(format: format, resizeMode: action == .resizeImages ? resizeMode : nil, resizeValue: action == .resizeImages ? value : nil, jpegQuality: jpegQuality, stripMetadata: stripMetadata, allowUpscaling: false)
        controller.performImageAction(selectedIDs: selectedIDs, request: request, destination: destination)
        onSubmitted()
    }
}

private struct StashActionPanelModifier: ViewModifier {
    let width: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(width: width)
            .background(.regularMaterial)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.24), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
    }
}

private extension View {
    func stashActionPanel(width: CGFloat) -> some View { modifier(StashActionPanelModifier(width: width)) }
}
