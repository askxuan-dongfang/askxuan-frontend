import SwiftUI

enum JourneyHost {
    static var smokeBooking: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["ASKXUAN_JOURNEY_BOOKING"]
        #else
        return nil
        #endif
    }
    static let provider = false
    static func orderDetail(_ id: String) -> some View {
        CustomerBookingDetailView(bookingId: id)
    }
}
