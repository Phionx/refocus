import AppKit
import SwiftUI

@MainActor struct RefocusView: View {
    @ObservedObject var model: AppModel
    @State private var newSite = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Refocus").font(.system(size: 17, weight: .semibold))
                Spacer()
                if model.busy { ProgressView().controlSize(.small).accessibilityLabel("Saving changes") }
                Menu {
                    Toggle("Open Refocus at login", isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))
                    if model.helperReady || model.helperNeedsRepair {
                        Button("Refresh background helper") { model.refreshHelper() }
                        Button("Disable & remove helper", role: .destructive) { model.removeHelper() }
                    }
                    Divider()
                    Button("About Refocus") { NSApp.orderFrontStandardAboutPanel() }
                    Button("Quit Refocus · turn blocking off") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("More options") }
                .menuStyle(.borderlessButton).fixedSize().disabled(model.busy)
            }

            HStack(spacing: 10) {
                Circle().fill(model.isBlocking && model.helperReady ? Color.green : Color.secondary).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.statusTitle).font(.system(size: 14, weight: .medium))
                    if model.isPaused, let deadline = model.configuration.pausedUntil {
                        Text("Resumes at \(deadline, style: .time)").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(model.configuration.sites.count) sites on your list").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("Blocking", isOn: Binding(get: { model.configuration.enabled }, set: { model.setEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .disabled(!model.helperReady || model.busy)
                    .accessibilityLabel("Enable website blocking")
            }

            if model.helperReady {
                Text("Background helper approved. Blocking turns off when you quit Refocus.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Fully quit and reopen your browser to apply changes immediately, or wait a bit for them to take effect.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.helperReady {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.helperNeedsRepair
                         ? "The background helper needs to be refreshed after this update. Your website list is saved."
                         : model.helperStatus == .requiresApproval
                         ? "Allow Refocus under General → Login Items in System Settings, then return here."
                         : "Refocus needs a background helper to edit your Mac's website blocks. Approve it under General → Login Items in System Settings. Blocking turns off when you quit Refocus.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Button(model.helperNeedsRepair ? "Refresh background helper" : model.helperStatus == .requiresApproval ? "Open System Settings" : "Enable blocking…") {
                        if model.helperNeedsRepair { model.refreshHelper() } else { model.setUp() }
                    }
                        .buttonStyle(.borderedProminent).disabled(model.busy)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Restricted sites").font(.caption).foregroundStyle(.secondary)
                if !model.configuration.sites.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(model.configuration.sites, id: \.self) { site in
                                HStack {
                                    Text(site).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 8)
                                    Button { model.removeSite(site) } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .medium)) }
                                        .buttonStyle(.plain).foregroundStyle(.secondary)
                                        .accessibilityLabel("Remove \(site)").help("Remove \(site)")
                                }.padding(.vertical, 9)
                                Divider()
                            }
                        }
                    }
                    .frame(height: min(CGFloat(model.configuration.sites.count) * 36, 216))
                    .disabled(model.busy)
                }
                HStack(spacing: 8) {
                    TextField("Add a website…", text: $newSite)
                        .textFieldStyle(.roundedBorder).onSubmit { addSite() }
                        .accessibilityLabel("Website to restrict")
                    Button("Add") { addSite() }.disabled(newSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.disabled(model.busy)
                Text("Includes www and common site aliases.").font(.caption).foregroundStyle(.secondary)
                if configurationIncludesMessenger && !model.configuration.sites.contains("facebook.com") {
                    Text("Messenger shares some servers with Facebook, so blocking it may also affect Facebook features.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            if let error = model.error {
                Text(error).font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    .accessibilityLabel("Error: \(error)")
            }

            Divider()
            HStack {
                Text("First line of defense against doomscrolling.").font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(model.isPaused ? "Resume now" : "Pause 5 min") { model.togglePause() }
                    .disabled(!model.helperReady || !model.configuration.enabled || model.busy)
            }
        }
        .padding(20).frame(width: 380)
        .onAppear { model.refresh() }
    }

    private var configurationIncludesMessenger: Bool {
        model.configuration.sites.contains { ["messenger.com", "m.me"].contains($0) }
    }

    private func addSite() {
        if model.addSite(newSite) { newSite = "" }
    }
}
