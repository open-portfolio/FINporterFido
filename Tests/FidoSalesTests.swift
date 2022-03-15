//
//  FidoSalesTests.swift
//
// Copyright 2021 FlowAllocator LLC
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

final class FidoSalesTests: XCTestCase {
    var imp: FidoSales!
    let tzNewYork = TimeZone(identifier: "America/New_York")!

    override func setUpWithError() throws {
        imp = FidoSales()
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
        Xymbol(CUSIP),Security Description,Quantity,Date Acquired,Date Sold,Proceeds,Cost Basis,Short Term Gain/Loss,Long Term Gain/Loss
        """
        let expected: FINporter.DetectResult = [:]
        let actual = try imp.detect(dataPrefix: badHeader.data(using: .utf8)!)
        XCTAssertEqual(expected, actual)
    }

    func testDetectSucceeds() throws {
        let header = """
        Symbol(CUSIP),Security Description,Quantity,Date Acquired,Date Sold,Proceeds,Cost Basis,Short Term Gain/Loss,Long Term Gain/Loss
        """
        let expected: FINporter.DetectResult = [.allocTransaction: [.CSV]]
        let actual = try imp.detect(dataPrefix: header.data(using: .utf8)!)
        XCTAssertEqual(expected, actual)
    }

    func testDetectViaMain() throws {
        let header = """
        Symbol(CUSIP),Security Description,Quantity,Date Acquired,Date Sold,Proceeds,Cost Basis,Short Term Gain/Loss,Long Term Gain/Loss
        """
        let expected: FINporter.DetectResult = [.allocTransaction: [.CSV]]
        let main = FINprospector([FidoSales()])
        let data = header.data(using: .utf8)!
        let actual = try main.prospect(sourceFormats: [.CSV], dataPrefix: data)
        XCTAssertEqual(1, actual.count)
        _ = actual.map { key, value in
            XCTAssertNotNil(key as? FidoSales)
            XCTAssertEqual(expected, value)
        }
    }

    func testParse() throws {
        let str = """
        Symbol(CUSIP),Security Description,Quantity,Date Acquired,Date Sold,Proceeds,Cost Basis,Short Term Gain/Loss,Long Term Gain/Loss
        VEA(100000000),"VANGUARD TAX-MANAGEDINTL FD FTSE DEV MKTETF",3.0,08/31/2020,01/29/2021,"$12.00 ","$10.00 ","$1.50 ","$0.50 "
        """

        let url = URL(fileURLWithPath: "Realized_Gain_Loss_Account_X12345678.csv")
        var rejectedRows = [AllocRowed.RawRow]()
        let dataStr = str.data(using: .utf8)!
        let actual: [AllocRowed.DecodedRow] = try imp.decode(MTransaction.self, dataStr, rejectedRows: &rejectedRows, url: url, timeZone: tzNewYork)

        let YYYYMMDDts = parseFidoMMDDYYYY("01/29/2021", timeZone: tzNewYork)!
        let expected: AllocRowed.DecodedRow = [
            "txnAction": MTransaction.Action.buysell,
            "txnTransactedAt": YYYYMMDDts,
            "txnAccountID": "X12345678",
            "txnSecurityID": "VEA",
            "txnLotID": "",
            "txnShareCount": -3.000,
            "txnSharePrice": 4.000,
            "realizedGainShort": 1.50,
            "realizedGainLong": 0.50,
        ]

        XCTAssertTrue(areEqual([expected], actual))
        XCTAssertEqual(0, rejectedRows.count)
    }
}
