import Foundation


public extension String {
	
	/// Representation of the localizable string with no localization applied.
	init(unlocalized resource: LocalizedStringResource) {
		self = String(localized: resource.defaultValue, table: "non-existing")
	}
}

public extension Progress {
	
	/// The `LocalizedStringResource` used to generate the `localizedDescription`.
	var localizable: LocalizedStringResource {
		get {
			let unknown = LocalizedStringResource("unknown operation")
			return userInfo[.localizationKey] as? LocalizedStringResource ?? unknown
		}
		set {
			setUserInfoObject(newValue, forKey: .localizationKey)
		}
	}
}

private extension ProgressUserInfoKey {
	static let localizationKey = Self("LocalizedStringResourceKey")
}
