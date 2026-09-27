// Tests for what home's views decide: the waveform's bars, the loading bar, the tile columns and the mood pictures.

import AppKit
import ImageIO
import Testing
import UttrflowUX

@testable import Uttrflow

@MainActor
@Suite("Home's views")
struct HomeHeroViewTests {
    @Test("the waveform is tallest and strongest in the middle and fades to both ends")
    func waveformBell() {
        let bars = (0..<HomeWaveform.count).map(HomeWaveform.bar)
        let middle = HomeWaveform.count / 2
        let peak = bars.map(\.height).max() ?? 0
        #expect(bars.allSatisfy { $0.height > 0 && $0.height <= 1 })
        #expect(bars.allSatisfy { $0.opacity >= 0.35 && $0.opacity <= 0.95 })
        #expect(bars[middle].opacity > bars[0].opacity)
        #expect(bars[0].height < peak / 2)
        #expect(bars[HomeWaveform.count - 1].height < peak / 2)
    }

    @Test(
        "the loading bar's segment slides in from off the left and leaves past the right, then starts again")
    func loadingBarSlides() {
        let segment = HomeModelBar.width * HomeModelBar.segment
        let middle = HomeModelBar.offset(at: HomeModelBar.period / 2)
        #expect(HomeModelBar.offset(at: 0) == -segment)
        #expect(HomeModelBar.offset(at: HomeModelBar.period * 0.999) > HomeModelBar.width)
        #expect(middle > 0 && middle < HomeModelBar.width)
        let again = HomeModelBar.offset(at: HomeModelBar.period * 1.25)
        #expect(abs(again - HomeModelBar.offset(at: HomeModelBar.period * 0.25)) < 0.001)
    }

    @Test("four tiles share a row only where each keeps its narrowest width")
    func tileColumns() {
        let four = HomeStatTileView.narrowest * 4 + 36
        #expect(HomeStatTileView.columns(forWidth: four) == 4)
        #expect(HomeStatTileView.columns(forWidth: four - 1) == 2)
    }

    @Test("every mood's picture ships, decoded no larger than it is drawn, and only the latest is kept")
    func moodPictures() async {
        for mood in HomeMood.allCases {
            let picture = await MoodPictures.picture(for: mood)
            #expect(picture != nil, "\(mood.imageName) is missing")
            let image = picture?.image
            #expect(max(image?.width ?? 0, image?.height ?? 0) <= MoodPictures.pixels)
            #expect(Double(image?.width ?? 0) >= HomeMoodPicture.widest * 2 - 1)
            #expect(MoodPictures.cached(for: mood)?.image === image)
        }
        #expect(MoodPictures.cached(for: .morning) == nil)
    }

    @Test("four tiles take one row where they fit and two rows where they do not, with no measuring pass")
    func tileGridRows() {
        let four = HomeStatTileView.narrowest * 4 + HomeTileGrid.spacing * 3
        #expect(HomeTileGrid.rows(count: 4, width: four) == 1)
        #expect(HomeTileGrid.rows(count: 4, width: four - 1) == 2)
        #expect(HomeTileGrid.rows(count: 0, width: four) == 0)
    }

    @Test("an account picture is decoded to avatar size and kept for the same bytes")
    func accountPicture() async throws {
        let image = try #require(await MoodPictures.picture(for: .evening)?.image)
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        let bytes = data as Data
        let avatar = try #require(await AccountPictures.image(for: bytes))
        #expect(max(avatar.width, avatar.height) <= AccountPictures.pixels)
        #expect(AccountPictures.cached(for: bytes) === avatar)
        #expect(AccountPictures.cached(for: Data([1, 2, 3])) == nil)
    }

    @Test("each stat tile has its own icon")
    func symbols() {
        let symbols = HomeStatKind.allCases.map(HomeStatTileView.symbol)
        #expect(Set(symbols).count == HomeStatKind.allCases.count)
    }
}
