import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var controller: ShelfWindowController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var isTargeted = false
    @State private var isShelfHovered = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var activeAction: SmartActionID?
    private let columns = [GridItem(.adaptive(minimum: 94, maximum: 128), spacing: 10)]

    var body: some View {
        VStack(spacing: 13) {
            shelfHeader
            shelfContent
            shelfFooter
        }
        .padding(16)
        .frame(minWidth: 340, idealWidth: 420, maxWidth: .infinity, minHeight: 250, idealHeight: 360, maxHeight: .infinity)
        .background(glassShell)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scaleEffect(isTargeted && !reduceMotion ? 1.008 : 1)
        .shadow(color: .black.opacity(isTargeted ? 0.28 : 0.20), radius: isTargeted ? 30 : 22, x: 0, y: isTargeted ? 14 : 10)
        .padding(12)
        .onHover { isShelfHovered = $0 }
        .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: $isTargeted, perform: controller.acceptDrop)
        .animation(reduceMotion ? nil : StashMotion.shelf, value: isTargeted)
        .animation(reduceMotion ? nil : StashMotion.insertion, value: controller.shelf.items.map(\.id))
        .ignoresSafeArea()
        .sheet(item: $activeAction) { action in
            if action == .createZip { ArchiveActionSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else if action == .batchRename { BatchRenameSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else if action == .mergePDFs { PDFMergeSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else { ImageActionSheet(action: action, selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
        }
    }

    private var shelfHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.full.fill").foregroundStyle(.indigo).imageScale(.large).accessibilityHidden(true)
            TextField("Shelf name", text: $controller.shelf.title)
                .textFieldStyle(.plain).font(.headline.weight(.semibold)).accessibilityLabel("Shelf name")
                .onSubmit { controller.persistIfNeeded() }
            Text("\(controller.shelf.items.count)")
                .font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4).background(.thinMaterial, in: Capsule())
                .accessibilityLabel("\(controller.shelf.items.count) items")
            Menu {
                let actions = controller.availableActions(for: selectedIDs)
                if actions.isEmpty { Text(selectedIDs.isEmpty ? "Select files to see actions" : "No actions for this selection") }
                else { ForEach(actions) { action in Button(action.title) { activeAction = action.id } } }
            } label: { Image(systemName: "sparkles") }
                .menuStyle(.borderlessButton).fixedSize().disabled(controller.isPerformingAction || controller.shelf.items.isEmpty)
                .help("Smart Actions").accessibilityLabel("Actions for selected items")
            Button { controller.togglePin() } label: { Image(systemName: controller.shelf.isPinned ? "pin.fill" : "pin") }
                .buttonStyle(GlassIconButtonStyle(emphasized: controller.shelf.isPinned)).help(controller.shelf.isPinned ? "Unpin shelf" : "Pin shelf")
                .accessibilityLabel(controller.shelf.isPinned ? "Unpin shelf" : "Pin shelf")
            Button { controller.dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(GlassIconButtonStyle()).help("Dismiss shelf").accessibilityLabel("Dismiss shelf")
        }
    }

    @ViewBuilder private var shelfContent: some View {
        if controller.shelf.items.isEmpty {
            VStack(spacing: 9) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 30, weight: .light)).foregroundStyle(isTargeted ? Color.indigo : Color.secondary)
                Text(isTargeted ? "Release to stash" : "Drop files here").font(.headline)
                Text("Files, folders, text or links").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 145)
            .background(Color.primary.opacity(isTargeted ? 0.07 : 0.035), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(controller.shelf.items) { item in
                        ShelfItemTile(item: item, isSelected: selectedIDs.contains(item.id), select: { toggleSelection(item.id) }, remove: { selectedIDs.remove(item.id); controller.remove(item) })
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }.padding(2)
            }
            .scrollIndicators(.automatic)
            .frame(maxHeight: .infinity)
        }
    }

    private var shelfFooter: some View {
        VStack(spacing: 7) {
            if controller.isPerformingAction { ProgressView("Working…").controlSize(.small).frame(maxWidth: .infinity, alignment: .leading) }
            if let message = controller.actionMessage { Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel("Action status: \(message)") }
            HStack {
                Button { selectedIDs.removeAll(); controller.clear() } label: { Label("Clear", systemImage: "trash") }
                    .buttonStyle(.borderless).disabled(controller.shelf.items.isEmpty)
                Spacer()
                if !selectedIDs.isEmpty { Text("\(selectedIDs.count) selected").font(.caption.weight(.medium)).foregroundStyle(.indigo) }
                Text("⌃⌥Space").font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
        }
    }

    private var glassShell: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(LinearGradient(colors: [.white.opacity(isShelfHovered ? 0.13 : 0.08), .clear, .indigo.opacity(isTargeted ? 0.12 : 0.025)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(LinearGradient(colors: [isTargeted ? .indigo.opacity(0.9) : .white.opacity(0.48), .white.opacity(0.08), isTargeted ? .indigo.opacity(0.55) : .black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isTargeted || differentiateWithoutColor ? 2 : 1))
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
}

private enum StashMotion {
    static let hover = Animation.spring(response: 0.18, dampingFraction: 0.86)
    static let selection = Animation.spring(response: 0.22, dampingFraction: 0.84)
    static let insertion = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let shelf = Animation.spring(response: 0.30, dampingFraction: 0.88)
}

private struct GlassIconButtonStyle: ButtonStyle {
    var emphasized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var isHovering = false
    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                icon.frame(width: 42, height: 42).foregroundStyle(item.isAvailable ? Color.accentColor : Color.red)
                    .shadow(color: .black.opacity(isHovering ? 0.22 : 0.10), radius: isHovering ? 5 : 2, y: isHovering ? 3 : 1)
                    .frame(maxWidth: .infinity)
                Button(action: remove) { Image(systemName: "minus.circle.fill").symbolRenderingMode(.hierarchical) }
                    .buttonStyle(.borderless).opacity(isHovering ? 1 : 0.58)
                    .help("Remove from shelf").accessibilityLabel("Remove \(item.displayName) from shelf")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.caption.weight(.medium)).lineLimit(2).truncationMode(.middle).multilineTextAlignment(.leading)
                Text(item.kind.rawValue.capitalized + (item.isAvailable ? "" : " · Missing")).font(.caption2).foregroundStyle(item.isAvailable ? Color.secondary : Color.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(minHeight: 96, maxHeight: 112, alignment: .top)
        .background(tileBackground)
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(borderColor, lineWidth: isSelected || differentiateWithoutColor ? 1.6 : 0.8))
        .shadow(color: .black.opacity(isHovering || isSelected ? 0.18 : 0.07), radius: isHovering || isSelected ? 9 : 3, y: isHovering || isSelected ? 5 : 2)
        .scaleEffect(!reduceMotion && isHovering ? 1.03 : 1)
        .offset(y: !reduceMotion && (isHovering || isSelected) ? -1.5 : 0)
        .contentShape(Rectangle()).onTapGesture(perform: select)
        .onDrag { dragProvider(for: item) }
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : StashMotion.hover, value: isHovering)
        .animation(reduceMotion ? nil : StashMotion.selection, value: isSelected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.displayName), \(item.kind.rawValue)\(item.isAvailable ? "" : ", missing")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(item.displayName)
    }

    @ViewBuilder private var icon: some View {
        if let url = item.fileURL { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit() }
        else { Image(systemName: item.symbolName) }
    }

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
