COMMAND_PICK = 0
COMMAND_CLEAR = 1
COMMAND_FETCH = 2
COMMAND_ADD = 3
COMMAND_REMIND = 4
COMMAND_DELETE = 5
COMMAND_ACTIVATE = 6
COMMAND_LIST = 7
COMMAND_HELP = 8

STATE_NOT_ACTIVATED = 'not-activated'
STATE_TUTORIAL_LIST = 'tutorial'
STATE_TUTORIAL_REMIND = 'tutorial-remind'
STATE_NORMAL = 'normal'
STATE_REMIND = 'remind'
STATE_DELETE = 'delete'
STATE_ADD = 'add'
STATE_UNRESOLVED_HANDLES = 'unresolved-handles'
STATE_UNKNOWN_COMMAND = 'unknown-command'
STATE_PAUSED = 'paused'

PHOTO_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/gif']
PHOTO_LABEL = '#photo'
SCREENSHOT_LABEL = '#screenshot'
ATTACHMENTS_LABEL = '#attachment'
REMIND_LABEL = "#reminders"
GENERIC_ERROR_MESSAGES = [
	u'\U0001F635 something went wrong.  My minions have been notified.',
	u"Well \U0001F4A9 something happened.  Someone'll be along to clean up shortly.",
]

UNRESOLVED_HANDLES_DATA_KEY = "unresolvedHandles"
ENTRY_IDS_DATA_KEY = "entryIDs"

ACKNOWLEDGEMENT_PHRASES = ["Got it.", "Roger.", "Copy that.", "Sure thing.", u"\U0001F44D", "Noted.", u"\U0001F44C"]

FIRST_INTRO_MESSAGE_NO_MAGIC = "Oh hello. I'm ready for you."
FIRST_INTRO_MESSAGE_MAGIC = "Ah. You used the magic phrase. Smooth."

INTRO_MESSAGES = [
	"I'm Keeper and I can help you remember small things that are easy to forget.",
	"Instead of writing them down somewhere (or forgetting to), just txt me.",
	"I'll show you how I work. First, what's your name?"
]

UNKNOWN_COMMAND_PHRASES = [
	u"Sorry, I'm not sure what you mean \U0001F633\nIf you're trying to add something, try using a hashtag. To notify my minions, type 'report' now.",
	u"I'm still pretty new \U0001F423 and I don't understand that.\n\n Say 'huh?' to see what I can do or 'report' and I'll poke one of my lackeys. \U0001F449",
	u"Do you have a map?  'Cause I'm lost. \U0001F615 Say 'huh?' for instructions or 'report' to notify the stooges."
]
REPORT_ISSUE_KEYWORD = "report"
REPORT_ISSUE_CONFIRMATION = "My minions have been notified."
DEFAULT_TIP_FREQUENCY_DAYS = 3

TELL_ME_MORE = "I can help you remember lists of things. Send me anything like 'add Jurassic Park to my movies list' or 'add pasta, sauce, cheese to shopping'."

HELP_MESSAGES = [
	u'There are a few things I can help you with. \U0001F4AA',
	u"\U0001F4DD You can tell me to remember lists\nFor example 'add martini to my cocktails list'",
	u"\U0001F514 You can tell me to remind you of something at a specific time\nFor example 'Remind me to call Mom tonight'",
]

SLACK_CHANNEL_FEED = "#livesmskeeperfeed"
SLACK_CHANNEL_MANUAL_ALERTS = "#manual-alerts"
