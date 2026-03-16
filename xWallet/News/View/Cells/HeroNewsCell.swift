//
//  HeroNewsCell.swift
//  xWallet
//
//  Created by Xueliang Zhu on 16/3/26.
//

import UIKit
import Nuke
import NukeExtensions
import SnapKit
import SwiftUI

final class HeroNewsCell: UICollectionViewCell {
    static let reuseIdentifier = "HeroNewsCell"

    let heroImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = XRadius.lg
        iv.backgroundColor = UIColor(Color.xBg2)
        return iv
    }()

    private let gradientContainer = UIView()

    private let gradientLayer: CAGradientLayer = {
        let gl = CAGradientLayer()
        gl.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        gl.locations = [0.0, 1.0]
        return gl
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
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = UIColor(Color.xTextSecondary)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        contentView.addSubview(heroImageView)
        heroImageView.addSubview(placeholderIcon)
        heroImageView.addSubview(gradientContainer)
        gradientContainer.layer.addSublayer(gradientLayer)
        gradientContainer.addSubview(titleLabel)
        gradientContainer.addSubview(metaLabel)

        heroImageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(heroImageView.snp.width).multipliedBy(9.0 / 16.0)
        }
        placeholderIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(48)
        }
        gradientContainer.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalToSuperview().multipliedBy(0.5)
        }
        titleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(XSpacing.lg)
            $0.bottom.equalTo(metaLabel.snp.top).offset(-XSpacing.xs)
        }
        metaLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(XSpacing.lg)
            $0.bottom.equalToSuperview().inset(XSpacing.lg)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = gradientContainer.bounds
    }

    func configure(with item: NewsItem) {
        titleLabel.text = item.title
        metaLabel.text = formatMeta(source: item.sourceName, date: item.publishedAt)

        if let urlString = item.imageURL, let url = URL(string: urlString) {
            placeholderIcon.isHidden = true
            let targetSize = CGSize(width: UIScreen.main.bounds.width, height: 280)
            let request = ImageRequest(
                url: url,
                processors: [.resize(size: targetSize, contentMode: .aspectFill)]
            )
            let options = ImageLoadingOptions(
                placeholder: nil,
                transition: .fadeIn(duration: 0.15)
            )
            NukeExtensions.loadImage(with: request, options: options, into: heroImageView) { result in
                switch result {
                case .success(let response):
                    print("[HeroCell] loaded: \(response.image.size)")
                case .failure(let error):
                    print("[HeroCell] failed: \(error)")
                }
            }
        } else {
            heroImageView.image = nil
            placeholderIcon.isHidden = false
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        NukeExtensions.cancelRequest(for: heroImageView)
        heroImageView.image = nil
        placeholderIcon.isHidden = true
        titleLabel.text = nil
        metaLabel.text = nil
    }
}
