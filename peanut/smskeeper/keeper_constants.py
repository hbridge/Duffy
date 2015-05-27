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
STATE_IMPLICIT_LABEL = 'implicit-label'
STATE_STOPPED = 'stopped'
STATE_HELP = 'help'

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
IMPLICIT_LABEL_STATE_DATA_KEY = "implicitLabel"


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
	u"\U0001F4DD I can remember lists of things for you.",
	u"\U0001F514 I can send you reminders at a specific time",
	u"What would you like to learn more about? Lists or reminders?"
]

LISTS_HELP_SUBJECT = "lists"
REMINDERS_HELP_SUBJECT = "reminders"

GENERAL_HELP_KEY = "general"
EXAMPLES_HELP_KEY = "examples"

HELP_SUBJECTS = {
	LISTS_HELP_SUBJECT: {
		GENERAL_HELP_KEY: [
			u"Lists \U0001F4DD are great for remembering things you want to keep track of.",
			u"Just say 'add', then the item you want to add, 'to' and the list name.  For example: 'Add spaghetti \U0001f35d to my shopping list'"
		],
		EXAMPLES_HELP_KEY: [
			u"Add Airplane \u2708\ufe0f to my movies list" + "\n" +
			u"Add Japan \U0001f1ef\U0001f1f5, France \U0001f1eb\U0001f1f7 to travel" + "\n" +
			u"Add Di Fara, Motorino, to Pizza Joints \U0001F355, " + "\n" +
			u"Add invitations, party favors, seating chart to wedding \U0001F492"
		],
	},
	REMINDERS_HELP_SUBJECT: {
		GENERAL_HELP_KEY: [
			u"Reminders \U0001F514 are great for keeping track of stuff you need to do later.",
			u"Just say 'remind me' and then what you want to be reminded of.  If you don't include a time \U0001f554, I'll ask you for one.",
			u"For example, you could say 'remind me to call mom \U0001f4f1 this weekend'"
		],
		EXAMPLES_HELP_KEY: [
			u"Remind me to do laundry on Saturday" + "\n" +
			u"Remind me to practice \U0001F3B8 tonight at 8pm" + "\n" +
			u"Remind me to email the team \U0001F4E7 next week" + "\n" +
			u"Remind me to get a gift for Dad \U0001F381"
		]
	},
}

SLACK_CHANNEL_FEED = "#livesmskeeperfeed"
SLACK_CHANNEL_MANUAL_ALERTS = "#manual-alerts"

COMMON_LIST_RES = [
	"grocer(y|ies)",
	"movies?",
	"books?",
	"wines?",
	"cocktails?",
	"shopping",
	"pharmacy",
	"buy",
	"errands",
	"todo",
	"(to)?read",
]

KEEPER_VCARD_URL = "https://s3.amazonaws.com/smskeeper/Keeper.vcf"

SHARE_UPSELL_FREQUENCY_DAYS = 3
SHARE_UPSELL_PHRASE = "If you know anyone else who could use my help, send them to"
