//
//  FidoPurchases.swift
//
//  Input: for use with Accounts_History.csv from Fidelity Brokerage Services
//
//  Output: supports openalloc/history schema
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

import Foundation

import SwiftCSV

import AllocData
import FINporter

public class FidoHistory: FINporter {
    override public var name: String { "Fido History" }
    override public var id: String { "fido_history" }
    override public var description: String { "Detect and decode account history export files from Fidelity, for sale and purchase info." }
    override public var sourceFormats: [AllocFormat] { [.CSV] }
    override public var outputSchemas: [AllocSchema] { [.allocTransaction] }

    internal static let headerRE = #"""
    Brokerage

    Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,Price \(\$\),Commission \(\$\),Fees \(\$\),Accrued Interest \(\$\),Amount \(\$\),Settlement Date
    """#

    // should match all lines, until a blank line or end of block/file
    internal static let csvRE = #"Run Date,Account,Action,Symbol,Security Description,Security Type,Quantity,(?:.+(\n|\Z))+"#

    override public func detect(dataPrefix: Data) throws -> DetectResult {
        guard let str = FINporter.normalizeDecode(dataPrefix),
              str.range(of: FidoHistory.headerRE,
                        options: .regularExpression) != nil
        else {
            return [:]
        }

        return outputSchemas.reduce(into: [:]) { map, schema in
            map[schema, default: []].append(.CSV)
        }
    }

    override open func decode<T: AllocRowed>(_: T.Type,
                                             _ data: Data,
                                             rejectedRows: inout [T.RawRow],
                                             inputFormat _: AllocFormat? = nil,
                                             outputSchema _: AllocSchema? = nil,
                                             url _: URL? = nil,
                                             defTimeOfDay: String? = nil,
                                             timeZone: TimeZone = TimeZone.current,
                                             timestamp _: Date? = nil) throws -> [T.DecodedRow]
    {
        guard let str = FINporter.normalizeDecode(data) else {
            throw FINporterError.decodingError("unable to parse data")
        }

        var items = [T.DecodedRow]()

        if let csvRange = str.range(of: FidoHistory.csvRE, options: .regularExpression) {
            let csvStr = String(str[csvRange])
            let table = try NamedCSV(string: String(csvStr))
            let nuItems = decodeDelimitedRows(delimitedRows: table.rows,
                                              defTimeOfDay: defTimeOfDay,
                                              timeZone: timeZone,
                                              rejectedRows: &rejectedRows)
            items.append(contentsOf: nuItems)
        }

        return items
    }

    internal func decodeDelimitedRows(delimitedRows: [AllocRowed.RawRow],
                                      defTimeOfDay: String? = nil,
                                      timeZone: TimeZone = TimeZone.current,
                                      rejectedRows: inout [AllocRowed.RawRow]) -> [AllocRowed.DecodedRow]
    {
        // let trimFromTicker = CharacterSet(charactersIn: "*")

        delimitedRows.reduce(into: []) { decodedRows, delimitedRow in
            // required values
            guard let rawAction = MTransaction.parseString(delimitedRow["Action"]),
                  let rawDate = delimitedRow["Run Date"],
                  let transactedAt = parseFidoMMDDYYYY(rawDate, defTimeOfDay: defTimeOfDay, timeZone: timeZone),
                  let accountNameNumber = MTransaction.parseString(delimitedRow["Account"]),
                  let accountID = accountNameNumber.split(separator: " ").last,
                  accountID.count > 0
            else {
                rejectedRows.append(delimitedRow)
                return
            }

            guard let decodedRow = decodeRow(delimitedRow: delimitedRow,
                                             transactedAt: transactedAt,
                                             rawAction: rawAction,
                                             accountID: String(accountID))
            else {
                rejectedRows.append(delimitedRow)
                return
            }

            decodedRows.append(decodedRow)
        }
    }

    internal func decodeRow(delimitedRow: AllocRowed.RawRow,
                            transactedAt: Date,
                            rawAction: String,
                            accountID: String) -> AllocRowed.DecodedRow?
    {
        let netAction: MTransaction.Action = {
            switch rawAction {
            case let str where str.starts(with: "YOU BOUGHT "):
                return .buysell
            case let str where str.starts(with: "PURCHASE INTO "):
                return .buysell
            case let str where str.starts(with: "YOU SOLD "):
                return .buysell
            case let str where str.starts(with: "REDEMPTION FROM "):
                return .buysell
            case let str where str.starts(with: "REINVESTMENT "):
                return .buysell
            case let str where str.starts(with: "TRANSFER OF ASSETS "):
                return .transfer
            case let str where str.starts(with: "DIVIDEND RECEIVED "):
                return .income
            case let str where str.starts(with: "LONG-TERM CAP GAIN "):
                return .income
            case let str where str.starts(with: "SHORT-TERM CAP GAIN "):
                return .income
            case let str where str.starts(with: "INTEREST EARNED "):
                return .income
            default:
                return .miscflow
            }
        }()

        var decodedRow: AllocRowed.DecodedRow = [
            MTransaction.CodingKeys.action.rawValue: netAction,
            MTransaction.CodingKeys.transactedAt.rawValue: transactedAt,
            MTransaction.CodingKeys.accountID.rawValue: accountID,
        ]

        let rawAmount = MTransaction.parseDouble(delimitedRow["Amount ($)"])
        let rawSymbol = MTransaction.parseString(delimitedRow["Symbol"])
        let rawShareCount = MTransaction.parseDouble(delimitedRow["Quantity"])
        let rawSharePrice = MTransaction.parseDouble(delimitedRow["Price ($)"])

        switch netAction {
        case .buysell:
            guard let symbol = rawSymbol,
                  let shareCount = rawShareCount,
                  let sharePrice = rawSharePrice
            else {
                return nil
            }

            decodedRow[MTransaction.CodingKeys.securityID.rawValue] = symbol
            decodedRow[MTransaction.CodingKeys.shareCount.rawValue] = shareCount
            decodedRow[MTransaction.CodingKeys.sharePrice.rawValue] = sharePrice

        case .transfer:
            if let symbol = rawSymbol {
                guard let quantity = rawShareCount else { return nil }

                decodedRow[MTransaction.CodingKeys.shareCount.rawValue] = quantity
                decodedRow[MTransaction.CodingKeys.securityID.rawValue] = symbol

                // if transfer of a stock/etf, there may be no share price
                if let sharePrice = rawSharePrice {
                    decodedRow[MTransaction.CodingKeys.sharePrice.rawValue] = sharePrice
                }
            } else {
                // no symbol, so it's probably cash (where amount is required)
                guard let amount = rawAmount else { return nil }

                decodedRow[MTransaction.CodingKeys.shareCount.rawValue] = amount
                decodedRow[MTransaction.CodingKeys.sharePrice.rawValue] = 1.0
            }

        case .income, .miscflow:
            guard let amount = rawAmount else { return nil }

            decodedRow[MTransaction.CodingKeys.shareCount.rawValue] = amount
            decodedRow[MTransaction.CodingKeys.sharePrice.rawValue] = 1.0

            if let symbol = rawSymbol {
                decodedRow[MTransaction.CodingKeys.securityID.rawValue] = symbol
            }
        }

        return decodedRow
    }
}

// optional values

//            let accountNameNumber = MTransaction.parseString(delimitedRow["Account"]),
//                  let accountID = accountNameNumber.split(separator: " ").last,
//                  accountID.count > 0,
//                  let securityID = MTransaction.parseString(delimitedRow["Symbol"], trimCharacters: trimFromTicker),
//                  securityID.count > 0,
//                  let shareCount = MTransaction.parseDouble(delimitedRow["Quantity"]),
//                  let sharePrice = MTransaction.parseDouble(delimitedRow["Price ($)"]),
//                  let runDate = delimitedRow["Run Date"],
//                  let transactedAt = parseFidoMMDDYYYY(runDate, defTimeOfDay: defTimeOfDay, timeZone: timeZone)

// unfortunately, no realized gain/loss info available in this export
// see the fido_sales report for that

// let lotID = ""

// decodedRows.append([
// MTransaction.CodingKeys.transactedAt.rawValue: transactedAt,
// MTransaction.CodingKeys.accountID.rawValue: accountID,
// MTransaction.CodingKeys.securityID.rawValue: securityID,
// MTransaction.CodingKeys.lotID.rawValue: lotID,
// MTransaction.CodingKeys.shareCount.rawValue: shareCount,
// MTransaction.CodingKeys.sharePrice.rawValue: sharePrice,
// MTransaction.CodingKeys.realizedGainShort.rawValue: nil,
// MTransaction.CodingKeys.realizedGainLong.rawValue: nil,
// ])
