import SwiftUI
import UIKit

struct WiFiTransferView: View {
    @EnvironmentObject private var server:
        WiFiTransferServer

    @State private var shareLink: String?

    var body: some View {
        List {
            serverControlSection

            if server.isRunning,
               server.address != nil {
                connectionSection
            }

            if server.lastError != nil {
                errorSection
            }

            if !server.log.isEmpty {
                activitySection
            }

            wiredTransferSection
        }
        .navigationTitle("Wi-Fi Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: shareSheetPresented
        ) {
            if let shareLink = shareLink {
                ActivityView(
                    items: [shareLink]
                )
            }
        }
        .onAppear {
            server.start()

            UIApplication.shared
                .isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared
                .isIdleTimerDisabled = false
        }
    }

    // MARK: - Share sheet state

    private var shareSheetPresented:
        Binding<Bool> {
        Binding(
            get: {
                shareLink != nil
            },
            set: { isPresented in
                if !isPresented {
                    shareLink = nil
                }
            }
        )
    }

    // MARK: - Server control

    private var serverControlSection:
        some View {
        Section {
            Toggle(
                "Wi-Fi Transfer",
                isOn: serverRunningBinding
            )
        } footer: {
            Text(
                "Open the address in a browser on a " +
                "computer connected to the same Wi-Fi " +
                "to add music or download files. Keep " +
                "this screen open while transferring."
            )
        }
    }

    private var serverRunningBinding:
        Binding<Bool> {
        Binding(
            get: {
                server.isRunning
            },
            set: { shouldRun in
                if shouldRun {
                    server.start()
                } else {
                    server.stop()
                }
            }
        )
    }

    // MARK: - Connection information

    @ViewBuilder
    private var connectionSection: some View {
        if let address = server.address {
            Section(
                "On your computer, open"
            ) {
                addressView(address)

                accessCodeView

                if let url = server.url {
                    connectionButtons(url)
                }

                Button("New Access Code") {
                    server.newCode()
                }
            }
        }
    }

    private func addressView(
        _ address: String
    ) -> some View {
        Text(address)
            .font(
                .title3
                    .monospaced()
                    .weight(.semibold)
            )
            .textSelection(.enabled)
    }

    private var accessCodeView:
        some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 12
        ) {
            Text("Access Code")

            Spacer(minLength: 8)

            Text(server.accessCode)
                .font(
                    .title3
                        .monospaced()
                        .weight(.bold)
                )
                .foregroundColor(.accentColor)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func connectionButtons(
        _ url: String
    ) -> some View {
        Button {
            UIPasteboard.general.string = url
        } label: {
            Label(
                "Copy Link with Code",
                systemImage: "doc.on.doc"
            )
        }

        Button {
            shareLink = url
        } label: {
            Label(
                "Send Link to Computer…",
                systemImage:
                    "square.and.arrow.up"
            )
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = server.lastError {
            Section {
                Label(
                    error,
                    systemImage:
                        "wifi.exclamationmark"
                )
                .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Activity log

    private var activitySection:
        some View {
        Section("Activity") {
            ForEach(
                Array(
                    server.log.enumerated()
                ),
                id: \.offset
            ) {
                _,
                line in

                Text(line)
                    .font(
                        .caption.monospaced()
                    )
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Wired transfer

    private var wiredTransferSection:
        some View {
        Section {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text(
                    "colon3's Music folder is also " +
                    "shared over a cable:"
                )

                Text(
                    "• Mac: Finder › iPhone › " +
                    "Files › colon3\n" +
                    "• Windows: Apple Devices " +
                    "app › Files\n" +
                    "• Linux: libimobiledevice " +
                    "+ ifuse"
                )
                .foregroundColor(.secondary)

                Text(
                    "ifuse --documents " +
                    "com.aminewallah.colon3 " +
                    "~/iphone"
                )
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .padding(8)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.secondary.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: 8
                    )
                )
            }
            .font(.subheadline)
            .padding(.vertical, 4)
        } header: {
            Text("Wired")
        } footer: {
            Text(
                "Wired transfer requires the " +
                "iPhone to trust the computer. " +
                "After copying files, pull down " +
                "on the library or tap Rescan."
            )
        }
    }
}
