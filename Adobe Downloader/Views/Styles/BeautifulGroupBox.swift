//
//  BeautifulGroupBox.swift
//  Adobe Downloader
//
//  Created by X1a0He on 3/28/25.
//
import SwiftUI

struct BeautifulGroupBox<Label: View, Content: View>: View {
    let label: Label
    let content: Content

    init(label: @escaping () -> Label, @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}
