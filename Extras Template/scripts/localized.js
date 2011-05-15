function _(string)
{
	var dictionary = player.pickLanguage(localizedStrings);
	return dictionary[string] ? dictionary[string] : string;
}

const localizedStrings = {
	de: {
		'Inconsistent Versions': 'Interner Versionsfehler',
		'This feature is not supported on Apple TV.': 'Diese Funktion wird auf Apple TV nicht unterstützt.',
		'iTunes Extras': 'iTunes Extras'
	}
};
