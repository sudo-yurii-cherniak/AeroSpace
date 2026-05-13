import AppKit
import Common

/// Problem ID-B6E178F2: It's not first-class citizen command in AeroSpace model, since it interacts with macOS API directly.
/// Consecutive macos-native-fullscreen commands may not works as expected (because macOS may report correct state with a
/// delay), or may flicker
///
/// The same applies to macos-native-minimize command
struct MacosNativeFullscreenCommand: Command {
    let args: MacosNativeFullscreenCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        let prevState = try await window.isMacosFullscreen
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !prevState
        }
        if newState == prevState {
            return switch args.failIfNoop {
                case true: .fail
                case false:
                    .succ(io.err((newState ? "Already fullscreen. " : "Already not fullscreen. ") +
                            "Tip: use --fail-if-noop to exit with non-zero exit code"))
            }
        }
        window.asMacWindow().setNativeFullscreen(newState)
        guard let workspace = window.visualWorkspace else {
            return .fail(io.err(windowIsntPartOfTree(window)))
        }
        if newState { // Enter fullscreen
            enterMacOsNativeUnconventionalState(
                window: window,
                targetParent: workspace.macOsNativeFullscreenWindowsContainer,
                adaptiveWeight: WEIGHT_DOESNT_MATTER,
            )
        } else { // Exit fullscreen
            switch window.layoutReason {
                case .macos(let prevBinding):
                    try await exitMacOsNativeUnconventionalState(window: window, prevBinding: prevBinding, workspace: workspace)
                default:
                    try await window.relayoutWindow(on: workspace)
            }
        }
        return .succ
    }
}
