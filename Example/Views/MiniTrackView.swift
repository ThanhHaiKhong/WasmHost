//
//  MiniTrackView.swift
//  app
//
//  Created by L7Studio on 4/2/25.
//

import SwiftUI
import Kingfisher
import WasmSwiftProtobuf

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        (UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets ?? .zero).insets
    }
}

extension EnvironmentValues {
    
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {    
    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
struct MiniPlayerOverlayList<ContentView: View>: View {
    @Bindable var player: Player
    @Binding var details: Bool
    @ViewBuilder var content: () -> ContentView
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    var body: some View {
        List(content: content)
            .contentMargins(
                .bottom,
                self.player.track != nil ? ((self.details ? 200 - safeAreaInsets.bottom : 50) + 16 + 8) : 0,
                for: .scrollContent
         )
    }
}

struct MiniTrackView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Namespace var animation
    let track: WasmSwiftProtobuf.MusicTrack
    @Bindable var player: Player
    @Binding var details: Bool
    var body: some View {
        VStack {
            Spacer()
            ZStack {
                ProgressView(value: player.progress)
                    .progressViewStyle(MiniTrackProgressStyle())
                    .contentShape(Rectangle())
                    .cornerRadius(8)
                
                HStack(alignment: .top) {
                    if let url = URL(string: track.thumbnail) {
                        VStack {
                            ZStack {
                                KFImage(url)
                                    .resizable()
                                    .fade(duration: 0.5)
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: (self.details ? 200 - safeAreaInsets.bottom : 50))

                                Color.black
                                    .opacity(0.3)
                                    .aspectRatio(1, contentMode: .fit)
                                self.player
                                    .indicatorView()
                                    .tint(.white)
                            }
                            .cornerRadius(8)
                            .onTapGesture {
                                self.player.toggle()
                            }
                            
                            Spacer()
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("\(track.title)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("\(track.author.name)")
                            Spacer()
                            if player.duration > 0 && player.duration.isFinite {
                                Text("-\((player.duration - player.currentTime).timeString(showMilliseconds: false))")
                            }
                        }
                        .font(.footnote)
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .lineLimit(self.details ? 3 : 1)
                    
                    Spacer()
                }
                .padding(EdgeInsets(top: 8, leading: 8, bottom: self.details ? safeAreaInsets.bottom : 0, trailing: 8))
                
            }
            .frame(height: (self.details ? 200 : 50) + 16)
            .background(RoundedRectangle(cornerRadius: 8).fill(.thinMaterial))
            .padding(EdgeInsets(top: 0,
                                leading: self.details ? 0 : 8,
                                bottom: self.details ? 0 : safeAreaInsets.bottom,
                                trailing: self.details ? 0 : 8))
        }
        .onTapGesture {
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                self.details.toggle()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview("Track Items") {
    @Previewable @Namespace var animation
    @Previewable @State var details: Bool = false
    let trackJson = """
            {
              "id": "kPa7bsKwL-c",
              "title": "Lady Gaga, Bruno Mars - Die With A Smile (Official Music Video)",
              "author": {
                "id": "UCNL1ZadSjHpjm4q9j2sVtOA",
                "name": "Lady Gaga",
                "thumbnail": "https://yt3.ggpht.com/GItB-g3kPf6WOCfcSaHwuiNFsdJRNu5EeuQfhbwKNnNWIOS2Nhwx4g-JeARQLtrhO6uAnjq2=s88-c-k-c0x00ffffff-no-rj"
              },
              "thumbnail": "https://i.ytimg.com/vi/kPa7bsKwL-c/hq720.jpg?sqp=-oaymwEcCOgCEMoBSFXyq4qpAw4IARUAAIhCGAFwAcABBg==&rs=AOn4CLDWJv1szFrySyao_qntdcn8uJi86w"
            }
            """
    
    let track = try! MusicTrack(jsonString: trackJson)
    lazy var player = Player(progress: 0.2, track: track)
    ZStack {
        ZStack(alignment: .bottom) {
            MiniPlayerOverlayList(player: player, details: $details) {
                ForEach(0..<10) { _ in
                    TrackItemView(track: try! MusicTrack(jsonString: trackJson))
                }
            }
            MiniTrackView(track: track, player: player, details: $details)
                .matchedGeometryEffect(id: track.id, in: animation)
        }
        
    }
    
}
