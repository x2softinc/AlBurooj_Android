import Foundation

enum AudioResource {
    /// Subdirectory (blue folder reference) where audio files are stored.
    static let subdirectory = "Audio"

    // MARK: - URLs

    /// Returns a URL for an audio file, preferring the `Audio` subdirectory and
    /// falling back to the bundle root if needed.
    static func url(named name: String, withExtension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
        ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    /// Returns all URLs for files with the given extension in the `Audio` subdirectory.
    /// Returns an empty array if none found.
    static func urls(withExtension ext: String) -> [URL] {
        Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) ?? []
    }

    // MARK: - Convenience

    static func mp3(named name: String) -> URL? {
        url(named: name, withExtension: "mp3")
    }

    static func caf(named name: String) -> URL? {
        url(named: name, withExtension: "caf")
    }
}
