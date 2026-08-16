import CoreGraphics
import Foundation
import ImageIO

enum SpriteAtlasError: LocalizedError {
    case unreadableImage
    case unexpectedDimensions(width: Int, height: Int)
    case frameOutsideAtlas(SpriteFrame)
    case invalidAnimationRoute(String)

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "The Clippy sprite atlas could not be decoded."
        case let .unexpectedDimensions(width, height):
            return "Expected a 3348×3162 sprite atlas, but found \(width)×\(height)."
        case let .frameOutsideAtlas(frame):
            return "Animation frame at \(frame.x),\(frame.y) is outside the sprite atlas."
        case let .invalidAnimationRoute(message):
            return "The animation routing data is invalid: \(message)"
        }
    }
}

final class SpriteAtlas {
    let image: CGImage
    let pixelWidth: Int
    let pixelHeight: Int

    init(url: URL) throws {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let decodedImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw SpriteAtlasError.unreadableImage
        }

        pixelWidth = decodedImage.width
        pixelHeight = decodedImage.height
        image = decodedImage

        guard
            pixelWidth == AnimationCatalog.atlasWidth,
            pixelHeight == AnimationCatalog.atlasHeight
        else {
            throw SpriteAtlasError.unexpectedDimensions(
                width: pixelWidth,
                height: pixelHeight
            )
        }

        for frame in AnimationCatalog.animations.flatMap(\.frames) {
            guard contains(frame) else {
                throw SpriteAtlasError.frameOutsideAtlas(frame)
            }
        }

        if let routeError = AnimationCatalog.routeValidationErrors().first {
            throw SpriteAtlasError.invalidAnimationRoute(routeError)
        }
    }

    func contentsRect(for frame: SpriteFrame) -> CGRect {
        let width = CGFloat(AnimationCatalog.frameWidth) / CGFloat(pixelWidth)
        let height = CGFloat(AnimationCatalog.frameHeight) / CGFloat(pixelHeight)
        let x = CGFloat(frame.x) / CGFloat(pixelWidth)

        // Animation metadata uses a top-left origin; CALayer contentsRect uses bottom-left.
        let y = 1 - CGFloat(frame.y + AnimationCatalog.frameHeight) / CGFloat(pixelHeight)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func contains(_ frame: SpriteFrame) -> Bool {
        frame.x >= 0 &&
        frame.y >= 0 &&
        frame.x + AnimationCatalog.frameWidth <= pixelWidth &&
        frame.y + AnimationCatalog.frameHeight <= pixelHeight &&
        frame.duration > 0
    }
}
