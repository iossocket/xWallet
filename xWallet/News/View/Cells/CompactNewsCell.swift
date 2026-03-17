//
//  CompactNewsCell.swift
//  xWallet
//
//  Created by Xueliang Zhu on 16/3/26.
//

import UIKit
import Nuke
import NukeExtensions
import SnapKit
import SwiftUI

final class CompactNewsCell: UICollectionViewCell {
    static let reuseIdentifier = "CompactNewsCell"

    let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = XRadius.md
        iv.backgroundColor = UIColor(Color.xBg2)
        return iv
    }()

    private let placeholderIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "newspaper"))
        iv.tintColor = UIColor(Color.xTextTertiary)
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor(Color.xTextPrimary)
        label.numberOfLines = 2
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(Color.xTextSecondary)
        label.numberOfLines = 2
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = UIColor(Color.xTextTertiary)
        return label
    }()

    private let tagStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = XSpacing.xs
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(Color.xBg1)
        contentView.layer.cornerRadius = XRadius.md
        contentView.clipsToBounds = true
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        contentView.addSubview(thumbnailView)
        thumbnailView.addSubview(placeholderIcon)
        contentView.addSubview(titleLabel)
        contentView.addSubview(summaryLabel)
        contentView.addSubview(metaLabel)
        contentView.addSubview(tagStack)

        thumbnailView.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(XSpacing.md)
            $0.size.equalTo(CGSize(width: 80, height: 80))
            $0.bottom.lessThanOrEqualToSuperview().inset(XSpacing.md)
        }
        placeholderIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(XSpacing.md)
            $0.leading.equalTo(thumbnailView.snp.trailing).offset(XSpacing.md)
            $0.trailing.equalToSuperview().inset(XSpacing.md)
        }
        summaryLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(XSpacing.xs)
            $0.leading.trailing.equalTo(titleLabel)
        }
        metaLabel.snp.makeConstraints {
            $0.top.equalTo(summaryLabel.snp.bottom).offset(XSpacing.xs)
            $0.leading.equalTo(titleLabel)
        }
        tagStack.snp.makeConstraints {
            $0.centerY.equalTo(metaLabel)
            $0.leading.equalTo(metaLabel.snp.trailing).offset(XSpacing.sm)
            $0.trailing.lessThanOrEqualToSuperview().inset(XSpacing.md)
            $0.bottom.lessThanOrEqualToSuperview().inset(XSpacing.md)
        }
    }

    func configure(with item: NewsItem) {
        titleLabel.text = item.title
        summaryLabel.text = item.summary
        metaLabel.text = formatMeta(source: item.sourceName, date: item.publishedAt)
        configureTags(item.tags)

        if let urlString = item.imageURL, let url = URL(string: urlString) {
            placeholderIcon.isHidden = true
            let request = ImageRequest(
                url: url,
                processors: [.resize(size: CGSize(width: 80, height: 80), contentMode: .aspectFill)]
            )
            let options = ImageLoadingOptions(
                placeholder: nil,
                transition: .fadeIn(duration: 0.15)
            )
            NukeExtensions.loadImage(with: request, options: options, into: thumbnailView)
        } else {
            thumbnailView.image = nil
            placeholderIcon.isHidden = false
        }
    }

    private func configureTags(_ tags: [String]) {
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tag in tags.prefix(2) {
            let pill = TagPillView(text: tag)
            tagStack.addArrangedSubview(pill)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        NukeExtensions.cancelRequest(for: thumbnailView)
        thumbnailView.image = nil
        placeholderIcon.isHidden = true
        titleLabel.text = nil
        summaryLabel.text = nil
        metaLabel.text = nil
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}

// MARK: - Tag Pill

private final class TagPillView: UIView {
    init(text: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(Color.xBg3)
        layer.cornerRadius = XRadius.sm / 2

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = UIColor(Color.xAccentLight)
        addSubview(label)
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 2, left: XSpacing.xs, bottom: 2, right: XSpacing.xs
            ))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
