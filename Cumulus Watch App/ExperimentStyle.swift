import SwiftUI

struct ExperimentPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .background(.black)
        .tint(.blue)
    }
}

struct ExperimentCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ExperimentHeading: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ExperimentPageHeading<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "cloud.fill")
                .font(.caption)
                .foregroundStyle(.blue.opacity(0.65))
                .accessibilityHidden(true)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ExperimentMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Normal text") {
    ExperimentStylePreview().dynamicTypeSize(.large)
}

#Preview("Larger text") {
    ExperimentStylePreview().dynamicTypeSize(.xxxLarge)
}

private struct ExperimentStylePreview: View {
    var body: some View {
        ExperimentPage {
            ExperimentPageHeading {
                Text("Explore your\nWatch data.")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            ExperimentCard {
                ExperimentPageHeading {
                    ExperimentHeading(title: "Background motion", symbol: "waveform.path")
                }
                Button {} label: {
                    Text("Stop collection & session")
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.borderedProminent)
            }
            ExperimentCard {
                ExperimentHeading(title: "Timing diagnostics", symbol: "clock")
                ExperimentMetric(label: "Source", value: "Synthetic preview")
                Text("Historical records, ready to explore.").font(.caption)
            }
        }
    }
}
