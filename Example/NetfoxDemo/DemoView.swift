//
//  DemoView.swift
//  NetfoxDemo
//
//  Launch arguments (handy for UI checks and GIF recording):
//    --send-all      send every sample request on launch
//    --open-netfox   open the netfox inspector once the requests are done
//

import SwiftUI
import netfox

struct DemoView: View {

    @State private var results = [DemoRequest.ID: String]()
    @State private var sendingIDs = Set<DemoRequest.ID>()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        NFX.sharedInstance().show()
                    } label: {
                        Label("Open netfox", systemImage: "network")
                    }

                    Button {
                        Task { await sendAll() }
                    } label: {
                        Label("Send all requests", systemImage: "paperplane")
                    }
                    .disabled(!sendingIDs.isEmpty)
                } footer: {
                    Text("You can also shake the device to open netfox (Simulator: Device > Shake, or Control-Command-Z).")
                }

                ForEach(DemoRequest.Group.allCases, id: \.self) { group in
                    Section(group.rawValue) {
                        ForEach(DemoRequest.all.filter { $0.group == group }) { demo in
                            Button {
                                Task { await send(demo) }
                            } label: {
                                DemoRow(demo: demo, result: results[demo.id], isSending: sendingIDs.contains(demo.id))
                            }
                            .disabled(sendingIDs.contains(demo.id))
                        }
                    }
                }

                Section {
                    Button {
                        logSampleWebSocketMessages()
                    } label: {
                        Label("Log WebSocket messages", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } header: {
                    Text("WebSocket")
                } footer: {
                    Text("URLProtocol can't see WebSocket frames, so apps log them with NFX.shared.logWebSocketText(_:direction:url:).")
                }
            }
            .navigationTitle("netfox demo")
        }
        .task {
            await handleLaunchArguments()
        }
    }

    private func send(_ demo: DemoRequest) async {
        sendingIDs.insert(demo.id)
        results[demo.id] = await DemoClient.send(demo)
        sendingIDs.remove(demo.id)
    }

    private func sendAll() async {
        sendingIDs.formUnion(DemoRequest.all.map(\.id))
        await withTaskGroup(of: (DemoRequest.ID, String).self) { group in
            for demo in DemoRequest.all {
                group.addTask { (demo.id, await DemoClient.send(demo)) }
            }
            for await (id, result) in group {
                results[id] = result
                sendingIDs.remove(id)
            }
        }
    }

    private func logSampleWebSocketMessages() {
        guard let url = URL(string: "wss://chat.netfox.demo/socket") else { return }
        let nfx = NFX.shared
        nfx.logWebSocketText(#"{"type":"hello","user":"demo"}"#, direction: .sent, url: url)
        nfx.logWebSocketText(#"{"type":"welcome","online":3}"#, direction: .received, url: url)
        nfx.logWebSocketPing(direction: .sent, url: url)
        nfx.logWebSocketData(Data(count: 256), direction: .received, url: url)
    }

    private func handleLaunchArguments() async {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--send-all") {
            logSampleWebSocketMessages()
            await sendAll()
        }
        if arguments.contains("--open-netfox") {
            // give the last responses a moment to land in the list
            try? await Task.sleep(for: .seconds(1))
            NFX.sharedInstance().show()
        }
    }
}

private struct DemoRow: View {
    let demo: DemoRequest
    let result: String?
    let isSending: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(demo.method)
                .font(.caption.monospaced().bold())
                .frame(width: 56, alignment: .leading)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(demo.title)
                    .foregroundStyle(.primary)
                if let result {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSending {
                ProgressView()
            }
        }
    }
}

#Preview {
    DemoView()
}
