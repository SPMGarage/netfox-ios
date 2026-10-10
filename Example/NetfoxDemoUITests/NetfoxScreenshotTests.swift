//
//  NetfoxScreenshotTests.swift
//  NetfoxDemoUITests
//
//  Walks through the main netfox screens and keeps a screenshot of each one
//  as a test attachment (export them with `xcrun xcresulttool export attachments`).
//  The accessibility identifiers used here are part of the netfox UI contract.
//

import XCTest

final class NetfoxScreenshotTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testWalkThroughMainScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["--send-all", "--open-netfox"]
        app.launch()

        // request list
        XCTAssertTrue(element("nfx.requestList", in: app).waitForExistence(timeout: 40), "netfox list did not open")
        waitForRows(atLeast: 8, in: app)
        snapshot("01-request-list")

        // detail of a JSON request
        let jsonRow = rows(in: app).containing(NSPredicate(format: "label CONTAINS 'todos/1'")).firstMatch
        tap(jsonRow.exists ? jsonRow : rows(in: app).firstMatch)
        snapshot("02-detail-info")

        let tabs = app.segmentedControls["nfx.detail.tabs"]
        if tabs.waitForExistence(timeout: 5) {
            tap(tabs.buttons["Request"])
            snapshot("03-detail-request")
            tap(tabs.buttons["Response"])
            snapshot("04-detail-response")
        } else {
            XCTFail("missing detail tabs")
        }

        let showBody = element("nfx.detail.showBody", in: app)
        if showBody.waitForExistence(timeout: 3) {
            tap(showBody)
            XCTAssertTrue(element("nfx.body.text", in: app).waitForExistence(timeout: 10), "body text did not appear")
            snapshot("05-body")
            goBack(in: app)
        }
        goBack(in: app)

        // settings and the screens behind it
        tap(element("nfx.settings", in: app))
        snapshot("06-settings")
        openAndSnapshot("nfx.settings.statistics", name: "07-statistics", in: app)
        openAndSnapshot("nfx.settings.deviceInfo", name: "08-device-info", in: app)
        openAndSnapshot("nfx.settings.webSocket", name: "09-websocket", in: app)
        goBack(in: app)

        // search
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("httpbin")
            snapshot("10-search")
        } else {
            XCTFail("missing search field")
        }

        // closing returns to the demo app
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        }
        tap(element("nfx.close", in: app))
        XCTAssertTrue(app.staticTexts["netfox demo"].waitForExistence(timeout: 10), "netfox did not close")
    }

    // MARK: - Helpers

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func rows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "nfx.requestRow")
    }

    @MainActor
    private func waitForRows(atLeast count: Int, in app: XCUIApplication, timeout: TimeInterval = 40) {
        let predicate = NSPredicate { object, _ in
            (object as? XCUIElementQuery).map { $0.count >= count } ?? false
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: rows(in: app))
        XCTWaiter().wait(for: [expectation], timeout: timeout)
    }

    @MainActor
    private func openAndSnapshot(_ identifier: String, name: String, in app: XCUIApplication) {
        let link = element(identifier, in: app)
        guard link.waitForExistence(timeout: 5) else {
            XCTFail("missing element: \(identifier)")
            return
        }
        link.tap()
        snapshot(name)
        goBack(in: app)
    }

    @MainActor
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 5) {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("missing element: \(element)")
            return
        }
        element.tap()
    }

    @MainActor
    private func goBack(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 3) {
            back.tap()
        }
    }

    @MainActor
    private func snapshot(_ name: String) {
        // give navigation animations time to settle before the screenshot
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
