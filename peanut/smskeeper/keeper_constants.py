import datetime

COMMAND_PICK = 0
COMMAND_CLEAR = 1
COMMAND_FETCH = 2
COMMAND_ADD = 3
COMMAND_REMIND = 4
COMMAND_DELETE = 5
COMMAND_ACTIVATE = 6
COMMAND_LIST = 7
COMMAND_HELP = 8

#
# WHEN YOU ADD A STATE, PUT IT IN THE ALL_STATES LIST BELOW
#
STATE_NOT_ACTIVATED = 'not-activated'
STATE_NOT_ACTIVATED_FROM_REMINDER = 'not-activated-from-reminder'
STATE_TUTORIAL_LIST = 'tutorial-list'
STATE_TUTORIAL_REMIND = 'tutorial-remind'
STATE_TUTORIAL_TODO = 'tutorial-todo'
STATE_NORMAL = 'normal'
STATE_REMIND = 'remind'
STATE_REMINDER_SENT = 'reminder-sent'
STATE_DELETE = 'delete'
STATE_ADD = 'add'
STATE_UNRESOLVED_HANDLES = 'unresolved-handles'
STATE_UNKNOWN_COMMAND = 'unknown-command'
STATE_IMPLICIT_LABEL = 'implicit-label'
STATE_STOPPED = 'stopped'
STATE_HELP = 'help'

ALL_STATES = [
	STATE_NORMAL,
	STATE_HELP,
	STATE_NOT_ACTIVATED,
	STATE_TUTORIAL_LIST,
	STATE_TUTORIAL_REMIND,
	STATE_TUTORIAL_TODO,
	STATE_REMIND,
	STATE_REMINDER_SENT,
	STATE_DELETE,
	STATE_ADD,
	STATE_IMPLICIT_LABEL,
	STATE_UNRESOLVED_HANDLES,
	STATE_UNKNOWN_COMMAND,
	STATE_STOPPED,
	STATE_NOT_ACTIVATED_FROM_REMINDER,
]

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
RESOLVED_HANDLES_DATA_KEY = "resolvedHandles"
FROM_UNRESOLVED_HANDLES_DATA_KEY = "fromUnresolvedHandles"
ENTRY_IDS_DATA_KEY = "entryIDs"
IMPLICIT_LABEL_STATE_DATA_KEY = "implicitLabel"

ENTRY_ID_DATA_KEY = "entryId"
FROM_TUTORIAL_KEY = "fromtutorial"

ACKNOWLEDGEMENT_PHRASES = ["Got it.", "Roger.", "Copy that.", "Sure thing.", u"\U0001F44D", "Noted.", u"\U0001F44C"]

FIRST_INTRO_MESSAGE_NO_MAGIC = "Oh hello. I'm ready for you."
FIRST_INTRO_MESSAGE_MAGIC = "Ah. You used the magic phrase. Smooth."

INTRO_MESSAGES = [
	u"\U0001F44B Hi, I'm Keeper! I'm here to help you remember small things that are easy to forget.",
	"Let me show you how I can help you. First, what's your name?"
]

INTRO_MESSAGES_PAID = [
	u"\U0001F44B Hi, I'm Keeper! I'm here to help you remember small things that are easy to forget.",
	"Let's start your 7-day free trial. You can send CANCEL to cancel anytime.",
	"Let me show you how I can help you. First, what's your name?"
]

UNKNOWN_COMMAND_PHRASES = [
	u"Sorry, I'm not sure what you mean \U0001F633\nType HELP for help. To notify my minions, say REPORT",
	u"I'm still pretty new \U0001F423 and I don't understand that.\n\n Say HELP to see what I can do or REPORT and I'll poke one of my lackeys. \U0001F449",
	u"I hope you have a map, 'cause I'm lost. \U0001F615 Say HELP for instructions or REPORT to notify the stooges."
]
REPORT_ISSUE_KEYWORD = "report"
REPORT_ISSUE_CONFIRMATION = "My minions have been notified."
DEFAULT_TIP_FREQUENCY_DAYS = 3

TELL_ME_MORE = "I can help you remember lists of things. Send me anything like 'add Jurassic Park to my movies list' or 'add pasta, sauce, cheese to shopping'."

HELP_MESSAGES = [
	u'There are a few things I can help you with. \U0001F4AA' + "\n" +
	u"I can remember lists \U0001F4DD of things for you, and I can send you reminders at a specific time \u23F0",
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
			u"Just say 'add' with an item and a list. For example: 'Add pay rent to my todo list'"
		],
		EXAMPLES_HELP_KEY: [
			u"Add Airplane \u2708\ufe0f to my movies list" + "\n" +
			u"Add Tokyo \U0001f1ef\U0001f1f5, Paris \U0001f1eb\U0001f1f7 to travel" + "\n" +
			u"Add Di Fara, Motorino to Pizza Joints \U0001F355" + "\n" +
			u"Add invitations, party favors, seating chart to wedding \U0001F492"
		],
	},
	REMINDERS_HELP_SUBJECT: {
		GENERAL_HELP_KEY: [
			u"Reminders \u23F0 are great for keeping track of stuff you need to do later.",
			u"Just say 'remind me' and then what you want to be reminded of.  If you don't include a time \U0001f554, I'll ask you for one." + "\n" +
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
KEEPER_TODO_VCARD_URL = "https://s3.amazonaws.com/smskeeper/Keeper_todo.vcf"
PHOTOS_TIP_URL="https://s3.amazonaws.com/smskeeper/PhotosTip.png"
KEEPER_BIRTHDAY = datetime.date(2015, 4, 29)

SHARE_UPSELL_FREQUENCY_DAYS = 3
SHARE_UPSELL_PHRASE = "If you know anyone else who could use my help, send them to"

FEEDBACK_FREQUENCY_DAYS = 15
FEEDBACK_PHRASE = u"Any tips for me on how I can help you more? \U0001F423 getkeeper.com/feedback.php"
FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS = 3

SMSKEEPER_TEST_NUM = "test"
SMSKEEPER_CLI_NUM = "cli"
SMSKEEPER_WEB_NUM = "web"

REMINDER_PRODUCT_ID = 0
TODO_PRODUCT_ID = 1

# This is local time, so 9am
TODO_DIGEST_HOUR = 9
TODO_DIGEST_MINUTE = 0

def isRealKeeperNumber(keeperNumber):
	return keeperNumber != SMSKEEPER_CLI_NUM and keeperNumber != SMSKEEPER_TEST_NUM


def isTestKeeperNumber(keeperNumber):
	return keeperNumber == SMSKEEPER_TEST_NUM

