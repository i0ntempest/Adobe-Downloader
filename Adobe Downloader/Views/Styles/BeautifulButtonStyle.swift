//
//  Adobe Downloader
//
//  Created by X1a0He.
//

import SwiftUI

public struct BeautifulButtonStyle: ButtonStyle {
    var baseColor: Color
    @State private var isHovering = false
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? baseColor.opacity(0.7) : baseColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(baseColor.opacity(0.2), lineWidth: 1)
                    .opacity(configuration.isPressed ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
} 