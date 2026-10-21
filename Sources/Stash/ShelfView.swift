import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var controller: ShelfWindowController
    @State private var isTargeted = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var activeAction: SmartActionID?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Shelf name", text: $controller.shelf.title)
                    .textFieldStyle(.plain).font(.headline)
                    .onSubmit { controller.persistIfNeeded() }
                Spacer()
                Text("\(controller.shelf.items.count)").foregroundStyle(.secondary)
                Button { controller.togglePin() } label: { Image(systemName: controller.shelf.isPinned ? "pin.fill" : "pin") }
                    .help(controller.shelf.isPinned ? "Unpin shelf" : "Pin shelf")
                Button { controller.dismiss() } label: { Image(systemName: "xmark.circle.fill") }.help("Dismiss shelf")
            }

            if controller.shelf.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down").font(.largeTitle)
                    Text("Drop files, text, or links here").font(.headline)
                    Text("Items remain references; Stash does not copy your files.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, minHeight: 130)
            } else {
                ScrollView { LazyVStack(spacing: 6) { ForEach(controller.shelf.items) { item in ShelfItemRow(item: item, isSelected: selectedIDs.contains(item.id), select: { toggleSelection(item.id) }, remove: { selectedIDs.remove(item.id); controller.remove(item) }) } } }
                    .frame(maxHeight: 260)
            }

            HStack {
                Button("Clear") { controller.clear() }.disabled(controller.shelf.items.isEmpty)
                Spacer()
                Menu("Actions") {
                    let actions = controller.availableActions(for: selectedIDs)
                    if actions.isEmpty { Text(selectedIDs.isEmpty ? "Select image files first" : "No actions for this selection") }
                    else { ForEach(actions) { action in Button(action.title) { activeAction = action.id } } }
                }.disabled(controller.isPerformingAction || controller.shelf.items.isEmpty)
                Text("⌃⌥Space creates a shelf").font(.caption).foregroundStyle(.secondary)
            }
            if controller.isPerformingAction { ProgressView("Working…").controlSize(.small) }
            if let message = controller.actionMessage { Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
        }
        .padding(14).frame(width: 330)
        .background(.regularMaterial)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isTargeted ? Color.accentColor : .white.opacity(0.12), lineWidth: isTargeted ? 3 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: $isTargeted, perform: controller.acceptDrop)
        .sheet(item: $activeAction) { action in
            if action == .createZip { ArchiveActionSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else if action == .batchRename { BatchRenameSheet(selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
            else { ImageActionSheet(action: action, selectedIDs: selectedIDs, controller: controller, onSubmitted: { selectedIDs.removeAll() }) }
        }
    }

    private func toggleSelection(_ id: UUID) { if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) } }
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
            HStack { TextField("Prefix", text: $configuration.prefix); TextField("Suffix", text: $configuration.suffix) }
            HStack { TextField("Find", text: $configuration.find); TextField("Replace", text: $configuration.replace) }
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
        .padding().frame(width: 650)
        .confirmationDialog("Rename \(plan.changedCount) original item(s)?", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("Rename Originals", role: .destructive) { controller.performRenameAction(selectedIDs: selectedIDs, configuration: configuration); onSubmitted(); dismiss() }
        } message: {
            Text("This changes the selected filenames in Finder. The operation is staged to avoid overwriting files.")
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
            TextField("Archive name", text: $name).textFieldStyle(.roundedBorder)
            Text(".zip is added automatically. Names cannot contain path separators or '..'.").font(.caption).foregroundStyle(.secondary)
            Toggle("Omit the selected folder’s top level", isOn: $omitTopLevel)
            Text("Available only for a single selected folder; its contents remain structured.").font(.caption).foregroundStyle(.secondary)
            Text("Compression: Default (libarchive ZIP)").font(.callout)
            Picker("Result", selection: $destination) { ForEach(OutputDestination.allCases) { Text($0.title).tag($0) } }
            Text("Source files are read only. Stash rejects symbolic links and verifies the ZIP before showing it.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Create") { controller.performArchiveAction(selectedIDs: selectedIDs, request: ArchiveRequest(archiveName: name, omitSingleTopLevelFolder: omitTopLevel), destination: destination); onSubmitted(); dismiss() }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding().frame(width: 440)
    }
}

private struct ShelfItemRow: View {
    let item: ShelfItem
    let isSelected: Bool
    let select: () -> Void
    let remove: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbolName).frame(width: 20).foregroundStyle(item.isAvailable ? Color.accentColor : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).lineLimit(1)
                Text(item.kind.rawValue.capitalized + (item.isAvailable ? "" : " · Missing")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: remove) { Image(systemName: "minus.circle") }.buttonStyle(.borderless).help("Remove from shelf")
        }
        .padding(8).background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.22)) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle()).onTapGesture(perform: select)
        .onDrag { dragProvider(for: item) }
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
        }.padding().frame(width: 430)
        .onAppear { if !ImageOutputFormat.available.contains(format) { format = ImageOutputFormat.available.first ?? .png } }
    }

    private func run() {
        let value = Double(sizeText).flatMap { $0 > 0 ? $0 : nil }
        let request = ImageActionRequest(format: format, resizeMode: action == .resizeImages ? resizeMode : nil, resizeValue: action == .resizeImages ? value : nil, jpegQuality: jpegQuality, stripMetadata: stripMetadata, allowUpscaling: false)
        controller.performImageAction(selectedIDs: selectedIDs, request: request, destination: destination)
        onSubmitted()
    }
}
