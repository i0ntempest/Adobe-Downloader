import SwiftUI

struct BannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Adobe Downloader 完全开源免费: https://github.com/X1a0He/Adobe-Downloader")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal)
        .padding(.bottom, 5)
        .background(Color(.clear))
    }
} 
