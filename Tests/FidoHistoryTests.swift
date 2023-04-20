//
//  FidoHistoryTests.swift
//
// Copyright 2021, 2022 OpenAlloc LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import FINporterFido
import XCTest

import AllocData
import FINporter

final class FidoHistoryTests: XCTestCase {
    var imp: FidoHistory!
    let tzNewYork = TimeZone(identifier: "America/New_York")!

    override func setUpWithError() throws {
        imp = FidoHistory()
    }

    func testSourceFormats() {
        let expected = Set([AllocFormat.CSV])
        let actual = Set(imp.sourceFormats)
        XCTAssertEqual(expected, actual)
    }

    func testTargetSchema() {
        let expected: [AllocSchema] = [.allocTransaction]
        let actual = imp.outputSchemas
        XCTAssertEqual(expected, actual)
    }

    func testDetectFailsDueToHeaderMismatch() throws {
        let badHeader = """



        Breakerage

        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        """
        let expected: FINporter.DetectResult = [:]
        let actual = try imp.detect(dataPrefix: badHeader.data(using: .utf8)!)
        XCTAssertEqual(expected, actual)
    }

    func testDetectSucceeds() throws {
        let header = """



        Brokerage

        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        """
        let expected: FINporter.DetectResult = [.allocTransaction: [.CSV]]
        let actual = try imp.detect(dataPrefix: header.data(using: .utf8)!)
        XCTAssertEqual(expected, actual)
    }

    func testDetectViaMain() throws {
        let header = """



        Brokerage

        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        """
        let expected: FINporter.DetectResult = [.allocTransaction: [.CSV]]
        let main = FINprospector([FidoHistory()])
        let data = header.data(using: .utf8)!
        let actual = try main.prospect(sourceFormats: [.CSV], dataPrefix: data)
        XCTAssertEqual(1, actual.count)
        _ = actual.map { key, value in
            XCTAssertNotNil(key as? FidoHistory)
            XCTAssertEqual(expected, value)
        }
    }

    func testParse() throws {
        let str = """



        Brokerage

        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
         03/01/2021,MY TACTICAL (taxable) X00000000, YOU BOUGHT VANGUARD LARGE-CAP INDEX FUND (VV) (Cash), VV, VANGUARD LARGE-CAP INDEX FUND,Cash,0.999,180.95,,,,-150.00,03/03/2021

        XXX
        """

        var rr = [AllocRowed.RawRow]()
        let dataStr = str.data(using: .utf8)!
        let actual: [AllocRowed.DecodedRow] = try imp.decode(MTransaction.self, dataStr, rejectedRows: &rr, timeZone: tzNewYork)

        let YYYYMMDDts = parseFidoMMDDYYYY("03/01/2021", timeZone: tzNewYork)!
        let expected: AllocRowed.DecodedRow = [
            "txnAction": MTransaction.Action.buysell,
            "txnTransactedAt": YYYYMMDDts,
            "txnAccountID": "X00000000",
            "txnSecurityID": "VV",
            "txnShareCount": 0.999,
            "txnSharePrice": 180.95,
        ]

        XCTAssertTrue(areEqual(expected, actual.first!))
        XCTAssertEqual(0, rr.count)
    }

    func testMiscFlow() throws {
        let str = """
        Brokerage

        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
         03/01/2021,CASH MGMT X0000000A, DEBIT CARD PURCHASE, , No Description,Cash,,,,,,-17.00,
         03/01/2021,CASH MGMT X0000000B, DIRECT DEBIT BLAH, , No Description,Cash,,,,,,-23.00,
         03/01/2021,CASH MGMT X0000000C, DIRECT DEPOSIT BLAH, , No Description,Cash,,,,,,7.00,

        XXX
        """

        var rr = [AllocRowed.RawRow]()
        let dataStr = str.data(using: .utf8)!
        let actual: [AllocRowed.DecodedRow] = try imp.decode(MTransaction.self, dataStr, rejectedRows: &rr, timeZone: tzNewYork)

        let YYYYMMDDts = parseFidoMMDDYYYY("03/01/2021", timeZone: tzNewYork)!
        let expected: [AllocRowed.DecodedRow] = [
            [
                "txnAction": MTransaction.Action.miscflow,
                "txnTransactedAt": YYYYMMDDts,
                "txnAccountID": "X0000000A",
                "txnShareCount": -17.0,
                "txnSharePrice": 1.0,
            ],
            [
                "txnAction": MTransaction.Action.miscflow,
                "txnTransactedAt": YYYYMMDDts,
                "txnAccountID": "X0000000B",
                "txnShareCount": -23.0,
                "txnSharePrice": 1.0,
            ],
            [
                "txnAction": MTransaction.Action.miscflow,
                "txnTransactedAt": YYYYMMDDts,
                "txnAccountID": "X0000000C",
                "txnShareCount": 7.0,
                "txnSharePrice": 1.0,
            ],
        ]

        XCTAssertEqual(expected, actual)
        XCTAssertEqual(0, rr.count)
    }
}
