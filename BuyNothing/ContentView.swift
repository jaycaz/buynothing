import SwiftUI

struct ContentView: View {
    let neighbors = MockData.neighbors
    let nudges = MockData.sampleNudges
    #if DEBUG
    @State private var showingCollageDemo = false
    @State private var showingSnapshot = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BuyNothing")
                            .font(.largeTitle.bold())
                        Text("Your neighborhood commons")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    #if DEBUG
                    Button {
                        showingSnapshot = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .accessibilityLabel("One-shot collage prototype")
                    #endif
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Nudges section
                if !nudges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Nudges", icon: "sparkles")
                        ForEach(nudges) { nudge in
                            NudgeCard(nudge: nudge)
                        }
                    }
                    .padding(.horizontal)
                }

                // Neighbors section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Neighbors", icon: "person.2")
                        .padding(.horizontal)
                    ForEach(neighbors) { neighbor in
                        NeighborCard(neighbor: neighbor)
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        #if DEBUG
        .sheet(isPresented: $showingCollageDemo) {
            CollageDemoView()
        }
        .sheet(isPresented: $showingSnapshot) {
            SnapshotCollageView()
        }
        #endif
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
        }
    }
}

struct NudgeCard: View {
    let nudge: Nudge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(nudge.message)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label(nudge.tossedItem.title, systemImage: nudge.tossedItem.category.systemImageName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(nudge.wish.text, systemImage: "heart")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

struct NeighborCard: View {
    let neighbor: Neighbor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name + neighborhood
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(neighbor.name)
                        .font(.headline)
                    Text(neighbor.neighborhood)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(neighbor.tossedItems.count) tossed")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Capsule())
            }

            // Tossed items
            if !neighbor.tossedItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sharing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(neighbor.tossedItems) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.category.systemImageName)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            Text(item.title)
                                .font(.subheadline)
                            Spacer()
                            Text(item.condition.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Wishes
            if !neighbor.wishes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Looking for")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(neighbor.wishes) { wish in
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.orange.opacity(0.8))
                                .frame(width: 16)
                            Text(wish.text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ContentView()
}
