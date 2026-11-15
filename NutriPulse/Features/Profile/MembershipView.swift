import SwiftUI
import StoreKit

struct MembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: MembershipStore
    @State private var showManage = false
    private let isPreview: Bool

    init(store: MembershipStore = .shared, isPreview: Bool = false) {
        _store = State(initialValue: store)
        self.isPreview = isPreview
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("More support, on your terms.").font(Theme.Fonts.display(30, .bold))
                    Text("Pulse coaching, AI food logging, and weekly guidance are included with Footing premium.")
                        .font(Theme.Fonts.body(17))
                    accessStatus
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Pulse conversations and weekly guidance", systemImage: "bubble.left.and.bubble.right")
                        Label("Describe a meal with AI food logging", systemImage: "waveform")
                        Text("Includes \(store.snapshot?.pulseLimit ?? 60) Pulse requests and \(store.snapshot?.foodLimit ?? 60) AI meal requests per calendar month (UTC). Weekly guidance uses a Pulse request. Retries count toward the allowance.")
                            .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                        if let value = store.snapshot {
                            Text("This month: \(value.pulseUsed)/\(value.pulseLimit) Pulse · \(value.foodUsed)/\(value.foodLimit) AI meals")
                                .font(Theme.Fonts.body(13)).accessibilityIdentifier("membershipUsage")
                        }
                    }.tile()
                    purchaseOptions
                    Text("Always free: manual tracking, food search and barcode scanning, saved meals, Apple Health integration, practical tools, and access to your saved records. Privacy controls and account deletion stay available.")
                        .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    if let message = store.errorMessage { Text(message).foregroundStyle(Theme.Colors.danger).accessibilityIdentifier("membershipError") }
                    if let notice = store.notice { Text(notice).foregroundStyle(Theme.Colors.textSecondary).accessibilityIdentifier("membershipNotice") }
                    Button("Restore purchases") { Task { await store.restore() } }.frame(minHeight: 44).disabled(isPreview || store.isBusy)
                    Button("Manage Apple subscription") { showManage = true }.frame(minHeight: 44).disabled(isPreview)
                    HStack(spacing: 20) {
                        Link("Privacy policy", destination: Config.privacyPolicyURL).frame(minHeight: 44)
                        Link("Terms of use", destination: Config.termsOfUseURL).frame(minHeight: 44)
                    }.font(Theme.Fonts.body(13))
                    Button("Refresh membership") { Task { await store.refresh(); await store.loadProduct() } }.frame(minHeight: 44).disabled(isPreview || store.isBusy || store.isRefreshing)
                }
                .font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textPrimary)
                .padding(Theme.Spacing.page).daylightReadableWidth(650)
            }
            .background(Theme.Colors.ground)
            .navigationTitle("Your membership").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .manageSubscriptionsSheet(isPresented: $showManage)
        }
        .task {
            if !isPreview { store.startListening(); await store.refresh(); await store.loadProduct(); return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--membership-storekit-preview") { await store.loadProduct() }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in if !isPreview && phase == .active { Task { await store.refresh() } } }
    }

    @ViewBuilder private var accessStatus: some View {
        if let until = store.snapshot?.founderUntil, until > .now {
            VStack(alignment: .leading, spacing: 8) {
                Text("You’re a founding member").font(Theme.Fonts.display(22, .bold))
                Text("Premium is free through \(until.formatted(date: .abbreviated, time: .omitted)). It ends automatically. You won’t be charged unless you choose a subscription later.")
            }.tile(Theme.Colors.lime)
        } else if store.hasPremium, let until = store.snapshot?.subscribedUntil {
            Text("Your subscription includes premium access through \(until.formatted(date: .abbreviated, time: .omitted)). Manage renewal and billing with Apple.").tile()
        } else if store.isRefreshing {
            ProgressView("Checking your membership…")
        } else {
            Text(store.snapshot?.founderClaimed == true ? "Your founding access has ended. Your saved records are still here. Choose a subscription whenever you’re ready." : "Your free tracking stays yours, with or without premium.").tile()
        }
    }

    @ViewBuilder private var purchaseOptions: some View {
        if store.snapshot?.enforced == false {
            Text("Premium plans are being prepared. AI features remain available during the free beta; no purchase is needed yet.").tile()
        }
        if store.snapshot?.enforced == true && store.snapshot?.founderAvailable == true && store.snapshot?.founderClaimed == false && !store.hasPremium {
            VStack(alignment: .leading, spacing: 12) {
                Text("Three months, on us").font(Theme.Fonts.display(22, .bold))
                Text("The first 50 accounts to claim founding access get three calendar months of premium. No payment details. No automatic billing.")
                Button("Claim three free months") { Task { await store.claim() } }
                    .buttonStyle(.brandPrimary).disabled(isPreview || store.isBusy).accessibilityIdentifier("claimFoundingMembership")
            }.tile(Theme.Colors.violet)
        }
        if store.snapshot?.enforced == true && store.snapshot?.founderUntil.map({ $0 > .now }) != true && !store.hasPremium {
            if let product = store.product {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(product.displayPrice) per month").font(Theme.Fonts.display(24, .bold))
                    Text("Payment is charged to your Apple Account when you confirm. The subscription renews monthly unless canceled at least 24 hours before the current period ends. Manage or cancel in Apple subscription settings.")
                        .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                    Button("Subscribe for \(product.displayPrice)/month") { Task { await store.purchase() } }
                        .buttonStyle(.brandPrimary).disabled(isPreview || store.isBusy || store.snapshot == nil)
                        .accessibilityIdentifier("subscribeMembership")
                }.tile()
            } else { Text("The App Store price will appear when subscriptions are available.").font(Theme.Fonts.body(14)) }
        }
    }
}

struct MembershipProfileSection: View {
    @State private var showMembership = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Membership").font(Theme.Fonts.body(12, .semibold)).foregroundStyle(Theme.Colors.textSecondary)
            Button { showMembership = true } label: {
                HStack {
                    Image(systemName: "sparkles")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your membership").font(Theme.Fonts.body(16, .semibold))
                        Text("Founding access, premium, and purchases").font(Theme.Fonts.body(13))
                    }
                    Spacer(); Image(systemName: "chevron.right")
                }.foregroundStyle(Theme.Colors.textPrimary).padding(16).frame(minHeight: 54)
            }.accessibilityIdentifier("profileMembership")
        }.tile().sheet(isPresented: $showMembership) { MembershipView() }
            .onChange(of: MembershipStore.shared.pendingPurchaseIntent, initial: true) { _, pending in
                if pending { showMembership = true; MembershipStore.shared.consumePurchaseIntent() }
            }
    }
}
