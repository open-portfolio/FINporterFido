//
//  FidoDateFormatterTests.swift
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
import FINporter

final class FidoDateFormatterTests: XCTestCase {
    let df = ISO8601DateFormatter()
    let tzNewYork = TimeZone(identifier: "America/New_York")!
    let tzDenver = TimeZone(identifier: "America/Denver")!
    
    func testBasic() throws {
        let actual = parseFidoMMDDYYYY("03/01/2021", timeZone: tzNewYork)
        let expected = df.date(from: "2021-03-01T17:00:00Z")
        XCTAssertEqual(expected, actual)
    }
    
    func testOverrideTimeOfDay() throws {
        let actual = parseFidoMMDDYYYY("03/01/2021", defTimeOfDay: "13:00", timeZone: tzNewYork)
        let expected = df.date(from: "2021-03-01T18:00:00Z")
        XCTAssertEqual(expected, actual)
    }

    func testOverrideTimeZone() throws {
        let actual = parseFidoMMDDYYYY("03/01/2021", timeZone: tzDenver)
        let expected = df.date(from: "2021-03-01T19:00:00Z")
        XCTAssertEqual(expected, actual)
    }

    func testOverrideBoth() throws {
        let actual = parseFidoMMDDYYYY("03/01/2021", defTimeOfDay: "13:00", timeZone: tzDenver)
        let expected = df.date(from: "2021-03-01T20:00:00Z")
        XCTAssertEqual(expected, actual)
    }
}
