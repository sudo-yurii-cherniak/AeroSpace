import AppKit

@MainActor
func normalizeLayoutReason() async throws {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        try await _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    try await _normalizeLayoutReason(workspace: focus.workspace, windows: macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    try await validateStillPopups()
}

@MainActor
private func validateStillPopups() async throws {
    for node in macosPopupWindowsContainer.children {
        let popup = (node as! MacWindow)
        let windowLevel = getWindowLevel(for: popup.windowId)
        if try await popup.isWindowHeuristic(windowLevel) {
            try await popup.relayoutWindow(on: focus.workspace)
            try await tryOnWindowDetected(popup)
        }
    }
}

@MainActor
private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) async throws {
    for window in windows {
        let isMacosFullscreen = try await window.isMacosFullscreen
        let isMacosMinimized = try await (!isMacosFullscreen).andAsync { @MainActor @Sendable in try await window.isMacosMinimized }
        let isMacosWindowOfHiddenApp = !isMacosFullscreen && !isMacosMinimized &&
            !config.automaticallyUnhideMacosHiddenApps && window.macAppUnsafe.nsApp.isHidden
        switch window.layoutReason {
            case .standard:
                switch true {
                    case isMacosFullscreen:
                        enterMacOsNativeUnconventionalState(
                            window: window,
                            targetParent: workspace.macOsNativeFullscreenWindowsContainer,
                            adaptiveWeight: WEIGHT_DOESNT_MATTER,
                        )
                    case isMacosMinimized:
                        enterMacOsNativeUnconventionalState(
                            window: window,
                            targetParent: macosMinimizedWindowsContainer,
                            adaptiveWeight: 1,
                        )
                    case isMacosWindowOfHiddenApp:
                        enterMacOsNativeUnconventionalState(
                            window: window,
                            targetParent: workspace.macOsNativeHiddenAppsWindowsContainer,
                            adaptiveWeight: WEIGHT_DOESNT_MATTER,
                        )
                    default: break
                }
            case .macos(let prevBinding):
                if !isMacosFullscreen && !isMacosMinimized && !isMacosWindowOfHiddenApp {
                    try await exitMacOsNativeUnconventionalState(window: window, prevBinding: prevBinding, workspace: workspace)
                }
        }
    }
}

@MainActor
func enterMacOsNativeUnconventionalState(window: Window, targetParent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) {
    let childWeights = TreeNodeWeightSnapshot.snapshot(from: window.parent)
    let previousBinding = window.bind(to: targetParent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    if case .standard = window.layoutReason, let previousBinding {
        window.layoutReason = .macos(prevBinding: BindingDataSnapshot(previousBinding, childWeights: childWeights))
    }
}

@MainActor
func exitMacOsNativeUnconventionalState(window: Window, prevBinding: BindingDataSnapshot, workspace: Workspace) async throws {
    window.layoutReason = .standard
    switch prevBinding.parentKind {
        case .workspace:
            if !restorePreviousBinding(window: window, prevBinding: prevBinding, workspace: workspace) {
                window.bindAsFloatingWindow(to: workspace)
            }
        case .tilingContainer:
            if !restorePreviousBinding(window: window, prevBinding: prevBinding, workspace: workspace) {
                try await window.relayoutWindow(on: workspace, forceTile: true)
            }
        case .macosPopupWindowsContainer: // Since the window was minimized/fullscreened it was mistakenly detected as popup. Relayout the window
            try await window.relayoutWindow(on: workspace)
        case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
            try await window.relayoutWindow(on: workspace)
    }
}

@MainActor
private func restorePreviousBinding(window: Window, prevBinding: BindingDataSnapshot, workspace: Workspace) -> Bool {
    guard let parent = prevBinding.parent else { return false }
    guard parent.nodeWorkspace == workspace else { return false }
    let index = prevBinding.index == INDEX_BIND_LAST
        ? INDEX_BIND_LAST
        : min(prevBinding.index, parent.children.count)
    window.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: index)
    prevBinding.restoreChildWeights()
    return true
}
