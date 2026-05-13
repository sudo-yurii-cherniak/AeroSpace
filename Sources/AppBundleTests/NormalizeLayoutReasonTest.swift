@testable import AppBundle
import XCTest

@MainActor
final class NormalizeLayoutReasonTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMacosFullscreenExitRestoresPreviousTilingPosition() async throws {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let left = TestWindow.new(id: 1, parent: root)
        let right = TestWindow.new(id: 2, parent: root)

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))

        left.macosFullscreen = true
        try await normalizeLayoutReason()

        assertEquals(root.layoutDescription, .h_tiles([.window(2)]))
        assertEquals(workspace.macOsNativeFullscreenWindowsContainer.children.map { ($0 as! Window).windowId }, [1])

        right.hWeight = 3
        right.markAsMostRecentChild()
        left.macosFullscreen = false
        try await normalizeLayoutReason()

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
        assertEquals(left.hWeight, 1)
        assertEquals(right.hWeight, 1)
    }
}
