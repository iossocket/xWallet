//
//  NewsFeedStatusView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 17/4/26.
//

import UIKit
import SnapKit

final class NewsFeedStatusView: UIView {
    enum Mode: Equatable {
        case loading
        case empty(message: String)
        case error(message: String)
    }

    var onRetry: (() -> Void)?

    private let stack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let iconView = UIImageView()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .clear

        spinner.color = UIColor.xAccent
        spinner.hidesWhenStopped = false

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = UIColor.xTextTertiary

        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = UIColor.xTextSecondary
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        retryButton.setTitleColor(UIColor.xAccent, for: .normal)
        retryButton.layer.borderWidth = 1
        retryButton.layer.borderColor = UIColor.xAccent.cgColor
        retryButton.layer.cornerRadius = XRadius.sm
        retryButton.contentEdgeInsets = UIEdgeInsets(
            top: 0, left: XSpacing.md, bottom: 0, right: XSpacing.md
        )
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = XSpacing.md
        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(retryButton)

        addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(XSpacing.lg)
        }
        iconView.snp.makeConstraints {
            $0.size.equalTo(48)
        }
        retryButton.snp.makeConstraints {
            $0.height.equalTo(36)
            $0.width.greaterThanOrEqualTo(88)
        }
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    func setMode(_ mode: Mode) {
        switch mode {
        case .loading:
            spinner.isHidden = false
            spinner.startAnimating()
            iconView.isHidden = true
            messageLabel.isHidden = true
            retryButton.isHidden = true
        case .empty(let message):
            spinner.isHidden = true
            spinner.stopAnimating()
            iconView.image = UIImage(systemName: "newspaper")
            iconView.isHidden = false
            messageLabel.text = message
            messageLabel.isHidden = false
            retryButton.isHidden = true
        case .error(let message):
            spinner.isHidden = true
            spinner.stopAnimating()
            iconView.image = UIImage(systemName: "exclamationmark.triangle")
            iconView.isHidden = false
            messageLabel.text = message
            messageLabel.isHidden = false
            retryButton.isHidden = false
        }
    }
}
