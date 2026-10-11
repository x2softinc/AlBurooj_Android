import Foundation
import UserNotifications

enum AdhanSoundPreference {
    static let storageKey = "adhanSound"
}

enum AdhanSoundOption: String, CaseIterable, Identifiable {
    case systemDefault = "Default"
    case adhan1 = "Adhan1"
    case adhan2 = "Adhan2"
    case adhan3 = "Adhan3"
    case adhan4 = "Adhan4"
    case ahmadAlNafees = "Ahmad_Al_Nafees"
    case alAqsa = "AlAqsa"
    case alHaram = "Al_Haram"
    case hafizMustafaOozcan = "Hafiz_Mustafa_Oozcan"
    case karlJenkins = "Karl_Jenkins"
    case madhina = "Madhina"
    case makkah = "Makkah"
    case misharyRashidAlafasy = "Mishary_Rashid_Alafasy"
    case misharyRashidAlafasy2 = "Mishary_Rashid_Alafasy2"
    case misharyRashidAlafasy3 = "Mishary_Rashid_Alafasy3"
    case qariAbdulKareem = "Qari_Abdul_Kareem"
    case salahMansoorAzZahrani = "Salah_Mansoor_AzZahrani"
    case sheikhJamacHareed = "Sheikh_Jamac_Hareed"
    

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemDefault: return "Default"
        case .adhan1: return "Adhan 1"
        case .adhan2: return "Adhan 2"
        case .adhan3: return "Adhan 3"
        case .adhan4: return "Adhan 4"
        case .ahmadAlNafees: return "Ahmad Al Nafees"
        case .alAqsa: return "Al Aqsa"
        case .alHaram: return "Al Haram"
        case .hafizMustafaOozcan: return "Hafiz Mustafa Oozcan"
        case .karlJenkins: return "Karl Jenkins"
        case .madhina: return "Madinah"
        case .makkah: return "Makkah"
        case .misharyRashidAlafasy: return "Mishary Rashid Alafasy"
        case .misharyRashidAlafasy2: return "Mishary Rashid Alafasy 2"
        case .misharyRashidAlafasy3: return "Mishary Rashid Alafasy 3"
        case .qariAbdulKareem: return "Qari Abdul Kareem"
        case .salahMansoorAzZahrani: return "Salah Mansoor Az Zahrani"
        case .sheikhJamacHareed: return "Sheikh Jamac Hareed"
        }
    }

    /// The .caf file name without extension, or nil for the system default sound.
    var resourceName: String? {
        guard self != .systemDefault else { return nil }
        return rawValue
    }

    /// The URL for the preview MP3 file, or nil for the system default sound.
    var previewURL: URL? {
        guard let resourceName else { return nil }
        return AudioResource.mp3(named: resourceName)
    }

    /// The sound used when scheduling an Adhan notification.
    var notificationSound: UNNotificationSound {
        guard let resourceName else { return .default }
        
        // iOS notification sounds need to reference the file within the app bundle.
        // The sound file must be in CAF, aiff, or wav format with specific requirements.
        // Since the files are at the bundle root (not in a subdirectory), we just use the filename.
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(resourceName).caf"))
    }
}
