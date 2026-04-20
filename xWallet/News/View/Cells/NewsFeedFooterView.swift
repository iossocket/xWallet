//
//  NewsFeedFooterView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 18/4/26.
//

import UIKit

class NewsFeedFooterView: UICollectionReusableView {
    enum Mode: Equatable { case blank, loading, error(String), end(String), allLoaded }

    var onRetry: (() -> Void)?

    static let reuseIdentifier = "NewsFeedFooterView"
    static let elementKind = UICollectionView.elementKindSectionFooter

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.xTextSecondary
        label.text = "Loading..."
        return label
    }()

    private let activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView(style: .medium)
        activityIndicatorView.color = UIColor.xAccent
        return activityIndicatorView
    }()

    private let retryButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Retry"
        config.baseForegroundColor = UIColor.xAccent
        let button = UIButton(configuration: config)
        return button
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [activityIndicatorView, titleLabel, retryButton])
        stackView.axis = .horizontal
        stackView.spacing = XSpacing.sm
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.startAnimating()
        
        retryButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func tapped() {
        self.onRetry?()
    }
    
    func config(mode: Mode) {
        switch mode {
        case .blank:
            activityIndicatorView.stopAnimating()
            titleLabel.isHidden = true
            retryButton.isHidden = true
        case .allLoaded:
            activityIndicatorView.stopAnimating()
            titleLabel.isHidden = false
            titleLabel.text = "No more news"
            retryButton.isHidden = true
        case .loading:
            activityIndicatorView.startAnimating()
            titleLabel.text = "Loading..."
            titleLabel.isHidden = false
            retryButton.isHidden = true
        case .error(let string):
            activityIndicatorView.stopAnimating()
            titleLabel.text = string
            titleLabel.isHidden = false
            retryButton.isHidden = false
        case .end(let string):
            activityIndicatorView.stopAnimating()
            titleLabel.text = string
            titleLabel.isHidden = false
            retryButton.isHidden = true
        }
    }
}
