//
//  SetupBackupAlertView.swift
//  Adobe Downloader
//
//  Created by X1a0He on 3/27/25.
//
import SwiftUI

struct SetupBackupAlertView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var isHovering = false
    @State private var countdown = 10
    @State private var isCountdownActive = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName)!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .padding(.top, 10)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                        .offset(x: 30, y: 30)
                )

            Text("Setup未备份提示")
                .font(.headline)
                .padding(.top, 5)

            Text("检测到Setup文件尚未备份，如果你需要安装程序，则Setup必须被处理，点击确定后你需要输入密码，Adobe Downloader将自动处理并备份为Setup.original")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                Button(action: onCancel) {
                    Text("取消")
                        .frame(width: 120, height: 24)
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.gray.opacity(0.8)))

                #if DEBUG
                Button(action: onConfirm) {
                    Text("确定")
                        .frame(width: 120, height: 24)
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .blue))
                .keyboardShortcut(.defaultAction)
                #else
                Button(action: isCountdownActive && countdown == 0 ? onConfirm : {
                    isCountdownActive = true
                }) {
                    Text(isCountdownActive && countdown > 0 ? "\(countdown)" : "确定")
                        .frame(width: 120, height: 24)
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: isCountdownActive && countdown > 0 ? Color.blue.opacity(0.6) : .blue))
                .disabled(isCountdownActive && countdown > 0)
                .keyboardShortcut(.defaultAction)
                .onReceive(timer) { _ in
                    if isCountdownActive && countdown > 0 {
                        countdown -= 1
                    }
                }
                #endif
            }
            .padding(.bottom, 20)
        }
        .frame(width: 400)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 2)
        .onAppear {
            #if !DEBUG
            isCountdownActive = true
            #endif
        }
    }
}
