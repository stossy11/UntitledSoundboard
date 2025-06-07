//
//  ContentView.swift
//  BadSoundboard™
//
//  Created by Stossy11 on 24/05/2025.
//

import SwiftUI
import AVKit
import AVFoundation
#if canImport(PhotosUI)
import PhotosUI
#endif
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Data Models
struct CodableColor: Codable, Equatable, Identifiable {
    var id: Double {
        red + green + blue + alpha
    }
    
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if os(macOS)
        let nsColor = NSColor(color)
            .usingColorSpace(.sRGB) ?? .white
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif

        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct Sounds: Codable, Equatable, Identifiable {
    var id: String {
        label + soundPath.lastPathComponent
    }
    
    var label: String
    var colour: CodableColor?
    var soundPath: URL
    var image: String?
}

struct SoundboardExport: Codable {
    let sounds: [SoundExportData]
    let exportDate: Date
    let version: String
    
    struct SoundExportData: Codable {
        let label: String
        let colour: CodableColor?
        let soundData: Data
        let soundExtension: String
        let image: String?
    }
}

// MARK: - Main Soundboard View
struct SoundboardView: View {
    @AppCodableStorage("soundsForSoundboard") var sounds: [Sounds] = []
    
    @State private var editingIndex: Int? = nil
    @State private var player: AVAudioPlayer?
    @State private var adding = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportURL: URL?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @AppStorage("badSoundboard") var badSoundboard = false
    
    var editing: Binding<Bool> {
        Binding(
            get: { editingIndex != nil },
            set: { if !$0 { editingIndex = nil } }
        )
    }
    
    var exporting: Binding<Bool> {
        Binding(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )
    }
    
    let buttonSize: CGFloat = 110
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if sounds.isEmpty {
                emptyStateView
            } else {
                soundGridView
            }
        }
        .onAppear() {
            #if os(macOS)
            if badSoundboard {
                NSApp.mainMenu?.item(at: 0)?.title = "BadSoundboard™"
            }
            #endif
        }
        .navigationTitle(badSoundboard ? "BadSoundboard™" : "UntitledSoundboard")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
#if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    toolBarView
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
            }
#else
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    toolBarView
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
            }
