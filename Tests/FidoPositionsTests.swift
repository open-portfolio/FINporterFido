//
//  FidoPositionsTests.swift
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

final class FidoPositionsTests: XCTestCase {
    var imp: FidoPositions!
    let df = ISO8601DateFormatter()

    let goodHeader = """
    Account Number,Account Name,Symbol,Description,Quantity,Last Price,Last Price Change,Current Value,Today's Gain/Loss Dollar,Today's Gain/Loss Percent,Total Gain/Loss Dollar,Total Gain/Loss Percent,Percent Of Account,Cost Basis Total,Average Cost Basis,Type
    """

    override func setUpWithError() throws {
        imp = FidoPositions()
    }

    func testSourceFormats() {
        let expected = Set([AllocFormat.CSV])
        let actual = Set(imp.sourceFormats)
        XCTAssertEqual(expected, actual)
    }

    func testTargetSchema() {
        let expected: [AllocSchema] = [.allocMetaSource, .allocAccount, .allocHolding, .allocSecurity]
        let actual = imp.outputSchemas
        XCTAssertEqual(expected, actual)
    }

    func testDetectFailsDueToHeaderMismatch() throws {
        let badHeader = goodHeader.replacingOccurrences(of: "Symbol", with: "Symbal")
        let expected: FINporter.DetectResult = [:]
        let actual = try imp.detect(dataPrefix: badHeader.data(using: .utf8)!)
        XCTAssertEqual(expected, actual)
    }

    func testDetectSucceeds() throws {
        let expected: FINporter.DetectResult = [.allocMetaSource: [.CSV], .allocAccount: [.CSV], .allocHolding: [.CSV], .allocSecurity: [.CSV]]
        let actual = try imp.detect(dataPrefix: goodHeader.data(using: .utf8)!)
        XCTAssertEqual(expected, actual)
    }

    func testDetectViaMain() throws {
        let expected: FINporter.DetectResult = [.allocMetaSource: [.CSV], .allocAccount: [.CSV], .allocHolding: [.CSV], .allocSecurity: [.CSV]]
        let main = FINprospector([FidoPositions()])
        let data = goodHeader.data(using: .utf8)!
        let actual = try main.prospect(sourceFormats: [.CSV], dataPrefix: data)
        XCTAssertEqual(1, actual.count)
        _ = actual.map { key, value in
            XCTAssertNotNil(key as? FidoPositions)
            XCTAssertEqual(expected, value)
        }
    }

    func testParse() throws {
        for str in [
            "﻿Account Number,Account Name,Symbol,Description,Quantity,Last Price,Last Price Change,Current Value,Today\'s Gain/Loss Dollar,Today\'s Gain/Loss Percent,Total Gain/Loss Dollar,Total Gain/Loss Percent,Percent Of Account,Cost Basis Total,Average Cost Basis,Type\r\nZ00000000,AAAA,VWO,VANGUARD INTL EQUITY INDEX FDS FTSE EMR MKT ETF,900,$50.922,+$0.160,\"$45,900.35\",+$150.25,+0.32%,\"+$11,945.20\",+31.10%,15.05%,\"$38,362.05\",$28.96,Cash,\r\nZ00000001,BBBB,VOO,VANGUARD S&P 500 ETF,800,$40.922,+$0.160,\"$45,900.35\",+$150.25,+0.32%,\"+$11,945.20\",+31.10%,15.05%,\"$38,362.05\",$18.96,Cash,\r\n\r\nXXX",

            // testParseWithLFToFirstBlankLine
            """
            Account Number,Account Name,Symbol,Description,Quantity,Last Price,Last Price Change,Current Value,Today's Gain/Loss Dollar,Today's Gain/Loss Percent,Total Gain/Loss Dollar,Total Gain/Loss Percent,Percent Of Account,Cost Basis Total,Average Cost Basis,Type
            Z00000000,AAAA,VWO,VANGUARD INTL EQUITY INDEX FDS FTSE EMR MKT ETF,900,$50.922,+$0.160,"$45,900.35",+$150.25,+0.32%,"+$11,945.20",+31.10%,15.05%,"$38,362.05",$28.96,Cash,
            Z00000001,BBBB,VOO,VANGUARD S&P 500 ETF,800,$40.922,+$0.160,"$45,900.35",+$150.25,+0.32%,"+$11,945.20",+31.10%,15.05%,"$38,362.05",$18.96,Cash,

            XXX
            """,

            // testParseWithLFToFirstBlankLine
            """
            Account Number,Account Name,Symbol,Description,Quantity,Last Price,Last Price Change,Current Value,Today's Gain/Loss Dollar,Today's Gain/Loss Percent,Total Gain/Loss Dollar,Total Gain/Loss Percent,Percent Of Account,Cost Basis Total,Average Cost Basis,Type
            Z00000000,AAAA,VWO,VANGUARD INTL EQUITY INDEX FDS FTSE EMR MKT ETF,900,$50.922,+$0.160,"$45,900.35",+$150.25,+0.32%,"+$11,945.20",+31.10%,15.05%,"$38,362.05",$28.96,Cash,
            Z00000001,BBBB,VOO,VANGUARD S&P 500 ETF,800,$40.922,+$0.160,"$45,900.35",+$150.25,+0.32%,"+$11,945.20",+31.10%,15.05%,"$38,362.05",$18.96,Cash,
            """,
        ] {
            var rejectedRows = [AllocRowed.RawRow]()
            let dataStr = str.data(using: .utf8)!
            let actual: [AllocRowed.DecodedRow] = try imp.decode(MHolding.self, dataStr, rejectedRows: &rejectedRows, outputSchema: .allocHolding)

            let expected: [AllocRowed.DecodedRow] = [
                ["holdingAccountID": "Z00000000", "holdingSecurityID": "VWO", "shareCount": 900.0, "shareBasis": 28.96],
                ["holdingAccountID": "Z00000001", "holdingSecurityID": "VOO", "shareCount": 800.0, "shareBasis": 18.96],
            ]

            XCTAssertTrue(areEqual(expected, actual))
            XCTAssertEqual(expected, actual)
            XCTAssertEqual(0, rejectedRows.count)

            let timestamp = Date()
            let actual2: [AllocRowed.DecodedRow] = try imp.decode(MHolding.self, dataStr, rejectedRows: &rejectedRows, outputSchema: .allocSecurity, timestamp: timestamp)

            let expected2: [AllocRowed.DecodedRow] = [
                ["securityID": "VWO", "sharePrice": 50.922, "updatedAt": timestamp],
                ["securityID": "VOO", "sharePrice": 40.922, "updatedAt": timestamp],
            ]

            XCTAssertTrue(areEqual(expected2, actual2))
            XCTAssertEqual(0, rejectedRows.count)

            let actual3: [AllocRowed.DecodedRow] = try imp.decode(MHolding.self, dataStr, rejectedRows: &rejectedRows, outputSchema: .allocAccount)

            let expected3: [AllocRowed.DecodedRow] = [
                ["accountID": "Z00000000", "title": "AAAA"],
                ["accountID": "Z00000001", "title": "BBBB"],
            ]

            XCTAssertTrue(areEqual(expected3, actual3))
            XCTAssertEqual(0, rejectedRows.count)
        }
    }

