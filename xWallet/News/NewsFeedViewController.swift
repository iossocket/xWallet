//
//  NewsFeedViewController.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/3/26.
//

import UIKit
import Nuke
import NukeExtensions
import SwiftUI
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.xBg0)
        setupCollectionView()
        setupDataSource()
        setupRefreshControl()
        observeRepository()

        Task {
//            try await Task.sleep(nanoseconds: 1_000_000_000)
            await repository.loadFirstPage()
        }
    }
    
    private func observeRepository() {
        withObservationTracking {
            _ = repository.items
            _ = repository.isRefreshing
            _ = repository.error
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeRepository()
                self.applySnapshot(items: self.repository.items, animated: true)

                if !self.repository.isRefreshing {
                    self.collectionView.refreshControl?.endRefreshing()
                }
            }
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
                return section

            case .none:
                fatalError("Unknown section \(sectionIndex)")
            }
        }
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
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
                return cell

            case .none:
                fatalError("Unknown section")
            }
        }
    }

    private func setupRefreshControl() {
        let rc = UIRefreshControl()
        rc.tintColor = UIColor(Color.xAccent)
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = rc
    }

    @objc private func handleRefresh() {
        Task { await repository.refresh() }
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height

        let threshold = frameHeight * 3
        if offsetY > contentHeight - frameHeight - threshold, contentHeight > 0 {
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