#endif
        }
        .sheet(isPresented: editing) {
            if let editingIndex {
                SoundEdit(sound: $sounds[editingIndex])
            }
        }
        .sheet(isPresented: $adding) {
            SoundNew(sounds: $sounds)
        }
        #if os(iOS)
        .sheet(isPresented: exporting) {
            Text("hewwo")
            
            ActivityViewController(activityItems: [exportURL!])
        }
        #endif
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [UTType(filenameExtension: "stosb") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Soundboard", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        #if os(macOS)
        .onChange(of: showingExportSheet) { isShowing in
            if isShowing, let exportURL = exportURL {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [UTType(filenameExtension: "stosb") ?? .data]
                savePanel.nameFieldStringValue = exportURL.lastPathComponent
                
                if savePanel.runModal() == .OK, let url = savePanel.url {
                    do {
                        try FileManager.default.copyItem(at: exportURL, to: url)
                        alertMessage = "Soundboard exported successfully!"
                        showingAlert = true
                    } catch {
                        alertMessage = "Failed to save export: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
                showingExportSheet = false
            }
        }
        #endif
    }
    
    private var toolBarView: some View {
        Group {
            Button(action: { adding = true }) {
                Label("Add Sound", systemImage: "plus.circle")
            }
            
            if !sounds.isEmpty {
                Button(action: exportSounds) {
                    Label("Export Sounds", systemImage: "square.and.arrow.up")
                }
            }
            
            Button(action: { showingImportSheet = true }) {
                Label("Import Sounds", systemImage: "square.and.arrow.down")
            }
            
            
            if player?.isPlaying ?? false {
                Button(action: { player?.stop() }) {
                    Label("Stop", systemImage: "pause.circle")
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "speaker.wave.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Sounds Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the menu button to add your first sound")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { adding = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Sound")
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var soundGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: buttonSize))], spacing: 20) {
                ForEach(sounds.indices, id: \.self) { index in
                    SoundButton(
                        exportURL: $exportURL,
                        alertMessage: $alertMessage,
                        showingAlert: $showingAlert,
                        sound: sounds[index],
                        size: buttonSize,
                        onPlay: { playSound(sounds[index]) },
                        onEdit: { editingIndex = index },
                        onDelete: { deleteSound(at: index) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
    
    private func playSound(_ sound: Sounds) {
        player?.stop()
        do {
            player = try AVAudioPlayer(contentsOf: sound.soundPath)
            player?.play()
        } catch {
            do {
                #if os(macOS)
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
                #else
                let documentsPath = URL.documentsDirectory
                #endif
                player = try AVAudioPlayer(contentsOf: documentsPath.appendingPathComponent(sound.soundPath.lastPathComponent))
                player?.play()
            } catch {
                alertMessage = "Failed to play sound: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func deleteSound(at index: Int) {
        let sound = sounds[index]
        do {
            try FileManager.default.removeItem(at: sound.soundPath)
            sounds.remove(at: index)
        } catch {
            alertMessage = "Failed to delete sound: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func exportSounds() {
        Task {
            do {
                var exportSounds: [SoundboardExport.SoundExportData] = []
                
                for sound in sounds {
                    let soundData = try Data(contentsOf: sound.soundPath)
                    let exportSound = SoundboardExport.SoundExportData(
                        label: sound.label,
                        colour: sound.colour,
                        soundData: soundData,
                        soundExtension: sound.soundPath.pathExtension,
                        image: sound.image
                    )
                    exportSounds.append(exportSound)
                }
                
                let export = SoundboardExport(
                    sounds: exportSounds,
                    exportDate: Date(),
                    version: "1.0"
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(export)
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Soundboard_Export_\(DateFormatter.filenameDateFormatter.string(from: Date()))")
                    .appendingPathExtension("stosb")
                
                try data.write(to: tempURL)
                
                await MainActor.run {
                    exportURL = tempURL
                    showingExportSheet = true
                }
                
            } catch {
                do {
                    var exportSounds: [SoundboardExport.SoundExportData] = []
                    
                    for sound in sounds {
                        let soundData = try Data(contentsOf: URL.documentsDirectory.appendingPathComponent(sound.soundPath.lastPathComponent))
                        let exportSound = SoundboardExport.SoundExportData(
                            label: sound.label,
                            colour: sound.colour,
                            soundData: soundData,
                            soundExtension: sound.soundPath.pathExtension,
                            image: sound.image
                        )
                        exportSounds.append(exportSound)
                    }
                    
                    let export = SoundboardExport(
                        sounds: exportSounds,
                        exportDate: Date(),
                        version: "1.0"
                    )
                    
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(export)
                    
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Soundboard_Export_\(DateFormatter.filenameDateFormatter.string(from: Date()))")
                        .appendingPathExtension("stosb")
                    
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        exportURL = tempURL
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to export sounds: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importSounds(from: url)
        case .failure(let error):
            alertMessage = "Failed to select file: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func importSounds(from url: URL) {
        Task {
            do {

                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let importData = try decoder.decode(SoundboardExport.self, from: data)
                
                var importedCount = 0
                
                for exportSound in importData.sounds {
                    #if os(macOS)
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
                    #else
                    let documentsPath = URL.documentsDirectory
                    #endif
                    
                    let soundURL = documentsPath
                        .appendingPathComponent("\(UUID().uuidString)")
                        .appendingPathExtension(exportSound.soundExtension)
                    
                    try exportSound.soundData.write(to: soundURL)
                    
                    let newSound = Sounds(
                        label: exportSound.label,
                        colour: exportSound.colour,
                        soundPath: soundURL,
                        image: exportSound.image
                    )
                    
                    await MainActor.run {
                        sounds.append(newSound)
                    }
                    
                    importedCount += 1
                }
                
                await MainActor.run {
                    alertMessage = "Successfully imported \(importedCount) sound\(importedCount == 1 ? "" : "s")!"
                    showingAlert = true
                }
                
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to import sounds: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Sound Button Component
struct SoundButton: View {
    @Binding var exportURL: URL?
    @Binding var alertMessage: String
    @Binding var showingAlert: Bool
    let sound: Sounds
    let size: CGFloat
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onPlay) {
            ZStack {
                
                if let imageName = sound.image, let image = imageFromBase64(imageName) {
                    // Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: size, height: size)
                    
                    // Content
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size - 8, height: size - 8)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size - 8, height: size - 8)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    #endif
                } else {
                    // Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundGradient)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: size, height: size)
                    
                    // Content
                    Text(sound.label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            onPlay()
        }
        .contextMenu {
            Button(action: onPlay) {
                Label("Play", systemImage: "play.fill")
            }
            
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: exportSounds) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func exportSounds() {
        Task {
            do {
                var exportSounds: [SoundboardExport.SoundExportData] = []
                
                let soundData = try Data(contentsOf: sound.soundPath)
                let exportSound = SoundboardExport.SoundExportData(
                    label: sound.label,
                    colour: sound.colour,
                    soundData: soundData,
                    soundExtension: sound.soundPath.pathExtension,
                    image: sound.image
                )
                exportSounds.append(exportSound)
                
                let export = SoundboardExport(
                    sounds: exportSounds,
                    exportDate: Date(),
                    version: "1.0"
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(export)
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Soundboard_Export_\(DateFormatter.filenameDateFormatter.string(from: Date()))")
                    .appendingPathExtension("stosb")
                
                try data.write(to: tempURL)
                
                await MainActor.run {
                    exportURL = tempURL
                }
                
            } catch {
                do {
                    var exportSounds: [SoundboardExport.SoundExportData] = []
                    
                    let soundData = try Data(contentsOf: URL.documentsDirectory.appendingPathComponent(sound.soundPath.lastPathComponent))
                    let exportSound = SoundboardExport.SoundExportData(
                        label: sound.label,
                        colour: sound.colour,
                        soundData: soundData,
                        soundExtension: sound.soundPath.pathExtension,
                        image: sound.image
                    )
                    exportSounds.append(exportSound)
                    
                    let export = SoundboardExport(
                        sounds: exportSounds,
                        exportDate: Date(),
                        version: "1.0"
                    )
                    
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(export)
                    
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Soundboard_Export_\(DateFormatter.filenameDateFormatter.string(from: Date()))")
                        .appendingPathExtension("stosb")
                    
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        exportURL = tempURL
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to export sounds: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if let color = sound.colour?.color {
            return LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Sound Edit View
struct SoundEdit: View {
    @Binding var sound: Sounds
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sound Details") {
                    if sound.image == nil {
                        TextField("Sound Name", text: $sound.label)
                        
                        ColorPicker("Button Color", selection: Binding(
                            get: { sound.colour?.color ?? .accentColor },
                            set: { sound.colour = CodableColor($0) }
                        ))
                    }
                    
                    ImagePickerView(selectedImage: $sound.image)
                    
                    if sound.image != nil {
                        Button("Remove Image", role: .destructive) {
                            sound.image = nil
                        }
                    }
                }
            }
            .navigationTitle("Edit Sound")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Sound New View
struct SoundNew: View {
    @Binding var sounds: [Sounds]
    @Environment(\.dismiss) var dismiss
    @AppStorage("badSoundboard") var badSoundboard = false
    
    @State private var sound = Sounds(
        label: "",
        colour: CodableColor(.accentColor),
        soundPath: {
            #if os(macOS)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            #else
            let documentsPath = URL.documentsDirectory
            #endif
            return documentsPath.appendingPathComponent("\(UUID().uuidString).mp3")
        }(),
        image: nil
    )
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var canSave: Bool {
        (!sound.label.isEmpty || sound.image != nil) && FileManager.default.fileExists(atPath: sound.soundPath.path)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sound Details") {
                    if sound.image == nil {
                        TextField("Sound Name", text: $sound.label)
                            .onChange(of:  sound) { cool in
                                if sound.label == "peepeepoopoo" {
                                    badSoundboard = true
                                }
                            }
                        
                        ColorPicker("Button Color", selection: Binding(
                            get: { sound.colour?.color ?? .accentColor },
                            set: { sound.colour = CodableColor($0) }
                        ))
                    }
                    
                    ImagePickerView(selectedImage: $sound.image)
                    
                    if sound.image != nil {
                        Button("Remove Image", role: .destructive) {
                            sound.image = nil
                        }
                    }
                }
                
                Section(
                    header: Text("Audio File"),
                    footer: Text("\(badSoundboard ? "BadSoundboard™" : "UntitledSoundboard") is made by Stossy11!")
                ) {
                    if !FileManager.default.fileExists(atPath: sound.soundPath.path) {
                        Button("Import Audio File") {
                            #if os(macOS)
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [.mp3, .wav, .m4a]
                            openPanel.allowsMultipleSelection = false
                            
                            if openPanel.runModal() == .OK, let url = openPanel.url {
                                handleAudioImport(result: .success([url]))
                            }
                            #else
                            FileImporterManager.shared.importFiles(types: [.mp3, .wav, .m4a]) { result in
                                handleAudioImport(result: result)
                            }
                            #endif
                        }
                        .foregroundColor(.accentColor)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Audio file imported")
                            Spacer()
                            Button("Change") {
                                #if os(macOS)
                                let openPanel = NSOpenPanel()
                                openPanel.allowedContentTypes = [.mp3, .wav, .m4a]
                                openPanel.allowsMultipleSelection = false
                                
                                if openPanel.runModal() == .OK, let url = openPanel.url {
                                    handleAudioImport(result: .success([url]))
                                }
                                #else
                                FileImporterManager.shared.importFiles(types: [.mp3, .wav, .m4a]) { result in
                                    handleAudioImport(result: result)
                                }
                                #endif
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Sound")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        sounds.append(sound)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                #else
                ToolbarItem(placement: .destructiveAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if sound.image != nil {
                            sound.label = ""
                        }
                        
                        sounds.append(sound)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                #endif
            }
            #if os(iOS)
            .withFileImporter()
            #endif
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func handleAudioImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let scopedResource = url.startAccessingSecurityScopedResource()
            defer { if scopedResource { url.stopAccessingSecurityScopedResource() } }
            
            do {
                #if os(macOS)
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
                #else
                let documentsPath = URL.documentsDirectory
                #endif
                let destinationPath = documentsPath.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
                try FileManager.default.copyItem(at: url, to: destinationPath)
                sound.soundPath = destinationPath
            } catch {
                alertMessage = "Failed to import audio file: \(error.localizedDescription)"
                showingAlert = true
            }
            
        case .failure(let error):
            alertMessage = "Failed to select audio file: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Image Picker View
struct ImagePickerView: View {
    #if canImport(PhotosUI) && os(iOS)
    @State private var selectedItem: PhotosPickerItem? = nil
    #endif
    @Binding var selectedImage: String?

    var body: some View {
        HStack {
            if let image = selectedImage, let platformImage = imageFromBase64(image) {
                #if os(macOS)
                Image(nsImage: platformImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #else
                Image(uiImage: platformImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #endif
            }
            
            VStack(alignment: .leading) {
                #if canImport(PhotosUI) && os(iOS)
                PhotosPicker(
                    selectedItem != nil ? "Change Image" : "Add Image",
                    selection: $selectedItem,
                    matching: .images
                )
                #else
                Button(selectedImage != nil ? "Change Image" : "Add Image") {
                    #if os(macOS)
                    let openPanel = NSOpenPanel()
                    openPanel.allowedContentTypes = [.image]
                    openPanel.allowsMultipleSelection = false
                    
                    if openPanel.runModal() == .OK, let url = openPanel.url,
                       let imageData = try? Data(contentsOf: url),
                       let image = NSImage(data: imageData) {
                        selectedImage = base64FromImage(image)
                    }
                    #endif
                }
                #endif
                
                if selectedImage != nil {
                    Text("Tap to change image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        #if canImport(PhotosUI) && os(iOS)
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = base64FromImage(uiImage)
                }
            }
        }
        #endif
    }
}

// MARK: - Activity View Controller (iOS only)
#if os(iOS)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
#endif

// MARK: - Utility Functions
#if os(macOS)
func imageFromBase64(_ base64String: String) -> NSImage? {
    guard let data = Data(base64Encoded: base64String),
          let image = NSImage(data: data) else {
        return nil
    }
    return image
}

func base64FromImage(_ image: NSImage) -> String? {
    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData),
          let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
        return nil
    }
    return imageData.base64EncodedString()
}
#else
func imageFromBase64(_ base64String: String) -> UIImage? {
    guard let data = Data(base64Encoded: base64String),
          let image = UIImage(data: data) else {
        return nil
    }
    return image
}

func base64FromImage(_ image: UIImage) -> String? {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        return nil
    }
    return imageData.base64EncodedString()
}
#endif

// MARK: - Extensions
extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

extension UTType {
    static let mp3 = UTType(filenameExtension: "mp3")!
    static let wav = UTType(filenameExtension: "wav")!
    static let m4a = UTType(filenameExtension: "m4a")!
}

// MARK: - Content View
struct ContentView: View {
    var body: some View {
        NavigationStack {
            SoundboardView()
        }
    }
}
#Preview {
    ContentView()
}

