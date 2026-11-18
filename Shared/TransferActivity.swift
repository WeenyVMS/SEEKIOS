import Foundation

/// Compatibility placeholder for the iOS 15 version of Seekios.
///
/// ActivityKit, Live Activities, Dynamic Island and Lock Screen
/// transfer widgets require iOS 16.1 or later. These features
/// are disabled in this build.
///
/// Transfer progress remains visible inside the application.
/// Automatic retries, background transfer support and completion
/// notifications are managed by TransferMonitor.
enum TransferActivityCompatibility {
    static let liveActivitiesAvailable = false
}
