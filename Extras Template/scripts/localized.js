function _(string)
{
	var dictionary = player.pickLanguage(localizedStrings);
	return dictionary[string] ? dictionary[string] : string;
}

const localizedStrings = {
	de: {
		'Inconsistent Versions': 'Interner Versionsfehler',
		'iTunes Extras': 'iTunes Extras'
	}
};
