import SwiftUI
import Combine
import Foundation

public struct CardContainer<Content: View>: View {
    @EnvironmentObject private var theme: AppTheme
    private let padding: CGFloat
    private let content: () -> Content

    public init(padding: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background(theme.cardBackground())
    }
}

public struct DividerLine: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(ColorTokens.outlineDark)
            .frame(height: 1)
            .opacity(0.9)
    }
}

public struct LabeledValueRow: View {
    public let title: String
    public let value: String
    public let iconSystem: String?

    public init(title: String, value: String, iconSystem: String? = nil) {
        self.title = title
        self.value = value
        self.iconSystem = iconSystem
    }

    public var body: some View {
        HStack {
            if let icon = iconSystem {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

public struct StatPill: View {
    public let iconSystem: String
    public let title: String
    public let value: String

    public init(iconSystem: String, title: String, value: String) {
        self.iconSystem = iconSystem
        self.title = title
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 4) {
            Label(value, systemImage: iconSystem)
                .font(.footnote)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }
}

public struct EmptyStateView: View {
    public let systemImage: String
    public let title: String
    public let message: String?

    public init(systemImage: String = "tray", title: String, message: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let msg = message, !msg.isEmpty {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }
}

public struct MoodBadgeView: View {
    public let kind: MoodKind

    public init(_ kind: MoodKind) {
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(kind.emoji).font(.system(size: 22))
            Text(kind.label).font(.subheadline)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(MoodTaxonomy.gradient(for: kind))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

public struct NumberField: View {
    public let title: String
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    @State private var text: String = ""

    public init(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) {
        self.title = title
        self._value = value
        self.range = range
        self._text = State(initialValue: String(value.wrappedValue))
    }

    public var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: Binding(
                get: { text },
                set: { newVal in
                    text = newVal.filter { $0.isNumber }
                    let intVal = Int(text) ?? value
                    let clamped = min(max(intVal, range.lowerBound), range.upperBound)
                    if clamped != value { value = clamped }
                    text = String(clamped)
                }
            ))
            .multilineTextAlignment(.trailing)
            .keyboardType(.numberPad)
            .frame(width: 80)
        }
        .onChange(of: value) { newVal in
            let clamped = min(max(newVal, range.lowerBound), range.upperBound)
            if clamped != newVal { value = clamped }
            text = String(clamped)
        }
    }
}

public struct SegmentedPicker<T: Hashable & CaseIterable & Identifiable & CustomStringConvertible>: View {
    @Binding private var selection: T
    public init(selection: Binding<T>) {
        self._selection = selection
    }
    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(T.allCases)) { item in
                Text(item.description).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }
}

public struct IconTextButton: View {
    @EnvironmentObject private var theme: AppTheme
    private let title: String
    private let systemImage: String
    private let prominent: Bool
    private let action: () -> Void

    public init(title: String, systemImage: String, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
        self.action = action
    }

    public var body: some View {
        if prominent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                ProminentButtonStyle(
                    fg: .black,
                    bg: theme.primary,
                    radius: theme.cornerRadiusM
                )
            )
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                TonalButtonStyle(
                    fg: theme.textPrimary,
                    bg: theme.surface,
                    radius: theme.cornerRadiusM,
                    stroke: theme.outline
                )
            )
        }
    }
}

public struct SectionHeader: View {
    public let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
        }.padding(.bottom, 4)
    }
}
