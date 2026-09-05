enum Whitelist {
    static let views: Set<String> = [
        "VStack", "HStack", "ZStack", "ScrollView", "Spacer", "Text", "Image",
        "Button", "ProgressView", "Rectangle", "RoundedRectangle", "Capsule", "Circle", "Divider", "ForEach",
    ]

    static let modifiers: Set<String> = [
        "padding", "background", "frame", "foregroundStyle", "font", "clipShape", "opacity",
        "lineLimit", "minimumScaleFactor", "multilineTextAlignment", "fixedSize", "disabled",
        "ignoresSafeArea", "tint", "buttonStyle", "progressViewStyle", "fill", "defaultScrollAnchor",
    ]
}
