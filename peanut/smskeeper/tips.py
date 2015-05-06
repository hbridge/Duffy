'''
Tips that will be sent daily to new users.
Tips will be evaluated for sending based on order so new tips should be added to the end.
'''

SMSKEEPER_TIPS = [
	{
		"identifier": "reminders",
		"messages": [
			"FYI, did you know that I can help you set reminders?",
			"For example: '#reminder call mom tomorrow at 5pm' or '#reminder pickup wine tomorrow'"
		]
	},
	{
		"identifier": "photos",
		"messages": [
			"Did you know that you can send me photos too?",
			"Send me a photo with a hash tag, and I'll send it back whenever you ask for that hashtag."
		]
	},
	{
		"identifier": "sharing",
		"messages": [
			"Hey there. I'm also great for sharing stuff with friends.",
			"For example, you could type: 'Avengers #movie @tessa' to add to keep track of movies to watch together."
		]
	},
	{
		"identifier": "voice",
		"messages": [
			"Me again with another tip.  You can put stuff in keeper without typing a word!",
			"On an iPhone try saying 'text Keeper speak more type less hashtag resolutions'",
		]
	}
]
