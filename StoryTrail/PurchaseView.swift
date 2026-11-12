import StoreKit
import SwiftUI

struct PurchaseView: View {
    let tour: Tour
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseStore: PurchaseStore
    @State private var isPresentingOfferCodeRedemption = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TrailPageHeader(
                        eyebrow: "Unlock your walk",
                        title: "More stories, more places.",
                        subtitle:
                            "Unlock this complete walking tour once and keep its stories ready offline."
                    )

                    purchaseCard(
                        eyebrow: "This tour",
                        title: tour.title,
                        detail: "\(tour.stops.count) stories · \(tour.minutes) minutes · offline access",
                        price: purchaseStore.product(for: tour)?.displayPrice ?? "Unavailable",
                        productID: PurchaseConfiguration.productID(for: tour.id),
                        highlighted: false,
                        action: { await purchaseStore.purchaseTour(tour) },
                    )

                    Button("Restore Purchases") {
                        Task { await purchaseStore.restorePurchases() }
                    }
                    .font(.trailBody(16, weight: .bold))
                    .foregroundStyle(TrailColor.green)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .disabled(purchaseStore.isLoading || purchaseStore.purchasingProductID != nil)

                    Button("Have a promo code? Redeem here") {
                        isPresentingOfferCodeRedemption = true
                    }
                    .font(.trailBody(15, weight: .bold))
                    .foregroundStyle(TrailColor.green)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .disabled(purchaseStore.purchasingProductID != nil)

                    if purchaseStore.product(for: tour) == nil {
                        Text(offlinePriceMessage)
                            .font(.trailBody(13))
                            .foregroundStyle(TrailColor.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    Text("Purchases are handled by Apple and are available on devices signed in with your Apple ID.")
                        .font(.trailBody(13))
                        .foregroundStyle(TrailColor.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(22)
            }
            .creamBackground()
            .navigationTitle("Tour Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: purchaseStore.hasAccess(to: tour)) { _, hasAccess in
            if hasAccess { dismiss() }
        }
        .modifier(
            OfferCodeRedemptionPresenter(
                isPresented: $isPresentingOfferCodeRedemption,
                purchaseStore: purchaseStore
            )
        )
        .alert(
            "Purchase problem",
            isPresented: Binding(
                get: { purchaseStore.errorMessage != nil },
                set: { if !$0 { purchaseStore.clearError() } },
            ),
            actions: { Button("OK") { purchaseStore.clearError() } },
            message: { Text(purchaseStore.errorMessage ?? "Please try again.") },
        )
    }

    private var offlinePriceMessage: String {
        if let fallbackPrice = PurchaseConfiguration.fallbackCanadianPrice(for: tour.id) {
            return "Expected Canadian price: \(fallbackPrice). Connect to load Apple's confirmed localized price. "
                + "Tours you already unlocked still work offline."
        }
        return "Connect to load Apple's confirmed price. Tours you already unlocked still work offline."
    }

    private func purchaseCard(
        eyebrow: String,
        title: String,
        detail: String,
        price: String,
        productID: String?,
        highlighted: Bool,
        action: @escaping () async -> Void,
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TrailEyebrow(text: eyebrow, color: highlighted ? TrailColor.green : TrailColor.muted)
                Spacer()
                if highlighted {
                    Image(systemName: "sparkles")
                        .foregroundStyle(TrailColor.coral)
                        .accessibilityHidden(true)
                }
            }
            Text(title)
                .font(.trailTitle(25))
                .foregroundStyle(TrailColor.ink)
            Text(detail)
                .font(.trailBody(15))
                .foregroundStyle(TrailColor.muted)
            Button {
                Task { await action() }
            } label: {
                HStack {
                    if let productID, purchaseStore.purchasingProductID == productID {
                        ProgressView().tint(.white)
                    }
                    Text(
                        price == "Unavailable"
                            ? (purchaseStore.isLoading ? "Loading price…" : "Price unavailable")
                            : "Unlock for \(price)"
                    )
                    .font(.trailBody(17, weight: .bold))
                }
                .foregroundStyle(TrailColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .frame(minHeight: 54)
                .background(
                    price == "Unavailable" ? TrailColor.unavailableAction : TrailColor.action,
                    in: RoundedRectangle(cornerRadius: TrailShape.button)
                )
            }
            .buttonStyle(TrailPressStyle())
            .disabled(productID == nil || price == "Unavailable" || purchaseStore.purchasingProductID != nil)
        }
        .padding(.vertical, 20)
        .overlay(alignment: .top) { Divider().overlay(TrailColor.line) }
    }
}

private struct OfferCodeRedemptionPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @ObservedObject var purchaseStore: PurchaseStore

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.offerCodeRedemption(options: [], isPresented: $isPresented) { result in
                Task { await purchaseStore.processOfferCodeRedemption(result) }
            }
        } else {
            content.offerCodeRedemption(isPresented: $isPresented)
        }
    }
}
