import AppKit

struct NotchGeometry {
    let compactFrame: CGRect
    let expandedFrame: CGRect
    let hasPhysicalNotch: Bool

    init(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        safeAreaInsets: NSEdgeInsets,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?
    ) {
        let auxiliaryGap = Self.auxiliaryGap(
            screenFrame: screenFrame,
            leftArea: auxiliaryTopLeftArea,
            rightArea: auxiliaryTopRightArea
        )
        hasPhysicalNotch = safeAreaInsets.top > 1 || auxiliaryGap != nil

        let compactWidth = min(max(auxiliaryGap ?? 120, 120), 220)
        let compactHeight = min(
            max(safeAreaInsets.top, screenFrame.maxY - visibleFrame.maxY, 32),
            screenFrame.height
        )
        compactFrame = Self.topCenteredFrame(
            width: compactWidth,
            height: compactHeight,
            in: screenFrame
        )

        expandedFrame = Self.topCenteredFrame(
            width: max(0, min(520, screenFrame.width - 32)),
            height: max(0, min(430, screenFrame.height - 48)),
            in: screenFrame
        )
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
        in screenFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }
}
