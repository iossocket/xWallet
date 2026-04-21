//
//  NewsFeedViewController.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/3/26.
//

import UIKit
import Nuke
import NukeExtensions
import SafariServices

enum NewsFeedSection: Int, CaseIterable {
    case hero
    case feed
}

class NewsFeedViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<NewsFeedSection, NewsItem>!
    private let prefetcher = ImagePrefetcher()
    private let repository = NewsRepository()
    private var heightCache: [String: CGFloat] = [:]
    private var pendingAppends: [NewsItem] = []
    private let statusView = NewsFeedStatusView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.xBg0

        setupCollectionView()
        setupDataSource()
        setupRefreshControl()
        setupStatusView()
        repository.delegate = self
        render(animated: false)
        updateStatusChrome()

        Task {
            await repository.loadFirstPage()
        }
    }

    // MARK: - Setup

    private func setupCollectionView() {
        collectionView = UICollectionView(
            frame: view.bounds,
            collectionViewLayout: createLayout()
        )
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(HeroNewsCell.self, forCellWithReuseIdentifier: HeroNewsCell.reuseIdentifier)
        collectionView.register(CompactNewsCell.self, forCellWithReuseIdentifier: CompactNewsCell.reuseIdentifier)
        collectionView.register(NewsFeedFooterView.self, forSupplementaryViewOfKind: NewsFeedFooterView.elementKind, withReuseIdentifier: NewsFeedFooterView.reuseIdentifier)
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch NewsFeedSection(rawValue: sectionIndex) {
            case .hero:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(280)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 0, leading: XSpacing.lg, bottom: XSpacing.md, trailing: XSpacing.lg
                )
                return section

            case .feed:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(110)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = XSpacing.sm
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 0, leading: XSpacing.lg, bottom: XSpacing.lg, trailing: XSpacing.lg
                )
                
                let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(56))
                let footer = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: footerSize,
                    elementKind: NewsFeedFooterView.elementKind,
                    alignment: .bottom
                )
                section.boundarySupplementaryItems = [footer]
                
                return section

            case .none:
                fatalError("Unknown section \(sectionIndex)")
            }
        }
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            switch NewsFeedSection(rawValue: indexPath.section) {
            case .hero:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: HeroNewsCell.reuseIdentifier, for: indexPath
                ) as! HeroNewsCell
                cell.configure(with: item)
                return cell

            case .feed:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: CompactNewsCell.reuseIdentifier, for: indexPath
                ) as! CompactNewsCell
                cell.configure(with: item)
                cell.cachedHeight = self?.heightCache[item.id] ?? 0
                return cell

            case .none:
                fatalError("Unknown section")
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == NewsFeedFooterView.elementKind,
                  NewsFeedSection(rawValue: indexPath.section) == .feed else { return nil }
            let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: NewsFeedFooterView.elementKind,
                withReuseIdentifier: NewsFeedFooterView.reuseIdentifier,
                for: indexPath
            ) as! NewsFeedFooterView
            footer.onRetry = { [weak self] in
                guard let self else { return }
                Task { await self.repository.loadMore() }
            }
            footer.config(mode: self?.computeFooterMode() ?? .blank)
            return footer
        }
    }

    private func setupRefreshControl() {
        let rc = UIRefreshControl()
        rc.tintColor = UIColor.xAccent
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = rc
    }

    private func setupStatusView() {
        statusView.onRetry = { [weak self] in
            guard let self else { return }
            Task { await self.repository.refresh() }
        }
    }

    private func updateStatusChrome() {
        guard repository.items.isEmpty else {
            if collectionView.backgroundView != nil {
                collectionView.backgroundView = nil
            }
            return
        }
        switch repository.state {
        case .idle, .loading:
            statusView.setMode(.loading)
        case .empty:
            statusView.setMode(.empty(message: "No news yet"))
        case .error(let err):
            statusView.setMode(.error(message: errorMessage(for: err)))
        case .content:
            if collectionView.backgroundView != nil {
                collectionView.backgroundView = nil
            }
            return
        }
        if collectionView.backgroundView !== statusView {
            collectionView.backgroundView = statusView
        }
    }

    private func computeFooterMode() -> NewsFeedFooterView.Mode {
        guard !repository.items.isEmpty else { return .blank }
        if !repository.hasMore {
            return .allLoaded
        }
        switch repository.state {
        case .loading:
            return .loading
        case .error(let err):
            return .error(errorMessage(for: err))
        case .content, .idle, .empty:
            return .blank
        }
    }

    private func refreshFooter() {
        let mode = computeFooterMode()
        let indexPaths = collectionView.indexPathsForVisibleSupplementaryElements(
            ofKind: NewsFeedFooterView.elementKind
        )
        for ip in indexPaths {
            if let footer = collectionView.supplementaryView(
                forElementKind: NewsFeedFooterView.elementKind, at: ip
            ) as? NewsFeedFooterView {
                footer.config(mode: mode)
            }
        }
    }

    private func errorMessage(for error: PaginatorError) -> String {
        switch error {
        case .network:
            return "You appear to be offline. Check your connection and try again."
        case .server(let statusCode):
            return "Server error (\(statusCode)). Please try again later."
        case .validationFailed:
            return "Received invalid data. Please try again."
        case .invalidKey, .store, .unknown, .cancelled:
            return "Something went wrong. Please try again."
        }
    }

    @objc private func handleRefresh() {
        Task { await repository.refresh() }
    }

    private func render(animated: Bool) {
        applySnapshot(items: repository.items, animated: animated)
    }

    private func flushPendingAppends() {
        guard !pendingAppends.isEmpty else { return }
        let items = pendingAppends
        pendingAppends = []
        Task { [weak self] in
            guard let self else { return }
            await self.cacheHeights(for: items)
            var snapshot = self.dataSource.snapshot()
            snapshot.appendItems(items, toSection: .feed)
            await self.dataSource.apply(snapshot, animatingDifferences: false)
            self.refreshFooter()
        }
    }

    private func cacheHeights(for items: [NewsItem]) async {
        let availableWidth = collectionView.bounds.width - XSpacing.lg * 2
        let existingKeys = Set(heightCache.keys)
        let newEntries = await Task.detached(priority: .userInitiated) {
            var result: [String: CGFloat] = [:]
            for item in items where !existingKeys.contains(item.id) {
                result[item.id] = CompactNewsCell.calculatedHeight(
                    for: item, availableWidth: availableWidth
                )
            }
            return result
        }.value
        for (id, height) in newEntries {
            heightCache[id] = height
        }
    }

    private func applySnapshot(items: [NewsItem], animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<NewsFeedSection, NewsItem>()
        snapshot.appendSections(NewsFeedSection.allCases)

        if let first = items.first {
            snapshot.appendItems([first], toSection: .hero)
        }
        if items.count > 1 {
            snapshot.appendItems(Array(items.dropFirst()), toSection: .feed)
        }

        dataSource.apply(snapshot, animatingDifferences: animated)
    }
    
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        heightCache = [:]
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                await self.cacheHeights(for: self.repository.items)
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    }
}

