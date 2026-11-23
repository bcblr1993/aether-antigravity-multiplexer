import Carbon
import Foundation

/// Global Carbon hotkey manager for ⌥0 (collapse all) and ⌥1~⌥9 (toggle instances).
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()
    private init() {}

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private(set) var isRegistered = false
    var onCollapseAll: (() -> Void)?
    var onToggleInstance: ((Int) -> Void)?
    private static let signature: OSType = 0x4147594D

    func setup(onCollapseAll: (() -> Void)?, onToggleInstance: ((Int) -> Void)?, shouldRegister: Bool = true) {
        self.onCollapseAll = onCollapseAll
        self.onToggleInstance = onToggleInstance
        if shouldRegister { register() } else { unregister() }
    }

    func register() {
        guard !isRegistered else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard err == noErr, hotKeyID.signature == GlobalHotKeyManager.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let id = Int(hotKeyID.id)
            DispatchQueue.main.async {
                if id == 0 { GlobalHotKeyManager.shared.onCollapseAll?() }
                else if (1...9).contains(id) { GlobalHotKeyManager.shared.onToggleInstance?(id) }
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
        guard status == noErr else { return }

        let keys: [(Int, UInt32)] = [
            (0, UInt32(kVK_ANSI_0)), (1, UInt32(kVK_ANSI_1)), (2, UInt32(kVK_ANSI_2)),
            (3, UInt32(kVK_ANSI_3)), (4, UInt32(kVK_ANSI_4)), (5, UInt32(kVK_ANSI_5)),
            (6, UInt32(kVK_ANSI_6)), (7, UInt32(kVK_ANSI_7)), (8, UInt32(kVK_ANSI_8)),
            (9, UInt32(kVK_ANSI_9))
        ]
        for (id, code) in keys {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: Self.signature, id: UInt32(id))
            if RegisterEventHotKey(code, UInt32(optionKey), hkID, GetEventDispatcherTarget(), 0, &ref) == noErr, let ref {
                hotKeyRefs.append(ref)
            }
        }
        isRegistered = true
    }

    func unregister() {
        guard isRegistered else { return }
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        isRegistered = false
    }

    deinit { unregister() }
}
