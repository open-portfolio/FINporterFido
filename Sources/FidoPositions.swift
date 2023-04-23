//
//  FidoPositions.swift
//
//
//  Input: for use with Portfolio_Positions_Mmm-DD-YYYY.csv from Fidelity Brokerage Services
//
//  Output: supports openalloc/holding, /security, /account, and /meta schemas
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

public class FidoPositions: FINporter {
    override public var name: String { "Fido Positions" }
    override public var id: String { "fido_positions" }
    override public var description: String { "Detect and decode position export files from Fidelity." }
    override public var sourceFormats: [AllocFormat] { [.CSV] }
    override public var outputSchemas: [AllocSchema] { [.allocMetaSource, .allocAccount, .allocHolding, .allocSecurity] }

    private let trimFromTicker = CharacterSet(charactersIn: "*")

    internal static let headerRE = #"""
    Account Number,Account Name,Symbol,Description,Quantity,Last Price,Last Price Change,Current Value,Today's Gain/Loss Dollar,Today's Gain/Loss Percent,Total Gain/Loss Dollar,Total Gain/Loss Percent,Percent Of Account,Cost Basis Total,Average Cost Basis,Type
    """#

    // should match all lines, until a blank line or end of block/file
    internal static let csvRE = #"Account Number,Account Name,Symbol,Description,Quantity,(?:.+(\n|\Z))+"#

    override public func detect(dataPrefix: Data) throws -> DetectResult {
        guard let str = FINporter.normalizeDecode(dataPrefix),
              str.range(of: FidoPositions.headerRE,
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
                                             outputSchema: AllocSchema? = nil,
                                             url: URL? = nil,
                                             defTimeOfDay _: String? = nil,
                                             timeZone _: TimeZone = TimeZone.current,
                                             timestamp: Date? = nil) throws -> [T.DecodedRow]
    {
        guard let str = FINporter.normalizeDecode(data) else {
            throw FINporterError.decodingError("unable to parse data")
        }

        guard let outputSchema_ = outputSchema else {
            throw FINporterError.needExplicitOutputSchema(outputSchemas)
        }

        var items = [T.DecodedRow]()

        if outputSchema_ == .allocMetaSource {
            var exportedAt: Date? = nil

            // extract exportedAt from "Date downloaded 07/30/2021 2:26 PM ET" (with quotes)
            let ddRE = #"(?<=\"Date downloaded ).+(?=\")"#
            if let dd = str.range(of: ddRE, options: .regularExpression) {
                exportedAt = fidoDateFormatter.date(from: String(str[dd]))
            }

            let sourceMetaID = UUID().uuidString

            items.append([
                MSourceMeta.CodingKeys.sourceMetaID.rawValue: sourceMetaID,
                MSourceMeta.CodingKeys.url.rawValue: url,
                MSourceMeta.CodingKeys.importerID.rawValue: id,
                MSourceMeta.CodingKeys.exportedAt.rawValue: exportedAt,
            ])

        } else {
            if let csvRange = str.range(of: FidoPositions.csvRE, options: .regularExpression) {
                let csvStr = str[csvRange]
                let table = try NamedCSV(string: String(csvStr))
                let nuItems = decodeDelimitedRows(delimitedRows: table.rows,
                                                  outputSchema_: outputSchema_,
                                                  rejectedRows: &rejectedRows,
                                                  timestamp: timestamp)
                items.append(contentsOf: nuItems)
            }
        }

        return items
    }

    internal func decodeDelimitedRows(delimitedRows: [AllocRowed.RawRow],
                                      outputSchema_: AllocSchema,
                                      rejectedRows: inout [AllocRowed.RawRow],
                                      timestamp: Date?) -> [AllocRowed.DecodedRow]
    {
        delimitedRows.reduce(into: []) { decodedRows, delimitedRow in
            switch outputSchema_ {
            case .allocAccount:
                guard let item = account(delimitedRow, rejectedRows: &rejectedRows) else { return }
                decodedRows.append(item)
            case .allocHolding:
                guard let item = holding(delimitedRow, rejectedRows: &rejectedRows) else { return }
                decodedRows.append(item)
            case .allocSecurity:
                guard let item = security(delimitedRow, rejectedRows: &rejectedRows, timestamp: timestamp) else { return }
                decodedRows.append(item)
            default:
                rejectedRows.append(delimitedRow)
                // throw FINporterError.targetSchemaNotSupported(outputSchemas)
            }
        }
    }

    internal func holding(_ row: AllocRowed.RawRow, rejectedRows: inout [AllocRowed.RawRow]) -> AllocRowed.DecodedRow? {
        // required values
        guard let accountID = MHolding.parseString(row["Account Number"]),
              accountID.count > 0,
              let securityID = MHolding.parseString(row["Symbol"], trimCharacters: trimFromTicker),
              securityID.count > 0,
              securityID != "Pending Activity",
              let shareCount = MHolding.parseDouble(row["Quantity"]),
              shareCount != 0
        else {
            rejectedRows.append(row)
            return nil
        }

        var decodedRow: AllocRowed.DecodedRow = [
            MHolding.CodingKeys.accountID.rawValue: accountID,
            MHolding.CodingKeys.securityID.rawValue: securityID,
            MHolding.CodingKeys.shareCount.rawValue: shareCount,
        ]

        // holding may have "n/a" for share basis
        var shareBasis: Double? = nil
        shareBasis = MHolding.parseDouble(row["Cost Basis Per Share"])
        if shareBasis == nil || shareBasis == 0,
           row["Cost Basis Per Share"] == "n/a"
        {
            if let sharePrice = MHolding.parseDouble(row["Last Price"]),
               sharePrice == 1.0
            {
                // assume it's cash, where the share basis is 1.00
                shareBasis = 1.0
            } else if let costBasis = MHolding.parseDouble(row["Cost Basis"]),
                      costBasis > 0
            {
                // reconstruct the shareBasis
                shareBasis = costBasis / shareCount
            }
        }

        if let _shareBasis = shareBasis {
            decodedRow[MHolding.CodingKeys.shareBasis.rawValue] = _shareBasis
        }

        return decodedRow
    }

    internal func security(_ row: AllocRowed.RawRow, rejectedRows: inout [AllocRowed.RawRow], timestamp: Date?) -> AllocRowed.DecodedRow? {
        guard let securityID = MHolding.parseString(row["Symbol"], trimCharacters: trimFromTicker),
              securityID.count > 0,
              securityID != "Pending Activity",
              let sharePrice = MHolding.parseDouble(row["Last Price"])
        else {
            rejectedRows.append(row)
            return nil
        }

        var decodedRow: AllocRowed.DecodedRow = [
            MSecurity.CodingKeys.securityID.rawValue: securityID,
            MSecurity.CodingKeys.sharePrice.rawValue: sharePrice,
        ]

        if let updatedAt = timestamp {
            decodedRow[MSecurity.CodingKeys.updatedAt.rawValue] = updatedAt
        }

        return decodedRow
    }

    internal func account(_ row: AllocRowed.RawRow, rejectedRows: inout [AllocRowed.RawRow]) -> AllocRowed.DecodedRow? {
        guard let accountID = MHolding.parseString(row["Account Number"]),
              accountID.count > 0,
              let title = MHolding.parseString(row["Account Name"])
        else {
            rejectedRows.append(row)
            return nil
        }

        return [
            MAccount.CodingKeys.accountID.rawValue: accountID,
            MAccount.CodingKeys.title.rawValue: title,
        ]
    }
}