    /// cash holding may have "n/a" for share basis
    func testHoldingCashShareBasisSetToLastPrice() throws {
        var rejectedRows = [AllocRowed.RawRow]()
        let rawRow: AllocRowed.RawRow = [
            "Account Number": "1",
            "Symbol": "SPAXX",
            "Last Price": "1.00",
            "Quantity": "1",
            "Average Cost Basis": "n/a",
        ]

        let actual = imp.holding(rawRow, rejectedRows: &rejectedRows)
        XCTAssertNotNil(actual)
        XCTAssertEqual(actual!["shareBasis"]!, 1.00)
    }

    func testHoldingShareBasisMissing() throws {
        var rejectedRows = [AllocRowed.RawRow]()
        let rawRow: AllocRowed.RawRow = [
            "Account Number": "1",
            "Symbol": "ABCXY",
            "Last Price": "$16.5587",
            "Quantity": "3333.821",
            "Average Cost Basis": "n/a",
            "Cost Basis Total": "$48323.69",
        ]

        let actual = imp.holding(rawRow, rejectedRows: &rejectedRows)
        XCTAssertNotNil(actual)
        XCTAssertEqual(actual?["shareBasis"] as! Double, 14.49, accuracy: 0.01)
    }

    func testParseSourceMeta() throws {
        let str = """
        Account Number,Account Name,...
        "XYZ","ABC",...

        "Date downloaded 07/30/2021 2:26 PM ET"

        "legalese down here"
        """

        let timestamp = Date()
        var rejectedRows = [AllocRowed.RawRow]()
        let dataStr = str.data(using: .utf8)!

        let actual: [MSourceMeta.DecodedRow] = try imp.decode(MSourceMeta.self,
                                                              dataStr,
                                                              rejectedRows: &rejectedRows,
                                                              outputSchema: .allocMetaSource,
                                                              url: URL(string: "http://blah.com"),
                                                              timestamp: timestamp)

        XCTAssertEqual(1, actual.count)
        XCTAssertNotNil(actual[0]["sourceMetaID"]!)
        XCTAssertEqual(URL(string: "http://blah.com"), actual[0]["url"]!)
        XCTAssertEqual("fido_positions", actual[0]["importerID"])
        let exportedAt: Date? = actual[0]["exportedAt"] as? Date
        let expectedExportedAt = df.date(from: "2021-07-30T18:26:00+0000")!
        XCTAssertEqual(expectedExportedAt, exportedAt)
    }
}