// MARK: - NewsRepositoryDelegate

extension NewsFeedViewController: NewsRepositoryDelegate {
    func newsRepository(_ repository: NewsRepository, didChangeState state: FeedListState) {
        if state != .loading, let rc = collectionView.refreshControl, rc.isRefreshing {
            rc.endRefreshing()
        }
        updateStatusChrome()
        refreshFooter()
    }

    func newsRepository(_ repository: NewsRepository, didReplaceItems items: [NewsItem]) {
        pendingAppends = []
        heightCache = [:]
        Task { [weak self] in
            guard let self else { return }
            await self.cacheHeights(for: items)
            self.applySnapshot(items: items, animated: true)
        }
    }

    func newsRepository(_ repository: NewsRepository, didAppendItems newItems: [NewsItem]) {
        guard !newItems.isEmpty else { return }
        pendingAppends.append(contentsOf: newItems)
        if !collectionView.isDragging && !collectionView.isDecelerating {
            flushPendingAppends()
        }
        refreshFooter()
    }
}

// MARK: - UICollectionViewDelegate

extension NewsFeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let url = URL(string: item.url) else { return }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if let heroCell = cell as? HeroNewsCell {
            NukeExtensions.cancelRequest(for: heroCell.heroImageView)
        } else if let compactCell = cell as? CompactNewsCell {
            NukeExtensions.cancelRequest(for: compactCell.thumbnailView)
        }
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let projectedY = targetContentOffset.pointee.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height
        let threshold = frameHeight * 2
        if contentHeight > 0, projectedY > contentHeight - frameHeight - threshold {
            Task { await repository.loadMore() }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        flushPendingAppends()
        triggerLoadMoreIfNearBottom(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            flushPendingAppends()
            triggerLoadMoreIfNearBottom(scrollView)
        }
    }

    private func triggerLoadMoreIfNearBottom(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height
        guard contentHeight > 0 else { return }
        if y > contentHeight - frameHeight - frameHeight * 0.5 {
            Task { await repository.loadMore() }
        }
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension NewsFeedViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(
        _ collectionView: UICollectionView,
        prefetchItemsAt indexPaths: [IndexPath]
    ) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  let urlString = item.imageURL else { return nil }
            return URL(string: urlString)
        }
        prefetcher.startPrefetching(with: urls)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cancelPrefetchingForItemsAt indexPaths: [IndexPath]
    ) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  let urlString = item.imageURL else { return nil }
            return URL(string: urlString)
        }
        prefetcher.stopPrefetching(with: urls)
    }
}
