//
//  UIExtensions.swift
//  MetalPetalDemo
//
//  Created by YuAo on 2021/4/4.
//

import Foundation
import SwiftUI

extension Color {
    static var secondarySystemBackground: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        #error("Unsupported Platform")
        #endif
    }
}

extension Image {
    init(cgImage: CGImage) {
        #if os(iOS)
        self.init(uiImage: UIImage(cgImage: cgImage))
        #elseif os(macOS)
        self.init(nsImage: NSImage(
            cgImage: cgImage,
            size: CGSize(width: cgImage.width, height: cgImage.height)
        ))
        #else
        #error("Unsupported Platform")
        #endif
    }
}

extension Button {
    func linkButtonStyle() -> some View {
        #if os(macOS)
        return buttonStyle(LinkButtonStyle()).onHover(perform: { isHover in
            if isHover {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        })
        #else
        return self
        #endif
    }
}

extension View {
    func roundedRectangleButtonStyle() -> some View {
        #if os(iOS)
        return padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .background(RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color.secondarySystemBackground))
        #else
        return self
        #endif
    }

    func stackNavigationViewStyle() -> some View {
        #if os(iOS)
        return navigationViewStyle(StackNavigationViewStyle())
        #else
        return self
        #endif
    }

    func groupedListStyle() -> some View {
        #if os(iOS)
        return listStyle(GroupedListStyle())
        #else
        return self
        #endif
    }

    func inlineNavigationBarTitle(_ title: some StringProtocol) -> some View {
        #if os(iOS)
        return navigationBarTitle(title, displayMode: .inline)
        #else
        return navigationTitle(title)
        #endif
    }

    func largeControlSize() -> some View {
        #if os(macOS)
        return controlSize(.large)
        #else
        return self
        #endif
    }

    func smallControlSize() -> some View {
        #if os(macOS)
        return controlSize(.small)
        #else
        return self
        #endif
    }

    func toolbarMenu(_ menu: some View) -> some View {
        #if os(iOS)
        return navigationBarItems(trailing: menu)
        #else
        return toolbar(content: {
            menu
        })
        #endif
    }

    func pickerWidthLimit(_ width: CGFloat) -> some View {
        #if os(macOS)
        return frame(maxWidth: width)
        #else
        return self
        #endif
    }

    func blurBackgroundEffect(cornerRadius: CGFloat) -> some View {
        #if os(macOS)
        return background(VisualEffectBlur(
            material: .hudWindow,
            blendingMode: .withinWindow,
            state: .followsWindowActiveState
        ).clipShape(RoundedRectangle(cornerRadius: cornerRadius)))
        #elseif os(iOS)
        return background(VisualEffectBlur(blurStyle: .systemThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius)))
        #endif
    }
}

#if os(iOS)

extension UIApplication {
    var topMostViewController: UIViewController? {
        let rootWindow = windows.first(where: { $0.isHidden == false })
        var topMostViewController: UIViewController? = rootWindow?.rootViewController
        while topMostViewController?.presentedViewController != nil {
            topMostViewController = topMostViewController?.presentedViewController
        }
        return topMostViewController
    }
}

#endif
