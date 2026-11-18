import SwiftUI
import UIKit

struct WiFiTransferView: View {
    @EnvironmentObject private var server: WiFiTransferServer

    @State private var shareLink: String?

    private var isShareSheetPresented: Binding<Bool> {
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

    var body: some View {
        List {
            Section {
                Toggle(
                    "Wi-Fi Transfer",
                    isOn: Binding(
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
                )
            } footer: {
                Text(
                    "Open the address in a browser on a " +
                    "computer connected to the same Wi-Fi " +
                    "to add music or download files. Keep " +
                    "this screen open while transferring."
                )
            }

            if server.isRunning,
               let address = server.address {
                Section(
                    "On your computer, open"
                ) {
                    Text(address)
                        .font(
                            .title3
                                .monospaced()
                                .weight(.semibold)
                        )
                        .textSelection(.enabled)

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

                    if let url = server.url {
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

                    Button("New Access Code") {
                        server.newCode()
                    }
                }
            }

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

            if !server.log.isEmpty {
                Section("Activity") {
                    ForEach(
                        server.log,
                        id: \.self
                    ) { line in
                        Text(line)
                            .font(
                                .caption.monospaced()
                            )
                            .lineLimit(2)
                    }
                }
            }

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
                        "• Mac: Finder › iPhone › Files › colon3\n" +
                        "• Windows: Apple Devices app › Files\n" +
                        "• Linux: libimobiledevice + ifuse"
                    )
                    .foregroundColor(.secondary)

                    Text(
                        "ifuse --documents " +
                        "com.aminewallah.colon3 ~/iphone"
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
                    "Wired transfer requires the iPhone " +
                    "to trust the computer. After copying " +
                    "files, pull down on the library or " +
                    "tap Rescan."
                )
            }
        }
        .navigationTitle("Wi-Fi Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: isShareSheetPresented
        ) {
            if let shareLink = shareLink {
                ActivityView(
                    activityItems: [shareLink]
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
}
