'''
Tips that will be sent daily to new users.
Tips will be evaluated for sending based on order so new tips should be added to the end.
'''

SMSKEEPER_TIPS = [
	{
		"identifier": "reminders",
		"messages": [
			"FYI, did you know that I can also help you set reminders?",
			"For example: '#reminder call mom tomorrow at 5pm' or '#reminder pickup wine tomorrow'"
		]
	},
	{
		"identifier": "photos",
		"messages": [
			"Did you know that you can send me photos too?",
			"Send a photo with a hash tag, and I'll send them back with other items with the same hashtag"
		]
	},
	{
		"identifier": "sharing",
		"messages": [
			"Did you know that you can share items with friends?",
			"For example: 'Avengers #movie @tessa' to share with Tessa"
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
