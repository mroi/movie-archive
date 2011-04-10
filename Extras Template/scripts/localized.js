function _(string)
{
	if (localizedStrings[player.language] && localizedStrings[player.language][string])
		return localizedStrings[player.language][string];
	else
		return string;
}

var localizedStrings = {
	de: {
		'iTunes Extras': 'iTunes Extras',
		'Inconsistent Versions': 'Interner Versionsfehler'
	}
};
