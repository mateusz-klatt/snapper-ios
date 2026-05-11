import SwiftUI

/// Three-tier selector header: exchange ``Menu`` → instrument
/// ``Button`` (opens ``InstrumentPickerSheet``) → timeframe
/// segmented ``Picker``.
///
/// Visual style matches the existing card primitives elsewhere in
/// the app — corner radius 12, surface background, BrandGreen
/// accent when the timeframe is active.
struct MarketSelectorBar: View {
    @Bindable var vm: MarketDataViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(vm.exchanges, id: \.self) { exchange in
                        Button(exchange.uppercased()) {
                            Task { await vm.selectExchange(exchange) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.selectedExchange?.uppercased() ?? "Exchange")
                            .font(.system(.body, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.textPrimary)
                }

                Button {
                    vm.showInstrumentPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.selectedInstrument?.symbol ?? "Pick instrument")
                            .font(.system(.body, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "magnifyingglass")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(vm.selectedInstrument == nil ? .textSecondary : .textPrimary)
                }
                .disabled(vm.instruments.isEmpty)
            }

            Picker("Timeframe", selection: Binding(
                get: { vm.selectedTimeframe },
                set: { tf in Task { await vm.selectTimeframe(tf) } }
            )) {
                ForEach(MarketTimeframe.allCases) { timeframe in
                    Text(timeframe.displayName).tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
