import SwiftUI

struct ToolbarView: View {
    @Binding var downloadAppleSilicon: Bool
    @Binding var currentApiVersion: String
    @Binding var searchText: String
    @Binding var showDownloadManager: Bool
    let isRefreshing: Bool
    let downloadTasksCount: Int
    let onRefresh: () -> Void
    let openSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $downloadAppleSilicon) { 
                Text("Apple Silicon") 
            }
            .toggleStyle(.switch)
            .tint(.green)
            .disabled(isRefreshing)
            
            HStack(spacing: 8) {
                Text("API:")
                Picker("", selection: $currentApiVersion) {
                    Text("v4").tag("4")
                    Text("v5").tag("5")
                    Text("v6").tag("6")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .disabled(isRefreshing)
            
            HStack(spacing: 8) {
                SearchField(text: $searchText)
                    .frame(maxWidth: 200)
                
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.borderless)
                }
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.medium)
                }
                .disabled(isRefreshing)
                .buttonStyle(.borderless)
                
                Button(action: { showDownloadManager.toggle() }) {
                    Image(systemName: "arrow.down.circle")
                        .imageScale(.medium)
                }
                .disabled(isRefreshing)
                .buttonStyle(.borderless)
                .overlay(
                    Group {
                        if downloadTasksCount > 0 {
                            Text("\(downloadTasksCount)")
                                .font(.caption2)
                                .padding(3)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .foregroundColor(.white)
                                .offset(x: 8, y: -8)
                        }
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
} 