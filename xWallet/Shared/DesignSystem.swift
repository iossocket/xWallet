//
//  DesignSystem.swift
//  xWallet
//
//  Design tokens for colors, typography, spacing, and animation.
//  All Views should reference these instead of literal values.
//

import SwiftUI

// MARK: - Colors

extension Color {
    // Background layers
    static let xBg0    = Color(hex: "050505")   // deepest background
    static let xBg1    = Color(hex: "0F0F12")   // card background (slight blue tint)
    static let xBg2    = Color(hex: "1A1A20")   // secondary card, input fields
    static let xBg3    = Color(hex: "252530")   // floating elements, dividers

    // Brand — purple (Phantom-inspired, not plain blue)
    static let xAccent      = Color(hex: "7B61FF")
    static let xAccentLight = Color(hex: "A78BFA")
    static let xAccentGlow  = Color(hex: "7B61FF").opacity(0.3)

    // Semantic
    static let xGreen  = Color(hex: "22C55E")   // up / success
    static let xRed    = Color(hex: "EF4444")   // down / danger
    static let xYellow = Color(hex: "F59E0B")   // warning
    static let xBlue   = Color(hex: "3B82F6")   // info

    // Privacy mode accent (Railgun green)
    static let xPrivacyAccent = Color(hex: "00D395")
    static let xPrivacyGlow   = Color(hex: "00D395").opacity(0.25)

    // Text hierarchy
    static let xTextPrimary   = Color.white
    static let xTextSecondary = Color(hex: "9CA3AF")
    static let xTextTertiary  = Color(hex: "4B5563")

    // Borders
    static let xBorder       = Color.white.opacity(0.08)
    static let xBorderStrong = Color.white.opacity(0.15)
}

// MARK: - Typography

extension Font {
    // Display — large balance numbers
    static let xDisplay   = Font.system(size: 40, weight: .bold,     design: .rounded)
    static let xDisplaySm = Font.system(size: 28, weight: .bold,     design: .rounded)

    // Titles
    static let xTitle1    = Font.system(size: 22, weight: .bold)
    static let xTitle2    = Font.system(size: 18, weight: .semibold)
    static let xTitle3    = Font.system(size: 16, weight: .semibold)

    // Body
    static let xBody       = Font.system(size: 15, weight: .regular)
    static let xBodyMedium = Font.system(size: 15, weight: .medium)

    // Caption
    static let xCaption     = Font.system(size: 13, weight: .regular)
    static let xCaptionBold = Font.system(size: 13, weight: .semibold)

    // Label — badges, tags
    static let xLabel     = Font.system(size: 11, weight: .medium)
    static let xLabelBold = Font.system(size: 11, weight: .bold)

    // Monospaced — addresses, hashes, precise amounts
    static let xMono   = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let xMonoSm = Font.system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - Spacing

enum XSpacing {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

enum XRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 28
    static let full: CGFloat = 999
}

// MARK: - Animation

extension Animation {
    /// Standard interaction — button taps, state toggles
    static let xStandard   = Animation.spring(response: 0.35, dampingFraction: 0.75)
    /// Page transitions
    static let xTransition = Animation.spring(response: 0.45, dampingFraction: 0.80)
    /// Balance / numeric updates
    static let xNumeric    = Animation.spring(response: 0.50, dampingFraction: 0.90)
    /// Quick snappy feedback
    static let xSnappy     = Animation.spring(response: 0.25, dampingFraction: 0.70)
}

// MARK: - View Modifiers

extension View {
    /// Standard frosted-glass card style
    func xCard(radius: CGFloat = XRadius.xl) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.xBorder, lineWidth: 1)
            )
    }

    /// Solid dark card style
    func xSolidCard(radius: CGFloat = XRadius.xl) -> some View {
        self
            .background(Color.xBg1)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.xBorder, lineWidth: 1)
            )
    }

    /// Accent glow shadow (use on primary buttons / active elements)
    func xAccentGlow() -> some View {
        self.shadow(color: Color.xAccentGlow, radius: 16, x: 0, y: 4)
    }
}
