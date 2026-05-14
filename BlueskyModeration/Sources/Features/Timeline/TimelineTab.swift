import SwiftUI

struct TimelineTab: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var blueskyClient: LiveBlueskyClient
    @StateObject private var viewModel = FeedTimelineViewModel()

    var body: some View {
        FeedTimelineView(viewModel: viewModel)
            .environmentObject(accountStore)
            .environmentObject(blueskyClient)
            .onAppear {
                syncFeedStore()
            }
            .onChange(of: accountStore.activeAccount?.did) { _, _ in
                viewModel.prepareForAccountChange()
                syncFeedStore()
            }
    }

    private func syncFeedStore() {
        guard let account = accountStore.activeAccount else { return }
        viewModel.feedStore.setAccount(did: account.did)
    }
}

#Preview {
    TimelineTab()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
