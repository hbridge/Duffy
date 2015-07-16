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
STATE_SUSPENDED = 'suspended'
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
	STATE_SUSPENDED,
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
IMPLICIT_LABEL_STATE_DATA_KEY = "implicitLabel"


LAST_ACTION_KEY = "lastAction"

# IS_SNOOZE_KEY = "isFollowup"
ENTRY_ID_DATA_KEY = "entryId"
ENTRY_IDS_DATA_KEY = "entryIDs"
# FROM_TUTORIAL_KEY = "fromtutorial"
TUTORIAL_STEP_KEY = "todo-tutorial-step"

#LAST_SENT_ENTRIES_IDS_KEY = "lastSentEntryIds"
#LAST_EDITED_ENTRY_ID_KEY = "lastEditedEntryId"
LAST_ENTRIES_IDS_KEY = "lastEntriesIds"

ACKNOWLEDGEMENT_PHRASES = ["Got it.", "Roger that.", "Copy that.", "Sure thing.", u"\U0001F44D", "Noted.", u"\U0001F44C"]

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
PHOTOS_TIP_URL = "https://s3.amazonaws.com/smskeeper/PhotosTip.png"
KEEPER_BIRTHDAY = datetime.date(2015, 4, 29)

SHARE_UPSELL_FREQUENCY_DAYS = 3
SHARE_UPSELL_PHRASE = "If you know anyone else who could use my help, send them to"

FEEDBACK_FREQUENCY_DAYS = 15
FEEDBACK_PHRASE = u"Btw, Would you be ok if one of my minions \U0001F638 contacted you to get more info on your experience with me?"
FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS = 3

SMSKEEPER_TEST_NUM = "test"
SMSKEEPER_CLI_NUM = "cli"
SMSKEEPER_WEB_NUM = "web"

REMINDER_PRODUCT_ID = 0
TODO_PRODUCT_ID = 1
WHATSAPP_TODO_PRODUCT_ID = 2

# This is local time, so 9am
TODO_DIGEST_HOUR = 9
TODO_DIGEST_MINUTE = 0


def isRealKeeperNumber(keeperNumber):
	if keeperNumber is None:
		return False

	return keeperNumber != SMSKEEPER_CLI_NUM and "test" not in keeperNumber


def isTestKeeperNumber(keeperNumber):
	return "test" in SMSKEEPER_TEST_NUM

REMINDER_DIGEST_HEADERS = [
	u":sunrise: Happy Monday!",
	u"Hello, Tuesday! \U000026F2",
	u"Wednesday is here!",
	u"Ohai Thursday! :cat:",
	u"TGIF! :party_popper:",
	u"It's Saturday! \U0001F344",
	u"Sunday funday! \U0001F366"
]

REMINDER_DIGEST_INSTRUCTIONS = (
	":white_check_mark: To check a task off, tell me what you're done with, like 'Done with calling Mom'"
	+ "\n:sleeping_symbol: To snooze a task, just tell me when I should remind you, like 'Snooze buy flip flops to Saturday'"
)

REMINDER_DIGEST_EMPTY = [
	u"No tasks for today. Let's start the week off right by tracking all you have to do! \U0001F60E",
	u"Tasks for today: 0. You must be really efficient! \U0001F4AD",
	u"I got no tasks for ya. Need me to track anything today? \U0001F60E",
	u"A weekday without tasks? Surely, there is something you need me to track? \U0001F62E",
	u"No tasks for today. Then, again Fridays really shouldn't even be a work day. \U0001F61B",
	u"Your task for today: Do nothing! PS: if you really need to do something, I'm here \U0001F60E",
	u"No tasks on a Sunday? I won't tell anyone \U0001F636"
]

HELP_MESSAGES = [
	u":raising_hand: Hi! I'm an automated digital assistant here to help you get things done.",
	u"Send me what you need to get done (and when) and I'll txt you back at the right time.",
	u"Like 'Pay rent on the 1st' or 'Wish Dad happy birthday on Tuesday'",
	REMINDER_DIGEST_INSTRUCTIONS
]

HELP_MESSAGES_OLD = [
	u'There are a few things I can help you with. \U0001F4AA' + "\n" +
	u"I can remember lists \U0001F4DD of things for you, and I can send you reminders at a specific time \u23F0",
	u"What would you like to learn more about? Lists or reminders?"
]

KEEPER_PROD_PHONE_NUMBERS = ["+14792026561", "+14792086270", "3584573970819@s.whatsapp.net"]

WHATSAPP_NUMBER_SUFFIX = "@s.whatsapp.net"
WHATSAPP_LOCAL_PROXY_PORT = 8081
DELAY_SECONDS_PER_WORD = 0.2
MIN_DELAY_SECONDS = 1

CLASS_CREATE_TODO = "createtodo"
CLASS_COMPLETE_TODO_ALL = "completetodo-all"
CLASS_COMPLETE_TODO_SPECIFIC = "completetodo-specific"
CLASS_DELETE = "deletereminder"
CLASS_FETCH_DIGEST = "fetchdigest"
CLASS_NICETY = "nicety"
CLASS_SILENT_NICETY = "silentnicety"
CLASS_CORRECTION = "timecorrection"
CLASS_SNOOZE = "snooze"
CLASS_HELP = "help"
CLASS_STOP = "stop"
CLASS_FETCH_WEATHER = "fetchweather"
CLASS_NONE = "nocategory"
CLASS_CHANGE_SETTING = "changesetting"

RECUR_DEFAULT = "default"
RECUR_ONE_TIME = "one-time"
RECUR_WEEKLY = "weekly"
RECUR_WEEKDAYS = "weekdays"
RECUR_DAILY = "daily"

RECURRENCE_CHOICES = [
	RECUR_DEFAULT,
	RECUR_ONE_TIME,
	RECUR_WEEKLY,
	RECUR_WEEKDAYS,
	RECUR_DAILY
]
