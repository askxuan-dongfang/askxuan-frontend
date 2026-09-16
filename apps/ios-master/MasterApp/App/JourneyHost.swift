import SwiftUI

enum JourneyHost {
    static var smokeBooking: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["ASKXUAN_JOURNEY_BOOKING"]
        #else
        return nil
        #endif
    }
    static let provider = true
    static func orderDetail(_ id: String) -> some View {
        BookingDetailView(bookingId: id)
    }
}
