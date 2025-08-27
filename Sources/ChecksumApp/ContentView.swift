import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = CloneViewModel()
    @State private var isSourceDropTargeted = false
    @State private var isDestDropTargeted = false
    @State private var showHistory = false
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                mainContentSection
            }
            .padding(20)
            
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
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Checksum").font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Clone and verify files with confidence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            historyButton
        }
    }
    
    private var mainContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main content area - sources and destinations side by side
            HStack(alignment: .top, spacing: 16) {
                sourcesSection
                destinationSection
            }
            
            // Progress section below
            progressSection
        }
    }
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sources", systemImage: "folder")
            GlassContainer(highlighted: isSourceDropTargeted) { 
                list(urls: viewModel.sources, remove: viewModel.removeSource) 
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isSourceDropTargeted) { providers in
                handleDrop(providers) { urls in viewModel.addSources(urls: urls) }
            }
            
            Button(action: { pick(sources: true, allowFiles: true) }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Files or Folders")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
        }
    }
    
    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Destination", systemImage: "externaldrive")
            GlassContainer(highlighted: isDestDropTargeted) { 
                list(urls: viewModel.destinations, remove: viewModel.removeDestination) 
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isDestDropTargeted) { providers in
                handleDrop(providers) { urls in viewModel.addDestinations(urls: urls.filter { isDirectory($0) }) }
            }
            
            Button(action: { pick(sources: false, allowFiles: false) }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Destination Folders")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
        }
    }
    
    private var progressSection: some View {
        GlassContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    Text("\(Int(viewModel.overallProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if viewModel.isCloning {
                    Text(viewModel.remainingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Toggle("Overwrite existing files", isOn: $viewModel.overwrite)
                        .toggleStyle(CheckboxToggleStyle())
                    Spacer()
                    Button(action: {
                        if viewModel.isCloning {
                            viewModel.stopCurrentJob()
                        } else {
                            Task { await viewModel.startClone() }
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
    }
    
    private var historyDrawer: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with better spacing
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
            .padding(.bottom, 8)
            
            // Content area
            if viewModel.jobs.isEmpty {
                VStack(spacing: 12) {
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.jobs) { job in
                            Button(action: { loadJob(job) }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Job \(job.id.uuidString.prefix(8))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(job.status)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(job.status == "success" ? .green.opacity(0.2) : 
                                                          job.status == "cancelled" ? .orange.opacity(0.2) : 
                                                          job.status == "failed" ? .red.opacity(0.2) : .blue.opacity(0.2))
                                            )
                                            .foregroundStyle(job.status == "success" ? .green : 
                                                            job.status == "cancelled" ? .orange : 
                                                            job.status == "failed" ? .red : .blue)
                                    }
                                    Text(job.createdAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.quaternary.opacity(0.3))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.quaternary.opacity(0.5), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.8))
                .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.quaternary.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private var historyButton: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showHistory.toggle() } }) {
            Image(systemName: "clock")
                .font(.title2)
                .foregroundStyle(showHistory ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    private func list(urls: [URL], remove: @escaping (IndexSet) -> Void) -> some View {
        Group {
            if urls.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Drop items here")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
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
				.frame(minHeight: 220)
				.listStyle(.inset)
			}
		}
	}

	private func pick(sources: Bool, allowFiles: Bool = true) {
		let panel = NSOpenPanel()
		panel.canChooseFiles = allowFiles
		panel.canChooseDirectories = sources
		panel.allowsMultipleSelection = true
		panel.begin { resp in
			if resp == .OK {
				if sources {
					viewModel.addSources(urls: panel.urls)
				} else {
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


