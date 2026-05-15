import SwiftUI

/// Searchable bottom-sheet over the selected exchange's
/// instrument list. Filters by case-insensitive ``symbol``
/// substring as the user types.
struct InstrumentPickerSheet: View {
    let instruments: [InstrumentDetailData]
    let onSelect: (InstrumentDetailData) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filtered: [InstrumentDetailData] {
        guard !query.isEmpty else { return instruments }
        let needle = query.lowercased()
        return instruments.filter { $0.symbol.lowercased().contains(needle) }
    }

    var body: some View {
        NavigationView {
            List(filtered, id: \.symbolPublicId) { instrument in
                Button {
                    onSelect(instrument)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instrument.symbol)
                                .font(.system(.body, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            if let kind = instrument.instrumentKind {
                                Text(kind)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        Spacer()
                        if !instrument.canTrade {
                            Text("View only")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.bgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search instruments")
            .navigationTitle(LocalizedStringKey("market.data.instrumentPicker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("trading.order.cancel")) { dismiss() }
                }
            }
        }
    }
}
