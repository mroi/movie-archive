import Foundation


public extension String {
	
	/// String representation of the localization key with no localization applied.
	init(unlocalized keyAndValue: String.LocalizationValue) {
		self = String(localized: keyAndValue, table: "non-existing")
	}
}

public extension Progress {
	
	/// The `String.LocalizationValue` used to generate the `localizedDescription`.
	var localization: String.LocalizationValue {
		get {
			let unknown = String.LocalizationValue("unknown operation")
			return userInfo[.localizationKey] as? String.LocalizationValue ?? unknown
		}
		set {
			setUserInfoObject(newValue, forKey: .localizationKey)
		}
	}
}

private extension ProgressUserInfoKey {
	static let localizationKey = Self("StringLocalizationKey")
}
