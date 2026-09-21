import SwiftUI

/// 24-hour electronic program schedule sheet for a television channel.
public struct ChannelEPGSheetView: View {
    let channel: Channel
    @ObservedObject var epgStore = EPGStore.shared
    @Environment(\.dismiss) private var dismiss

    public init(channel: Channel) {
        self.channel = channel
    }

    private var channelPrograms: [EPGProgram] {
        epgStore.programs(for: channel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(width: 60, height: 60)

                            CachedAsyncImage(url: channel.logoURL, targetSize: CGSize(width: 100, height: 100)) { img in
                                img
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .cornerRadius(6)
                            } placeholder: {
                                Image(systemName: "tv")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(channel.name)
                                .font(.title3.bold())
                                .foregroundColor(.primary)

                            HStack(spacing: 6) {
                                Text(channel.groupTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(6)

                                if let current = epgStore.currentProgram(for: channel) {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.red).frame(width: 6, height: 6)
                                        Text("CANLI YAYIN")
                                            .font(.caption2.bold())
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Programs Timeline List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Günün Yayın Akışı (\(channelPrograms.count) Program)")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)

                        LazyVStack(spacing: 10) {
                            ForEach(channelPrograms) { program in
                                programRow(program)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Yayın Rehberi (EPG)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func programRow(_ program: EPGProgram) -> some View {
        let isAiring = program.isCurrentlyAiring

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Time Range Pill
                Text(program.timeRangeString)
                    .font(.caption.bold())
                    .foregroundColor(isAiring ? .white : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isAiring ? Color.red : Color.secondary.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                if isAiring {
                    Text(program.formattedRemainingTime)
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(4)
                }
            }

            Text(program.title)
                .font(.system(size: 16, weight: isAiring ? .bold : .medium))
                .foregroundColor(isAiring ? .red : .primary)

            if let desc = program.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Progress bar if currently airing
            if isAiring {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.red)
                            .frame(width: geo.size.width * CGFloat(program.progressPercentage), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isAiring ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}
