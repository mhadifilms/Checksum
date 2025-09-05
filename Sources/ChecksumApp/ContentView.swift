import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = CloneViewModel()
    @State private var isSourceDropTargeted = false
    @State private var isDestDropTargeted = false
    @State private var showHistory = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LiquidGlassBackground()
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    mainContentSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // History drawer as overlay sidebar
                if showHistory {
                    HStack {
                        Spacer()
                        historyDrawer
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                    .padding(.trailing, 20)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onReceive(NotificationCenter.default.publisher(for: .init("ClearInputs"))) { _ in
            viewModel.sources.removeAll()
            viewModel.destinations.removeAll()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 2) {
            Text("Checksum")
                .font(.title2.weight(.semibold))
            Text("Clone and verify files with confidence.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) { historyButton }
        .padding(.bottom, 4)
    }
    
    private var mainContentSection: some View {
        GeometryReader { proxy in
            let isPortrait = proxy.size.width < 640
            VStack(alignment: .leading, spacing: 16) {
                if isPortrait {
                    // Compute dynamic heights so content never overflows in portrait
                    let progressHeight: CGFloat = 96
                    let spacingBetweenLists: CGFloat = 16
                    let availableForLists = max(proxy.size.height - progressHeight - spacingBetweenLists, 0)
                    let listHeight = max(140, availableForLists / 2)
                    VStack(spacing: 16) {
                        sourcesSection(height: listHeight)
                        destinationSection(height: listHeight)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        sourcesSection()
                        destinationSection()
                    }
                    .frame(maxHeight: .infinity)
                }
                Spacer()
                progressSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func sourcesSection(height: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sources", systemImage: "folder")
            GlassContainer(highlighted: isSourceDropTargeted) { 
                    list(urls: viewModel.sources, remove: viewModel.removeSource, height: height ?? 220)
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isSourceDropTargeted) { providers in
                if !viewModel.isCloning {
                    _ = handleDrop(providers) { urls in viewModel.addSources(urls: urls) }
                }
                return false
            }
            
            Button(action: { pick(sources: true, allowFiles: true) }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Files or Folders")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
            .disabled(viewModel.isCloning)
        }
    }
    
    private func destinationSection(height: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Destination", systemImage: "externaldrive")
            GlassContainer(highlighted: isDestDropTargeted) { 
                    list(urls: viewModel.destinations, remove: viewModel.removeDestination, height: height ?? 220)
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isDestDropTargeted) { providers in
                if !viewModel.isCloning {
                    _ = handleDrop(providers) { urls in viewModel.addDestinations(urls: urls.filter { isDirectory($0) }) }
                }
                return false
            }
            
            Button(action: { pick(sources: false, allowFiles: true) }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Destination Folders")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
            .disabled(viewModel.isCloning)
        }
    }
    
    private var progressSection: some View {
        GlassContainer {
            HStack(spacing: 16) {
                // Left side - Progress info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView(value: viewModel.overallProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        Text("\(Int(viewModel.overallProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 35, alignment: .trailing)
                    }
                    
                    if viewModel.isCloning {
                        Text(viewModel.remainingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Right side - Action button
                Button(action: {
                    if viewModel.isCloning {
                        viewModel.stopCurrentJob()
                    } else {
                        // If a previous job exists with same inputs/outputs, confirm overwrite
                        if let last = viewModel.jobs.last, !viewModel.sources.isEmpty, !viewModel.destinations.isEmpty {
                            let alert = NSAlert()
                            alert.messageText = "Overwrite previous results?"
                            alert.informativeText = "Starting again may overwrite files previously copied to the destination."
                            alert.addButton(withTitle: "OK")
                            alert.addButton(withTitle: "Cancel")
                            let response = alert.runModal()
                            if response == .alertFirstButtonReturn {
                                Task { await viewModel.startClone(overwrite: true) }
                            }
                        } else {
                            Task { await viewModel.startClone(overwrite: false) }
                        }
                    }
                }) {
                    Text(viewModel.isCloning ? "Stop" : "Start")
                        .frame(minWidth: 80)
                }
                .buttonStyle(PillButtonStyle())
                .disabled(viewModel.sources.isEmpty || viewModel.destinations.isEmpty)
            }
        }
    }
    
    private var historyDrawer: some View {
        VStack(spacing: 0) {
            // Header - fixed at top
            HStack {
                SectionHeader(title: "History", systemImage: "clock")
                Spacer()
                Button(action: { showHistory = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial)
            
            Divider()
            
            // Content area - fills remaining space
            if viewModel.jobs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No jobs yet")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Your copy operations will appear here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
            } else {
                List {
                    ForEach(viewModel.jobs.sorted(by: { $0.createdAt > $1.createdAt })) { job in
                        Button(action: { 
                            loadJob(job)
                            // Also open the destination folder in Finder if job is completed
                            if job.status == "success" {
                                openJobResultInFinder(job)
                            }
                        }) {
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(jobDisplayName(for: job))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    HStack {
                                        Text(job.createdAt, formatter: timeFormatterWithSeconds)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(job.status)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(job.status == "success" ? .green.opacity(0.2) : 
                                                          job.status == "cancelled" ? .orange.opacity(0.2) : 
                                                          job.status == "failed" ? .red.opacity(0.2) : .blue.opacity(0.2))
                                            )
                                            .foregroundStyle(job.status == "success" ? .green : 
                                                            job.status == "cancelled" ? .orange : 
                                                            job.status == "failed" ? .red : .blue)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Reveal in Finder") {
                                if let first = job.destinations.first {
                                    NSWorkspace.shared.activateFileViewerSelecting([first])
                                }
                            }
                            Button("Remove Job") {
                                viewModel.removeJob(id: job.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .fill(.quaternary.opacity(0.3))
                .frame(width: 1),
            alignment: .leading
        )
    }
    
    private func jobDisplayName(for job: CloneViewModel.Job) -> String {
        if job.sources.count == 1 {
            return job.sources[0].lastPathComponent
        } else if job.sources.count > 1 {
            return "\(job.sources.count) items"
        } else {
            return "Job \(job.id.uuidString.prefix(8))"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
    
    private var timeFormatterWithSeconds: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter
    }
    
    private func openJobResultInFinder(_ job: CloneViewModel.Job) {
        // For each source, find the corresponding copied files in each destination
        var filesToSelect: [URL] = []
        
        for source in job.sources {
            for destination in job.destinations {
                // If source is a folder, select the folder itself (copied folder) under destination
                if isDirectory(source) {
                    let copiedFolder = destination.appendingPathComponent(source.lastPathComponent)
                    if FileManager.default.fileExists(atPath: copiedFolder.path) {
                        filesToSelect.append(copiedFolder)
                    }
                } else {
                    // For files, select the copied file under destination
                    let copiedFile = destination.appendingPathComponent(source.lastPathComponent)
                    if FileManager.default.fileExists(atPath: copiedFile.path) {
                        filesToSelect.append(copiedFile)
                    }
                }
            }
        }
        
        if !filesToSelect.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(filesToSelect)
        } else if let firstDestination = job.destinations.first {
            // Fallback to just opening the destination folder
            NSWorkspace.shared.activateFileViewerSelecting([firstDestination])
        }
    }
    
    private var historyButton: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showHistory.toggle() } }) {
            Image(systemName: "clock")
                .font(.title2)
                .foregroundStyle(showHistory ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    private func list(urls: [URL], remove: @escaping (IndexSet) -> Void, height: CGFloat) -> some View {
        Group {
            if urls.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Drop items here")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: height)
            } else {
        List {
            ForEach(urls, id: \.self) { url in
						HStack(alignment: .center, spacing: 10) {
							Image(systemName: isDirectory(url) ? "folder" : "doc")
								.foregroundStyle(.secondary)
							VStack(alignment: .leading, spacing: 2) {
								Text(url.lastPathComponent)
									.fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
								Text(url.deletingLastPathComponent().path)
									.font(.caption)
									.foregroundStyle(.secondary)
									.lineLimit(1)
									.truncationMode(.head)
							}
							Spacer()
							Button {
								NSWorkspace.shared.activateFileViewerSelecting([url])
							} label: {
								Image(systemName: "magnifyingglass")
							}
							.buttonStyle(.borderless)
							Button {
								// remove current URL
								if let idx = urls.firstIndex(of: url) {
									var mutable = urls
									mutable.remove(at: idx)
									remove(IndexSet(integer: idx))
								}
							} label: {
								Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
							}
							.buttonStyle(.borderless)
						}
						.contextMenu {
							Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
            }
            .onDelete(perform: remove)
        }
        .frame(minHeight: height, maxHeight: height)
				.listStyle(.inset)
			}
		}
    }

	private func pick(sources: Bool, allowFiles: Bool = true) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = allowFiles
		panel.canChooseDirectories = sources
        panel.allowsMultipleSelection = true
        
        // For destinations, only allow directories
        if !sources {
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
        }
        
        panel.begin { resp in
            if resp == .OK {
				if sources {
					viewModel.addSources(urls: panel.urls)
				} else {
					// Only add directories for destinations
					viewModel.addDestinations(urls: panel.urls.filter { isDirectory($0) })
				}
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], handler: @escaping ([URL]) -> Void) -> Bool {
        var any = false
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            any = true
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
				let maybeURL: URL? = {
					if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
					if let url = item as? URL { return url }
					return nil
				}()
				DispatchQueue.main.async {
					if let url = maybeURL { urls.append(url) }
                group.leave()
				}
            }
        }
        group.notify(queue: .main) { handler(urls) }
        return any
	}

	private func isDirectory(_ url: URL) -> Bool {
		if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), let isDir = values.isDirectory { return isDir }
		return url.hasDirectoryPath
	}

	  private func loadJob(_ job: CloneViewModel.Job) {
      Task { @MainActor in
          viewModel.sources = job.sources
          viewModel.destinations = job.destinations
      }
    }
}

#Preview {
    ContentView()
}


