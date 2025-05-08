//
//  TrackItemView.swift
//  app
//
//  Created by L7Studio on 10/2/25.
//
import SwiftUI
import Kingfisher
import WasmSwiftProtobuf

struct TrackItemView: View {
    let track: WasmSwiftProtobuf.MusicTrack
    var body: some View {
        HStack(alignment: .top) {
            if !track.thumbnail.isEmpty {
                VStack {
                    KFImage(URL(string: track.thumbnail))
                        .resizable()
                        .fade(duration: 0.5)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 60)
                        .cornerRadius(8)
                    Spacer()
                }
            }
           
            VStack(alignment: .leading) {
                Text("\(track.title)")
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(track.author.name)")
                    .font(.footnote)
            }
        }
    }
}
