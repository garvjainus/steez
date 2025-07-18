import SwiftUI
import Kingfisher

struct FrameSelectorView: View {
    let frameUrls: [URL]
    let onFrameSelected: (URL) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select the Clearest Frame")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(frameUrls, id: \.self) { url in
                        Button(action: {
                            onFrameSelected(url)
                        }) {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

#if DEBUG
struct FrameSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleUrls: [URL] = [
            URL(string: "https://via.placeholder.com/120x180.png?text=Frame+1")!,
            URL(string: "https://via.placeholder.com/120x180.png?text=Frame+2")!,
            URL(string: "https://via.placeholder.com/120x180.png?text=Frame+3")!,
            URL(string: "https://via.placeholder.com/120x180.png?text=Frame+4")!,
            URL(string: "https://via.placeholder.com/120x180.png?text=Frame+5")!,
        ]
        
        FrameSelectorView(frameUrls: sampleUrls) { selectedUrl in
            print("Selected frame: \(selectedUrl)")
        }
    }
}
#endif 