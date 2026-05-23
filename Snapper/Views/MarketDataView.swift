import SwiftUI

/// Market data deep-view screen. Composes a selector bar, the 2x2
/// metric grid, the candlestick chart, and a delayed/live status
/// row. The VM owns selection, snapshots, and WS-driven merges.
///
/// Reached from ``HomeView`` via a permission-gated
/// ``NavigationLink``; the screen itself does not re-check
/// ``Permission.READ_MARKET_DATA`` since the entry already gates.
struct MarketDataView: View {
    @EnvironmentObject var webSocketManager: WebSocketManager
    @Environment(AppState.self) private var appState
    @State private var vm: MarketDataViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView(LocalizedStringKey("market.data.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgBase)
            }
        }
        .navigationTitle(LocalizedStringKey("market.data.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm == nil {
                let viewModel = MarketDataViewModel(webSocketManager: webSocketManager)
                vm = viewModel
                await viewModel.start()
            }
        }
        .onDisappear { vm?.stop() }
    }

    @ViewBuilder
    private func content(vm: MarketDataViewModel) -> some View {
        @Bindable var bindableVM = vm
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MarketSelectorBar(vm: vm)

                InstrumentDescriptionBannerView(
                    underlying: vm.relatedResponse?.payload.underlying,
                    isLoading: vm.isLoadingRelated,
                    language: appState.locale.catalogLanguage
                )

                RelatedInstrumentsRowView(
                    relatedResponse: vm.relatedResponse,
                    selectedExchange: vm.selectedExchange,
                    selectedSymbol: vm.selectedInstrument?.symbol,
                    language: appState.locale.catalogLanguage,
                    onSelect: { exchange, nativeSymbol in
                        Task { await vm.selectMarket(exchange: exchange, symbol: nativeSymbol) }
                    }
                )

                PairStatsRowView(
                    chips: vm.filteredPairChips,
                    language: appState.locale.catalogLanguage,
                    onSelect: { exchange, symbol in
                        Task { await vm.selectMarket(exchange: exchange, symbol: symbol) }
                    }
                )

                MarketMetricGrid(metrics: vm.metrics)

                VStack(alignment: .leading, spacing: 0) {
                    CacheWarmingBannerView(
                        cacheState: vm.cacheState,
                        expected: MarketCacheTarget.expectedSampleCount,
                        language: appState.locale.catalogLanguage
                    )
                    CandlestickChartView(candles: vm.candles, timeframe: vm.selectedTimeframe)
                        .frame(height: 280)
                        .padding(.horizontal, 4)
                }
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                MarketStatusRow(
                    isDelayed: vm.metrics.isDelayed,
                    isReady: vm.isReady,
                    isLoading: vm.isLoading,
                    loadError: vm.loadError
                )
            }
            .padding(16)
        }
        .background(Color.bgBase)
        .sheet(isPresented: $bindableVM.showInstrumentPicker) {
            InstrumentPickerSheet(
                instruments: vm.instruments,
                onSelect: { instrument in
                    Task { await vm.selectInstrument(instrument) }
                }
            )
        }
    }
}
