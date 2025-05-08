//
//  Ext.swift
//  app
//
//  Created by L7Studio on 20/1/25.
//
import SwiftUI

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

func hideKeyboard() {
    let resign = #selector(UIResponder.resignFirstResponder)
    UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
}

extension TimeInterval {
    public func timeString(showMilliseconds: Bool = true) -> String {
        let ti = NSInteger(self)
        let ds = Int((self.truncatingRemainder(dividingBy: 1)) * 10)
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)
        if showMilliseconds {
            if hours > 0 {
                return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, ds)
            }
            return String(format: "%02d:%02d.%02d", minutes, seconds, ds)
        }
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct MiniTrackProgressStyle: ProgressViewStyle {
    var strokeColor = SwiftUI.Color.accentColor.opacity(0.8)
    func makeBody(configuration: Configuration) -> some View {
        let fractionCompleted = configuration.fractionCompleted ?? 0
        
        return ZStack {
            GeometryReader { reader in
                Path { path in
                    path.addLines([
                        .init(x: 0, y: 0),
                        .init(x: reader.size.width, y: 0),
                    ])
                }
                .trim(from: 0, to: fractionCompleted)
                .stroke(strokeColor, lineWidth: reader.size.height * 2)
            }
        }
    }
}
