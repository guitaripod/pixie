import Foundation
import Testing

@testable import Pixie

@MainActor
struct EditPresetSeasonTests {
    private func day(_ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    @Test func halloweenLeadsThroughTheSecondOfNovember() {
        #expect(EditPreset.seasonalID(on: day(10, 1)) == "halloween")
        #expect(EditPreset.seasonalID(on: day(11, 2)) == "halloween")
        #expect(EditPreset.all(on: day(10, 20)).first?.id == "halloween")
    }

    @Test func theHolidayCardLeadsFromMidNovemberThroughEpiphany() {
        #expect(EditPreset.seasonalID(on: day(11, 15)) == "holiday")
        #expect(EditPreset.seasonalID(on: day(12, 24)) == "holiday")
        #expect(EditPreset.seasonalID(on: day(1, 6)) == "holiday")
        #expect(EditPreset.all(on: day(12, 10)).first?.id == "holiday")
    }

    @Test func outsideBothSeasonsTheCatalogKeepsItsOrder() {
        for date in [day(11, 3), day(11, 14), day(1, 7), day(7, 1)] {
            #expect(EditPreset.seasonalID(on: date) == nil)
            #expect(EditPreset.all(on: date).first?.id == "headshot")
        }
    }

    @Test func bothSeasonalPresetsAreMarkedAndReachableByLink() {
        for id in ["halloween", "holiday"] {
            let preset = EditPreset.preset(id: id)
            #expect(preset?.isSeasonal == true)
            #expect(preset?.isPopular == false)
        }
        #expect(EditPreset.preset(id: "headshot")?.isSeasonal == false)
    }
}
