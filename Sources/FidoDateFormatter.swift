//
//  FidoDateFormatter.swift
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

import FINporter

let fidoDateFormatter: DateFormatter = {
    let df = DateFormatter()
    // h: Hour [1-12]
    // mm: minute (2 for zero padding)
    // a: AM or PM
    // v: Use one letter for short wall (generic) time (e.g., PT)
    df.dateFormat = "MM/dd/yyyy h:mm a v"
    return df
}()

/// parse a 'naked' MM/dd/yyyy date into a fully resolved date
/// assume noon of current time zone for any Fido date
func parseFidoMMDDYYYY(_ mmddyyyy: String?,
                       defTimeOfDay: String? = nil,
                       timeZone: TimeZone) -> Date?
{
    let timeOfDay: String = defTimeOfDay ?? "12:00"
    guard let _mmddyyyy = mmddyyyy,
          timeOfDay.count == 5
    else { return nil }

    let df = DateFormatter()
    df.dateFormat = "MM/dd/yyyy HH:mm"
    df.timeZone = timeZone

    let dateStr = "\(_mmddyyyy) \(timeOfDay)"
    let result = df.date(from: dateStr)
    return result
}
