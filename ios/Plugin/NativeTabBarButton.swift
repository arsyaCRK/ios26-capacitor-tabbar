import UIKit

final class NativeTabBarButton: UIControl {

    private let blurView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    private let imageView: UIImageView

    override init(frame: CGRect) {
        let effect = UIBlurEffect(style: .prominent)
        blurView = UIVisualEffectView(effect: effect)
        vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: effect))
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.label

        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false

        blurView.translatesAutoresizingMaskIntoConstraints = false
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 20
        blurView.layer.masksToBounds = true

        addSubview(blurView)
        blurView.contentView.addSubview(vibrancyView)
        vibrancyView.contentView.addSubview(imageView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            vibrancyView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            vibrancyView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: vibrancyView.contentView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: vibrancyView.contentView.centerYAnchor)
        ])

        widthAnchor.constraint(equalToConstant: 56).isActive = true
        heightAnchor.constraint(equalToConstant: 56).isActive = true

        layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 12

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        imageView.image = UIImage(systemName: "ellipsis.circle", withConfiguration: config)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.layer.cornerRadius = bounds.height / 2
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: blurView.layer.cornerRadius).cgPath
    }

    func setImage(symbolName: String?) {
        guard let symbolName else { return }
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        imageView.image = UIImage(systemName: symbolName, withConfiguration: config)
    }
}
