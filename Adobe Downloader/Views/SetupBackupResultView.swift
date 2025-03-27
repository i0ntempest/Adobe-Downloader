//
//  SetupBackupResultView.swift
//  Adobe Downloader
//
//  Created by X1a0He on 3/27/25.
//
import SwiftUI

struct SetupBackupResultView: View {
    let isSuccess: Bool
    let message: String
    let onDismiss: () -> Void
    
    init(isSuccess: Bool, message: String, onDismiss: @escaping () -> Void) {
        self.isSuccess = isSuccess
        self.message = message
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 20) {

            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(isSuccess ? .green : .red)
                .padding(.top, 20)

            Text(isSuccess ? "备份成功" : "备份失败")
                .font(.title3)
                .bold()
                .padding(.top, 5)

            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .foregroundColor(.secondary)

            Button(action: onDismiss) {
                Text("确定")
                    .frame(width: 120, height: 24)
                    .foregroundColor(.white)
            }
            .buttonStyle(BeautifulButtonStyle(baseColor: isSuccess ? Color.green : Color.blue))
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 20)
        }
        .frame(width: 350)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 2)
    }
}
