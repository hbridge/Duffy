'''
Tips that will be sent daily to new users.
Tips will be evaluated for sending based on order so new tips should be added to the end.
'''

SMSKEEPER_TIPS = [
	{
		"identifier": "reminders",
		"message": "Hey there, :NAME:. Just an FYI that I can set reminders for you. For example: '#reminder call mom tomorrow at 5pm'"
	},
	{
		"identifier": "photos",
		"message": "Another tip for you :NAME:: send me a photo with a hash tag, and get it back by sending me the same hashtag - just like text!"
	},
	{
		"identifier": "sharing",
		"message": "Hey :NAME:! I can help you keep track of stuff with friends. For example, type: 'Avengers #movie @Bob' to start a list of movies to watch with Bob."
	},
	{
		"identifier": "voice",
		"message": "Hate typing, :NAME:? Text me without without typing a word! On an iPhone, try holding down your home button and saying 'text Keeper speak more type less hashtag resolutions'",
	}
]


def renderTip(tip, name):
	return tip["message"].replace(":NAME:", name)
