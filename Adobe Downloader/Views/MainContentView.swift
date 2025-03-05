import SwiftUI

struct MainContentView: View {
    let loadingState: LoadingState
    let filteredProducts: [UniqueProduct]
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            switch loadingState {
            case .idle, .loading:
                ProgressView("正在加载...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .failed(let error):
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("加载失败")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .padding(.bottom, 10)
                    
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重试")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .success:
                if filteredProducts.isEmpty {
                    EmptyStateView()
                } else {
                    ProductGridView(products: filteredProducts)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("没有找到产品")
                .font(.headline)
                .padding(.top)
            Text("尝试使用不同的搜索关键词")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProductGridView: View {
    let products: [UniqueProduct]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 20)
                ],
                spacing: 20
            ) {
                ForEach(products, id: \.id) { uniqueProduct in
                    AppCardView(uniqueProduct: uniqueProduct)
                }
            }
            .padding()
            
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 6, height: 6)
                Text("获取到 \(products.count) 款产品")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
        }
    }
} 