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

final class CompactNewsCell: UICollectionViewCell {
    static let reuseIdentifier = "CompactNewsCell"

    private static let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
    private static let summaryFont = UIFont.systemFont(ofSize: 13, weight: .regular)
    private static let metaFont = UIFont.systemFont(ofSize: 11, weight: .medium)
    private static let thumbnailSize: CGFloat = 80

    var cachedHeight: CGFloat = 0

    let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = XRadius.md
        iv.backgroundColor = UIColor.xBg2
        return iv
    }()

    private let placeholderIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "newspaper"))
        iv.tintColor = UIColor.xTextTertiary
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = CompactNewsCell.titleFont
        label.textColor = UIColor.xTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = CompactNewsCell.summaryFont
        label.textColor = UIColor.xTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = CompactNewsCell.metaFont
        label.textColor = UIColor.xTextTertiary
        return label
    }()

    private let tagStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = XSpacing.xs
        return sv
    }()

    private let tagPills: [TagPillView] = [TagPillView(), TagPillView()]

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor.xBg1
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

        for pill in tagPills {
            pill.isHidden = true
            tagStack.addArrangedSubview(pill)
        }

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
        let visibleTags = Array(tags.prefix(tagPills.count))
        for (index, pill) in tagPills.enumerated() {
            if index < visibleTags.count {
                pill.update(text: visibleTags[index])
                pill.isHidden = false
            } else {
                pill.isHidden = true
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cachedHeight = 0
        NukeExtensions.cancelRequest(for: thumbnailView)
        thumbnailView.image = nil
        placeholderIcon.isHidden = true
        tagPills.forEach { $0.isHidden = true }
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        if cachedHeight > 0 {
            layoutAttributes.size.height = cachedHeight
            return layoutAttributes
        }
        return super.preferredLayoutAttributesFitting(layoutAttributes)
    }

    nonisolated static func calculatedHeight(for item: NewsItem, availableWidth: CGFloat) -> CGFloat {
        let textWidth = availableWidth - XSpacing.md * 3 - thumbnailSize
        let maxTitleLines: CGFloat = 2
        let maxSummaryLines: CGFloat = 2

        let titleHeight = textHeight(
            for: item.title,
            font: titleFont,
            width: textWidth,
            maxLines: maxTitleLines
        )

        let summaryHeight = textHeight(
            for: item.summary ?? "",
            font: summaryFont,
            width: textWidth,
            maxLines: maxSummaryLines
        )

        let metaHeight = ceil(metaFont.lineHeight)

        let textTotal = titleHeight + XSpacing.xs + summaryHeight + XSpacing.xs + metaHeight
        let contentHeight = max(thumbnailSize, textTotal)
        return ceil(contentHeight + XSpacing.md * 2)
    }

    nonisolated private static func textHeight(
        for text: String,
        font: UIFont,
        width: CGFloat,
        maxLines: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let maxHeight = ceil(font.lineHeight * maxLines)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return min(ceil(rect.height), maxHeight)
    }
}

// MARK: - Tag Pill

private final class TagPillView: UIView {
    private let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .bold)
        l.textColor = UIColor.xAccentLight
        return l
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor.xBg3
        layer.cornerRadius = XRadius.sm / 2
        addSubview(label)
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 2, left: XSpacing.xs, bottom: 2, right: XSpacing.xs
            ))
        }
    }

    func update(text: String) {
        label.text = text
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
