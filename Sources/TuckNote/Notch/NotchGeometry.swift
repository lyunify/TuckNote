import AppKit

struct NotchGeometry {
    static let minimumExpandedSize = CGSize(width: 360, height: 260)

    let compactFrame: CGRect
    let expandedFrame: CGRect
    let hasPhysicalNotch: Bool
    private let screenFrame: CGRect
    private let expandedMaxY: CGFloat

    init(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        safeAreaInsets: NSEdgeInsets,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?
    ) {
        self.screenFrame = screenFrame
        let auxiliaryGap = Self.auxiliaryGap(
            screenFrame: screenFrame,
            leftArea: auxiliaryTopLeftArea,
            rightArea: auxiliaryTopRightArea
        )
        hasPhysicalNotch = safeAreaInsets.top > 1 || auxiliaryGap != nil

        let nominalCompactWidth = min(max(auxiliaryGap ?? 120, 120), 220)
        let compactWidth = min(screenFrame.width, nominalCompactWidth)
        let compactHeight = min(
            max(safeAreaInsets.top, screenFrame.maxY - visibleFrame.maxY, 32),
            screenFrame.height
        )
        compactFrame = Self.topCenteredFrame(
            width: compactWidth,
            height: compactHeight,
            maxY: screenFrame.maxY,
            in: screenFrame
        )
        expandedMaxY = hasPhysicalNotch ? compactFrame.minY : screenFrame.maxY

        expandedFrame = Self.topCenteredFrame(
            width: max(0, min(520, screenFrame.width - 32)),
            height: max(0, min(430, expandedMaxY - screenFrame.minY - 48)),
            maxY: expandedMaxY,
            in: screenFrame
        )
    }

    func expandedFrame(fittingPreferredSize preferredSize: CGSize?) -> CGRect {
        guard let preferredSize else { return expandedFrame }
        let availableWidth = max(0, screenFrame.width - 32)
        let availableHeight = max(0, expandedMaxY - screenFrame.minY - 48)
        let width = max(
            0,
            min(max(preferredSize.width, Self.minimumExpandedSize.width), availableWidth)
        )
        let height = max(
            0,
            min(max(preferredSize.height, Self.minimumExpandedSize.height), availableHeight)
        )
        return Self.topCenteredFrame(width: width, height: height, maxY: expandedMaxY, in: screenFrame)
    }

    private static func auxiliaryGap(
        screenFrame: CGRect,
        leftArea: CGRect?,
        rightArea: CGRect?
    ) -> CGFloat? {
        guard let leftArea, let rightArea,
              leftArea.maxX <= screenFrame.midX,
              rightArea.minX >= screenFrame.midX else {
            return nil
        }

        let width = rightArea.minX - leftArea.maxX
        return width > 1 ? width : nil
    }

    private static func topCenteredFrame(
        width: CGFloat,
        height: CGFloat,
        maxY: CGFloat,
        in screenFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: screenFrame.midX - width / 2,
            y: maxY - height,
            width: width,
            height: height
        )
    }
}
