//
//  FidoSales.swift
//
//  Input: For use with Realized_Gain_Loss_Account_XXXXXXXX.csv from 'Closed Positions' of taxable accounts
//          from Fidelity Brokerage Services
//
//  Note that accountID is extracted from file URL.
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

public class FidoSales: FINporter {
    public override var name: String { "Fido Sales" }
    public override var id: String { "fido_sales" }
    public override var description: String { "Detect and decode realized sale export files from Fidelity." }
    public override var sourceFormats: [AllocFormat] { [.CSV] }
    public override var outputSchemas: [AllocSchema] { [.allocTransaction] }

    internal static let headerRE = #"Symbol\(CUSIP\),Security Description,Quantity,Date Acquired,Date Sold,Proceeds,Cost Basis,Short Term Gain/Loss,Long Term Gain/Loss"#

    internal static let csvRE = #"[A-Za-z0-9]+(?=\.)"#

    public override func detect(dataPrefix: Data) throws -> DetectResult {
        guard let str = FINporter.normalizeDecode(dataPrefix),
              str.range(of: FidoSales.headerRE,
                        options: .regularExpression) != nil
        else {
            return [:]
        }

        return outputSchemas.reduce(into: [:]) { map, schema in
            map[schema, default: []].append(.CSV)
        }
    }

    override open func decode<T: AllocRowed>(_ type: T.Type,
                                            _ data: Data,
                                            rejectedRows: inout [T.RawRow],
                                            inputFormat _: AllocFormat? = nil,
                                            outputSchema _: AllocSchema? = nil,
                                            url: URL? = nil,
                                            defTimeOfDay: String? = nil,
                                            timeZone: TimeZone = TimeZone.current,
                                            timestamp _: Date? = nil) throws -> [T.DecodedRow] {
        guard let str = FINporter.normalizeDecode(data) else {
            throw FINporterError.decodingError("unable to parse data")
        }

        // Extract X12345678 from "...Realized_Gain_Loss_Account_X12345678.csv"
        let accountID: String? = {
            if let urlStr = url?.absoluteString,
               let accountIDRange = urlStr.range(of: FidoSales.csvRE, options: .regularExpression) {
                return String(urlStr[accountIDRange])
            }
            return nil
        }()

        let delimitedRows = try CSV(string: str).namedRows
        
        return decodeDelimitedRows(delimitedRows: delimitedRows,
                                   defTimeOfDay: defTimeOfDay,
                                   timeZone: timeZone,
                                   rejectedRows: &rejectedRows,
                                   accountID: accountID)
    }
    
    internal func decodeDelimitedRows(delimitedRows: [AllocRowed.RawRow],
                                         defTimeOfDay: String? = nil,
                                         timeZone: TimeZone = TimeZone.current,
                                         rejectedRows: inout [AllocRowed.RawRow],
                                         accountID: String?) -> [AllocRowed.DecodedRow] {
        delimitedRows.reduce(into: []) { decodedRows, delimitedRow in
            // required values
            guard let symbolCusip = MTransaction.parseString(delimitedRow["Symbol(CUSIP)"]),
                  let symbol = symbolCusip.split(separator: "(").first,
                  symbol.count > 0,
                  let shareCount = MTransaction.parseDouble(delimitedRow["Quantity"]),
                  let proceeds = MTransaction.parseDouble(delimitedRow["Proceeds"]),
                  let dateSold = delimitedRow["Date Sold"],
                  let transactedAt = parseFidoMMDDYYYY(dateSold, defTimeOfDay: defTimeOfDay, timeZone: timeZone)
            else {
                rejectedRows.append(delimitedRow)
                return
            }
            
            // calculated values
            let sharePrice = (shareCount != 0) ? (proceeds / shareCount) : nil
            
            // optional values
            let realizedShort = MTransaction.parseDouble(delimitedRow["Short Term Gain/Loss"])
            let realizedLong = MTransaction.parseDouble(delimitedRow["Long Term Gain/Loss"])
            
            let securityID = String(symbol)
            let shareCount_ = -1 * shareCount // negative because it's a sale (reduction in shares)
            
            let lotID = ""
            
            decodedRows.append([
                MTransaction.CodingKeys.action.rawValue: MTransaction.Action.buysell,
                MTransaction.CodingKeys.transactedAt.rawValue: transactedAt,
                MTransaction.CodingKeys.accountID.rawValue: accountID ?? "",
                MTransaction.CodingKeys.securityID.rawValue: securityID,
                MTransaction.CodingKeys.lotID.rawValue: lotID,
                MTransaction.CodingKeys.shareCount.rawValue: shareCount_,
                MTransaction.CodingKeys.sharePrice.rawValue: sharePrice,
                MTransaction.CodingKeys.realizedGainShort.rawValue: realizedShort,
                MTransaction.CodingKeys.realizedGainLong.rawValue: realizedLong,
            ])
        }
    }
}
