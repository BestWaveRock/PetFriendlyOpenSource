import XCTest
@testable import PetFriendly

final class RemediationStateTests: XCTestCase {
    func testPaymentPasswordAcceptsOnlySixDigitsAndDisablesConfirmWhileLoading() {
        var state = PaymentPasswordState()
        for character in "12a34567" { state.append(character) }
        XCTAssertEqual(state.password, "123456")
        XCTAssertTrue(state.canConfirm)
        state.beginSubmission()
        XCTAssertFalse(state.canConfirm)
    }

    func testPaymentPasswordFailureClearsInputAndKeepsGateOpen() {
        var state = PaymentPasswordState(password: "123456")
        state.beginSubmission()
        state.fail(message: "wrong")
        XCTAssertEqual(state.password, "")
        XCTAssertEqual(state.errorMessage, "wrong")
        XCTAssertFalse(state.isSubmitting)
    }

    func testWalletAmountValidationRejectsInvalidAndOverBalanceAmounts() {
        XCTAssertEqual(WalletAmountValidator.validate("0", balance: 100, operation: .recharge), .invalid)
        XCTAssertEqual(WalletAmountValidator.validate("101", balance: 100, operation: .withdraw), .exceedsBalance)
        XCTAssertEqual(WalletAmountValidator.validate("10.5", balance: 100, operation: .withdraw), .valid(10.5))
    }

    func testPayPasswordFormSelectsSetAndChangeContracts() {
        XCTAssertEqual(PayPasswordFormState(hasPassword: false).request(old: "", new: "123456"),
                       PayPasswordRequest(path: "/petFriendly/client/pay-password/set", parameters: ["newPassword": "123456"]))
        XCTAssertEqual(PayPasswordFormState(hasPassword: true).request(old: "654321", new: "123456"),
                       PayPasswordRequest(path: "/petFriendly/client/pay-password/reset", parameters: ["oldPassword": "654321", "newPassword": "123456"]))
    }

    func testSessionReducerAlwaysConvergesAfterTerminalEvents() {
        var state = AccountSessionState.authenticating
        state.reduce(.loginFailed)
        XCTAssertEqual(state, .signedOut)
        state = .signingOut
        state.reduce(.logoutFailed)
        XCTAssertEqual(state, .signedOut)
        state = .authenticated
        state.reduce(.tokenExpired)
        XCTAssertEqual(state, .signedOut)
    }
}
