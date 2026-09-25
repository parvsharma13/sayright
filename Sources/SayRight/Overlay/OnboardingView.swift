import SwiftUI

struct OnboardingView: View {
    // No @State: SwiftUI tracks @Observable reads in `body` on its own, and the
    // SwiftUIMacros plugin that backs @State ships only with Xcode. See README.
    private var permissions: Permissions { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Welcome to SayRight").font(.title2).bold()
                    Text("Select text in any app, then fix or rewrite it in place.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: permissions.isTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(permissions.isTrusted ? .green : .orange)
                Text(permissions.isTrusted
                     ? "Accessibility access granted."
                     : "SayRight needs Accessibility access to read the text you select.")
                Spacer()
            }

            if !permissions.isTrusted {
                Text("Open System Settings › Privacy & Security › Accessibility and switch SayRight on. This window updates on its own.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Open System Settings") {
                        permissions.request()
                        permissions.openSystemSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                Text("You're ready. Look for the SayRight icon in the menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear { permissions.startPolling() }
        // Deliberately no onDisappear: the poller is app-wide and is what starts the
        // Coordinator when access is granted. Stopping it on close left the app inert
        // until the next relaunch.
    }
}
