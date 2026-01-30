import SwiftUI
import CellarCore

// MARK: - CollectionListView

/// Displays package collections in a sidebar-detail layout.
/// The left panel lists all collections with icons and counts.
/// The right panel shows the packages in the selected collection.
struct CollectionListView: View {
    @Environment(CollectionStore.self) private var store

    @State private var isAddingCollection = false
    @State private var isAddingPackage = false
    @State private var newCollectionName = ""
    @State private var newCollectionIcon = "folder"
    @State private var newCollectionColor = "blue"
    @State private var newPackageName = ""
    @State private var addAsCask = false

    var body: some View {
        Group {
            if store.isInstalling, let stream = store.installStream {
                installOutputView(stream: stream)
            } else {
                mainContent
            }
        }
        .navigationTitle("Collections")
        .toolbar { toolbarContent }
        .sheet(isPresented: $isAddingCollection) { addCollectionSheet }
        .sheet(isPresented: $isAddingPackage) { addPackageSheet }
        .task { store.load() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HSplitView {
            collectionList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
            detailPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Collection List

    private var collectionList: some View {
        @Bindable var store = store

        return VStack(spacing: 0) {
            List(selection: $store.selectedCollectionId) {
                Section("Built-in") {
                    ForEach(store.collections.filter(\.isBuiltIn)) { collection in
                        collectionRow(collection)
                            .tag(collection.id)
                    }
                }

                let userCollections = store.collections.filter { !$0.isBuiltIn }
                if !userCollections.isEmpty {
                    Section("Custom") {
                        ForEach(userCollections) { collection in
                            collectionRow(collection)
                                .tag(collection.id)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.delete(collection)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button {
                    newCollectionName = ""
                    newCollectionIcon = "folder"
                    newCollectionColor = "blue"
                    isAddingCollection = true
                } label: {
                    Label("Add Collection", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()
            }
            .padding(8)
        }
    }

    private func collectionRow(_ collection: PackageCollection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: collection.icon)
                .foregroundStyle(color(for: collection.colorName))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .fontWeight(.medium)
                Text("\(collection.totalCount) packages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let collection = store.selectedCollection {
            collectionDetail(collection)
        } else {
            ContentUnavailableView(
                "Select a Collection",
                systemImage: "folder",
                description: Text("Choose a collection from the list to view its packages.")
            )
        }
    }

    private func collectionDetail(_ collection: PackageCollection) -> some View {
        VStack(spacing: 0) {
            collectionDetailHeader(collection)
            Divider()
            packageList(collection)
        }
    }

    private func collectionDetailHeader(_ collection: PackageCollection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: collection.icon)
                .font(.title)
                .foregroundStyle(color(for: collection.colorName))

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.headline)
                if let description = collection.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(collection.totalCount) packages")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.fill.tertiary, in: Capsule())
        }
        .padding()
    }

    private func packageList(_ collection: PackageCollection) -> some View {
        List {
            if !collection.packages.isEmpty {
                Section("Formulae") {
                    ForEach(collection.packages, id: \.self) { name in
                        HStack {
                            Label(name, systemImage: "terminal")
                            Spacer()
                            Button {
                                store.removePackage(name, from: collection)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            if !collection.casks.isEmpty {
                Section("Casks") {
                    ForEach(collection.casks, id: \.self) { name in
                        HStack {
                            Label(name, systemImage: "macwindow")
                            Spacer()
                            Button {
                                store.removeCask(name, from: collection)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            if collection.packages.isEmpty && collection.casks.isEmpty {
                ContentUnavailableView(
                    "No Packages",
                    systemImage: "shippingbox",
                    description: Text("Add packages to this collection using the toolbar button.")
                )
            }
        }
    }

    // MARK: - Install Output

    private func installOutputView(stream: AsyncThrowingStream<String, Error>) -> some View {
        VStack(spacing: 0) {
            ProcessOutputView(
                title: "Installing Collection",
                stream: stream
            )

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    store.endInstall()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                newPackageName = ""
                addAsCask = false
                isAddingPackage = true
            } label: {
                Label("Add Package", systemImage: "plus.square")
            }
            .disabled(store.selectedCollection == nil)
            .help("Add a package to this collection")

            Button {
                guard let collection = store.selectedCollection else { return }
                store.installAll(collection)
            } label: {
                Label("Install All", systemImage: "arrow.down.circle")
            }
            .disabled(store.selectedCollection == nil || store.isInstalling)
            .help("Install all packages in this collection")
        }
    }

    // MARK: - Add Collection Sheet

    private var addCollectionSheet: some View {
        VStack(spacing: 16) {
            Text("New Collection")
                .font(.headline)

            Form {
                TextField("Name", text: $newCollectionName)

                Picker("Icon", selection: $newCollectionIcon) {
                    Label("Folder", systemImage: "folder").tag("folder")
                    Label("Star", systemImage: "star").tag("star")
                    Label("Terminal", systemImage: "terminal").tag("terminal")
                    Label("Globe", systemImage: "globe").tag("globe")
                    Label("Wrench", systemImage: "wrench").tag("wrench")
                    Label("Server", systemImage: "server.rack").tag("server.rack")
                    Label("Lock", systemImage: "lock.shield").tag("lock.shield")
                    Label("Chart", systemImage: "chart.bar.xaxis").tag("chart.bar.xaxis")
                    Label("Code", systemImage: "chevron.left.forwardslash.chevron.right").tag("chevron.left.forwardslash.chevron.right")
                    Label("Paintbrush", systemImage: "paintbrush").tag("paintbrush")
                }

                Picker("Color", selection: $newCollectionColor) {
                    Text("Blue").tag("blue")
                    Text("Red").tag("red")
                    Text("Green").tag("green")
                    Text("Orange").tag("orange")
                    Text("Purple").tag("purple")
                    Text("Indigo").tag("indigo")
                    Text("Teal").tag("teal")
                    Text("Pink").tag("pink")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isAddingCollection = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    let name = newCollectionName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    store.create(name: name, icon: newCollectionIcon, colorName: newCollectionColor)
                    isAddingCollection = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Add Package Sheet

    private var addPackageSheet: some View {
        VStack(spacing: 16) {
            Text("Add Package")
                .font(.headline)

            Form {
                TextField("Package Name", text: $newPackageName)
                Toggle("Add as Cask", isOn: $addAsCask)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isAddingPackage = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    guard let collection = store.selectedCollection else { return }
                    let name = newPackageName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    if addAsCask {
                        store.addCask(name, to: collection)
                    } else {
                        store.addPackage(name, to: collection)
                    }
                    isAddingPackage = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPackageName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 380)
    }

    // MARK: - Color Helper

    private func color(for name: String) -> Color {
        switch name {
        case "blue": .blue
        case "red": .red
        case "green": .green
        case "orange": .orange
        case "purple": .purple
        case "indigo": .indigo
        case "teal": .teal
        case "pink": .pink
        case "yellow": .yellow
        case "mint": .mint
        default: .accentColor
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CollectionListView()
            .environment(CollectionStore())
    }
    .frame(width: 800, height: 600)
}
