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
import SwiftCSV

final class FidoHistoryActionTests: XCTestCase {
    var imp: FidoHistory!
    let df = ISO8601DateFormatter()
    var rr: [AllocRowed.RawRow]!
    let tzNewYork = TimeZone(identifier: "America/New_York")!

    override func setUpWithError() throws {
        imp = FidoHistory()
        rr = []
    }

    func testBuy() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
         07/30/2021,BROKERAGE 200000000, YOU BOUGHT VANGUARD TAX-MANAGED INTL FD FTSE DEV M (VEA) (Cash), VEA, VANGUARD TAX-MANAGED INTL FD FTSE DEV M,Cash,0.446,51.38,,,,-22.92,08/02/2021
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnSecurityID": "VEA", "txnShareCount": 0.446, "txnAccountID": "200000000", "txnAction": AllocData.MTransaction.Action.buysell, "txnTransactedAt": timestamp1, "txnSharePrice": 51.38]]
        XCTAssertEqual(expected, actual)
    }

    func testSell() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        07/30/2021,BROKERAGE 200000000, YOU SOLD ISHARES TR 20 YR TR BD ETF (TLT) (Cash), TLT, ISHARES TR 20 YR TR BD ETF,Cash,-86,144.41,,0.07,,12418.76,08/02/2021
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnSecurityID": "TLT", "txnShareCount": -86.0, "txnAccountID": "200000000", "txnAction": AllocData.MTransaction.Action.buysell, "txnTransactedAt": timestamp1, "txnSharePrice": 144.41]]
        XCTAssertEqual(expected, actual)
    }

    func testTransferCashIn() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        07/30/2021,CASH MGMT Z00000000, TRANSFER OF ASSETS ACAT DELIVER (Cash), , No Description,Cash,,,,,,1010,
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnShareCount": 1010.0, "txnAccountID": "Z00000000", "txnAction": AllocData.MTransaction.Action.transfer, "txnTransactedAt": timestamp1, "txnSharePrice": 1.0]]
        XCTAssertEqual(expected, actual)
    }

    // NOTE speculative!
    func testTransferSecurityOut() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        07/30/2021,BROKERAGE 20000000, TRANSFER OF ASSETS ACAT DELIVER, TLT, ISHARES TR 20 YR TR BD ETF,Cash,-86,144.41,,0.07,,12418.76,08/02/2021
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnSecurityID": "TLT", "txnShareCount": -86, "txnAccountID": "20000000", "txnAction": AllocData.MTransaction.Action.transfer, "txnTransactedAt": timestamp1, "txnSharePrice": 144.41]]
        XCTAssertEqual(expected, actual)
    }

    // NOTE speculative!
    func testTransferSecurityIn() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        07/30/2021,BROKERAGE 20000000, TRANSFER OF ASSETS ACAT RECEIVE, TLT, ISHARES TR 20 YR TR BD ETF,Cash,86,144.41,,0.07,,12418.76,08/02/2021
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnSecurityID": "TLT", "txnShareCount": 86, "txnAccountID": "20000000", "txnAction": AllocData.MTransaction.Action.transfer, "txnTransactedAt": timestamp1, "txnSharePrice": 144.41]]
        XCTAssertEqual(expected, actual)
    }

    func testDividend() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        07/30/2021,BROKERAGE 200000000, DIVIDEND RECEIVED VANGUARD INTL EQUITY INDEX FDS FTSE PAC (VPL) (Cash), VPL, VANGUARD INTL EQUITY INDEX FDS FTSE PAC,Cash,,,,,,297.62,
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnSecurityID": "VPL", "txnShareCount": 297.62, "txnAccountID": "200000000", "txnAction": AllocData.MTransaction.Action.income, "txnTransactedAt": timestamp1, "txnSharePrice": 1.0]]
        XCTAssertEqual(expected, actual)
    }

    func testInterest() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        07/30/2021,CASH MGMT Z00000000, INTEREST EARNED FDIC INSURED DEPOSIT AT JP MORGAN BK NO (QXXXX) (Cash), QXXXX, FDIC INSURED DEPOSIT AT JP MORGAN BK NO,Cash,,,,,,1.56,
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnShareCount": 1.56, "txnAccountID": "Z00000000", "txnSecurityID": "QXXXX", "txnAction": AllocData.MTransaction.Action.income, "txnTransactedAt": timestamp1, "txnSharePrice": 1.0]]
        XCTAssertEqual(expected, actual)
    }

    func testRedemption() throws {
        let csvStr = """
        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        07/30/2021,CASH MGMT Z00000000, REDEMPTION FROM CORE ACCOUNT FDIC INSURED DEPOSIT AT JP MORGAN BK NO (QXXXX) (Cash), QXXXX, FDIC INSURED DEPOSIT AT JP MORGAN BK NO,Cash,-1010,1,,,,1010,
        """

        let timestamp1 = df.date(from: "2021-07-30T16:00:00Z")!
        let table = try NamedCSV(string: String(csvStr))
        let actual = imp.decodeDelimitedRows(delimitedRows: table.rows,
                                             timeZone: tzNewYork,
                                             rejectedRows: &rr)
        let expected: [AllocRowed.DecodedRow] = [["txnShareCount": -1010, "txnAccountID": "Z00000000", "txnSecurityID": "QXXXX", "txnAction": AllocData.MTransaction.Action.buysell, "txnTransactedAt": timestamp1, "txnSharePrice": 1.0]]
        XCTAssertEqual(expected, actual)
    }

    func testVarious() throws {
        let YYYYMMDDts = parseFidoMMDDYYYY("03/01/2021", timeZone: tzNewYork)!
        let miscflow = AllocData.MTransaction.Action.miscflow
        let income = AllocData.MTransaction.Action.income
        let buysell = AllocData.MTransaction.Action.buysell
        let transfer = AllocData.MTransaction.Action.transfer
        let accountID = "X0000000A"

        let rows: [(csvRow: String, expected: [AllocRowed.DecodedRow])] = [
            // buysell

            ("03/01/2021,PASSIVE X0000000A,  PURCHASE INTO CORE ACCOUNT FIDELITY GOVERNMENT MONEY MARKET (SPAXX) MORNING TRADE (Cash), SPAXX, FIDELITY GOVERNMENT MONEY MARKET,Cash,700.00,1,,,,-700.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 700.0, "txnAction": buysell, "txnAccountID": accountID, "txnSecurityID": "SPAXX"]]),

            ("03/01/2021,PASSIVE X0000000A, YOU SOLD VANGUARD IDX FUND (VTI) (Cash), VTI, VANGUARD IDX FUND,Cash,-7.0,100.0,,0.08,700.00,03/05/2021",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 100.0, "txnShareCount": -7.0, "txnAction": buysell, "txnAccountID": accountID, "txnSecurityID": "VTI"]]),

            ("03/01/2021,PASSIVE X0000000A, YOU BOUGHT VANGUARD INDEX FDS VANGUARD VALUE ETF F (VTV) (Cash), VTV, VANGUARD INDEX FDS VANGUARD VALUE ETF F,Cash,7.0,100.0,,,,-700.0,03/05/2021",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 100.0, "txnShareCount": 7.0, "txnAction": buysell, "txnAccountID": accountID, "txnSecurityID": "VTV"]]),

            ("03/01/2021,PASSIVE X0000000A,  REDEMPTION FROM CORE ACCOUNT FIDELITY GOVERNMENT MONEY MARKET (SPAXX) MORNING TRADE (Cash), SPAXX, FIDELITY GOVERNMENT MONEY MARKET,Cash,-17.00,1,,,,17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": -17.0, "txnAction": buysell, "txnAccountID": accountID, "txnSecurityID": "SPAXX"]]),

            ("03/01/2021,PASSIVE X0000000A, REINVESTMENT FIDELITY GOVERNMENT MONEY MARKET (SPAXX) (Cash), SPAXX, FIDELITY GOVERNMENT MONEY MARKET,Cash,-17.00,1,,,,-17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": -17.0, "txnAction": buysell, "txnAccountID": accountID, "txnSecurityID": "SPAXX"]]),

            // transfer

            ("03/01/2021,CASH MGMT X0000000A, TRANSFER OF ASSETS ACAT DELIVER (Cash), , No Description,Cash,,,,,,17.0,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 17.0, "txnAction": transfer, "txnAccountID": accountID]]),

            ("03/01/2021,BROKERAGE X0000000A, TRANSFER OF ASSETS ACAT RECEIVE, TLT, ISHARES TR 20 YR TR BD ETF,Cash,86,144.41,,0.07,,12418.76,08/02/2021",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 144.41, "txnShareCount": 86.0, "txnAction": transfer, "txnAccountID": accountID, "txnSecurityID": "TLT"]]),

            ("03/01/2021,BROKERAGE X0000000A, TRANSFER OF ASSETS ACAT DELIVER, TLT, ISHARES TR 20 YR TR BD ETF,Cash,-86,144.41,,0.07,,12418.76,08/02/2021",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 144.41, "txnShareCount": -86.0, "txnAction": transfer, "txnAccountID": accountID, "txnSecurityID": "TLT"]]),

            // no share price on this stock transfer
            ("03/01/2021,BROKERAGE X0000000A, TRANSFER OF ASSETS EST SETTLE 02-04-21 ALPHABET INC (ABCD) (Cash), ABCD, ALPHA INC,Cash,-200,,,,,,",
             [["txnTransactedAt": YYYYMMDDts, "txnShareCount": -200.0, "txnAction": transfer, "txnAccountID": accountID, "txnSecurityID": "ABCD"]]),

            // income

            ("03/01/2021,PASSIVE X0000000A, DIVIDEND RECEIVED VANGUARD EMERGING MARKETS (VWO) (Cash), VWO,  VANGUARD EMERGING MARKETS,Cash,,,,,,17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 17.0, "txnAction": income, "txnAccountID": accountID, "txnSecurityID": "VWO"]]),

            ("03/01/2021,PASSIVE X0000000A, LONG-TERM CAP GAIN VANGUARD CHARLOTTE TOTAL INTL BD INDEX (BNDX) (Cash), BNDX, VANGUARD CHARLOTTE TOTAL INTL BD INDEX,Cash,,,,,,17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 17.0, "txnAction": income, "txnAccountID": accountID, "txnSecurityID": "BNDX"]]),

            ("03/01/2021,PASSIVE X0000000A, SHORT-TERM CAP GAIN VANGUARD CHARLOTTE TOTAL INTL BD INDEX (BNDX) (Cash), BNDX, VANGUARD CHARLOTTE TOTAL INTL BD INDEX,Cash,,,,,,17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 17.0, "txnAction": income, "txnAccountID": accountID, "txnSecurityID": "BNDX"]]),

            ("03/01/2021,CASH MGMT X0000000A, INTEREST EARNED FDIC INSURED DEPOSIT AT JP MORGAN BK NO (QIMHQ) (Cash), QIMHQ, FDIC INSURED DEPOSIT AT JP MORGAN BK NO,Cash,,,,,,17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 17.0, "txnAction": income, "txnAccountID": accountID, "txnSecurityID": "QIMHQ"]]),

            // miscflow

            ("03/01/2021,PASSIVE X0000000A, UNANTICIPATED ITEM TREATED AS MISC FLOW, BLAH, BLORT,Cash,-17.00,1,,,,-17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": -17.0, "txnAction": miscflow, "txnAccountID": accountID, "txnSecurityID": "BLAH"]]),

            ("03/01/2021,CASH MGMT X0000000A, DEBIT CARD PURCHASE, , No Description,Cash,,,,,,-17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": -17.0, "txnAction": miscflow, "txnAccountID": accountID]]),

            ("03/01/2021,CASH MGMT X0000000A, DIRECT DEBIT XCEL ENERGY 0000001111XCELENERGY (Cash), , No Description,Cash,,,,,,-17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": -17.0, "txnAction": miscflow, "txnAccountID": accountID]]),

            ("03/01/2021,CASH MGMT X0000000A, DIRECT DEPOSIT XCEL ENERGY 0000001111XCELENERGY (Cash), , No Description,Cash,,,,,,17.00,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 17.0, "txnAction": miscflow, "txnAccountID": accountID]]),

            ("03/01/2021,CASH MGMT X0000000A, TRANSFERRED FROM VS Z00-123456-1 (Cash),  , No Description,Cash,,,,,,17.0,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": 17.0, "txnAction": miscflow, "txnAccountID": accountID]]),

            ("03/01/2021,CASH MGMT X0000000A, TRANSFERRED FTOROM VS Z00-123456-1 (Cash),  , No Description,Cash,,,,,,-17.0,",
             [["txnTransactedAt": YYYYMMDDts, "txnSharePrice": 1.0, "txnShareCount": -17.0, "txnAction": miscflow, "txnAccountID": accountID]]),
        ]

        let body = """
        Brokerage

        Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price ($),Commission ($),Fees ($),Accrued Interest ($),Amount ($),Settlement Date
        ##ROW##

        """

        for row in rows {
            var rr = [AllocRowed.RawRow]()
            let dataStr = body.replacingOccurrences(of: "##ROW##", with: row.csvRow).data(using: .utf8)!
            let actual: [AllocRowed.DecodedRow] = try imp.decode(MTransaction.self, dataStr, rejectedRows: &rr, timeZone: tzNewYork)

            XCTAssertEqual(row.expected, actual, "ROW: \(row)")
            // XCTAssertEqual(row.rejectedRows, rr.count, "ROW: \(row)")
        }
    }
}
