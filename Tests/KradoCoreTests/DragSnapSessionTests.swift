import Testing
@testable import KradoCore

@Suite("Esc cancels drag snapping")
struct DragSnapSessionTests {
    @Test("A new drag allows snapping")
    func beginAllowsSnap() {
        var session = DragSnapSession()
        #expect(!session.allowsSnap)
        session.begin()
        #expect(session.allowsSnap)
    }

    @Test("Esc during a drag cancels snapping once")
    func escapeCancels() {
        var session = DragSnapSession()
        session.begin()
        let pressed1 = session.keyDown(DragSnapSession.escapeKeyCode)
        #expect(pressed1)
        #expect(!session.allowsSnap)
        #expect(session.isCancelled)
        let pressed2 = session.keyDown(DragSnapSession.escapeKeyCode)
        #expect(!pressed2)
    }

    @Test("Other keys do not cancel", arguments: [UInt16(0), 36, 48, 49, 123, 126])
    func otherKeys(code: UInt16) {
        var session = DragSnapSession()
        session.begin()
        let pressed3 = session.keyDown(code)
        #expect(!pressed3)
        #expect(session.allowsSnap)
    }

    @Test("Esc outside a drag does nothing")
    func escapeWithoutDrag() {
        var session = DragSnapSession()
        let pressed4 = session.keyDown(DragSnapSession.escapeKeyCode)
        #expect(!pressed4)
        session.begin()
        session.end()
        let pressed5 = session.keyDown(DragSnapSession.escapeKeyCode)
        #expect(!pressed5)
        #expect(!session.allowsSnap)
    }

    @Test("The next drag snaps again after a cancelled one")
    func nextDragResets() {
        var session = DragSnapSession()
        session.begin()
        _ = session.keyDown(DragSnapSession.escapeKeyCode)
        session.end()
        session.begin()
        #expect(session.allowsSnap)
    }
}
