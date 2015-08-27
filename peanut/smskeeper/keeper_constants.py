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
STATE_TUTORIAL_MEDICAL = 'tutorial-medical'
STATE_TUTORIAL_STUDENT = 'tutorial-student'
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
STATE_JOKE_SENT = 'joke-sent'
STATE_SURVEY_SENT = 'survey-sent'

ALL_STATES = [
	STATE_NORMAL,
	STATE_HELP,
	STATE_NOT_ACTIVATED,
	STATE_TUTORIAL_LIST,
	STATE_TUTORIAL_REMIND,
	STATE_TUTORIAL_TODO,
	STATE_TUTORIAL_STUDENT,
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
	STATE_TUTORIAL_MEDICAL,
	STATE_JOKE_SENT,
	STATE_SURVEY_SENT,
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

# LAST_SENT_ENTRIES_IDS_KEY = "lastSentEntryIds"
# LAST_EDITED_ENTRY_ID_KEY = "lastEditedEntryId"
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

INTRO_MESSAGES_MEDICAL = [
	u"\U0001F44B Hi, I'm Keeper! I'm here to make sure you remember to take your medicine.",
	"Let's start your 7-day free trial. You can send CANCEL to cancel anytime.",
	"Let me show you how I can help you. First, what's your name?"
]


UNKNOWN_COMMAND_PHRASES = [
	u"ZZZZ \U0001F62A....so tired. Talk more in the morning! \U0001F60C",
	u"So sleepy. Let's play the silent game... with eyes closed \U0001F606",
	u"\U0001F4A4 I'll be much more responsive in the morning",
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
SHARE_UPSELL_WEBLINK = 'weblink'  # send weblink
SHARE_UPSELL_PHONE = 'phone'  # send phone number

# second parameter is whether to send out a website link or phone number
SHARE_UPSELL_PHRASES = [
	[u"Btw, I'm great for anyone who forgets things \U0001F433. Know anyone who could use my help? Send them to", SHARE_UPSELL_WEBLINK],
	[u"Think any of your friends would want to try me? I like making new friends \U0001F38E. Send them to", SHARE_UPSELL_WEBLINK],
	[u"Is there anyone you know who can use a little more sanity \U0001F0CF in their life? Just send them to \U00002615", SHARE_UPSELL_WEBLINK],
	[u"And if you have anyone else who needs help, just ask them to say 'hello' to me at", SHARE_UPSELL_PHONE],
]

FEEDBACK_FREQUENCY_DAYS = 45
FEEDBACK_PHRASE = u"Btw, Would you be ok if one of my minions \U0001F638 contacted you to get more info on your experience with me?"
FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS = 3

SMSKEEPER_TEST_NUM = "test"
SMSKEEPER_CLI_NUM = "cli"
SMSKEEPER_WEB_NUM = "web"

REMINDER_PRODUCT_ID = 0
TODO_PRODUCT_ID = 1
WHATSAPP_TODO_PRODUCT_ID = 2
MEDICAL_PRODUCT_ID = 3
STUDENT_PRODUCT_ID = 4


def isAdminInterface(keeperNumber):
	return "web" in keeperNumber


def isRealKeeperNumber(keeperNumber):
	if keeperNumber is None:
		return False

	return keeperNumber != SMSKEEPER_CLI_NUM and "test" not in keeperNumber and "web" not in keeperNumber


def isTestKeeperNumber(keeperNumber):
	return "test" in SMSKEEPER_TEST_NUM

DIGEST_STATE_DEFAULT = "default"
DIGEST_STATE_LIMITED = "limited"

REMINDER_DIGEST_HEADERS = [
	u":sunrise: G'morning sunshine",
	u"Tuesday, it is \U000026F2",
	u"Wednesday is here already!",
	u"How did Thursday sneak up on us? :cat:",
	u"Friday funday! :party_popper:",
	u"It's sit-around-day \U0001F344",
	u"Sunday Sunday Sunday! \U0001F366"
]

REMINDER_DIGEST_DONE_INSTRUCTIONS = ":white_check_mark: To check a task off, tell me what you're done with, like 'Done with calling Mom'"


REMINDER_DIGEST_SNOOZE_INSTRUCTIONS = ":sleeping_symbol: To snooze a task, just tell me when I should remind you, like 'Snooze buy flip flops to Saturday'"

REMINDER_DIGEST_EMPTY = [
	u"Start the week off right. Tell me what you need to get done this week! \U0001F60E",
	u"No tasks today. I know it's hard to believe, but I'm really good at helping you get stuff done \U0001F4AD",
	u"A day with nothing to do is the best. Unless you forgot your Mom's birthday. Don't be that kid \U0001F60E",
	# TODO replace this after digests go out tomorrow
	u"I can text other people reminders for you, just say something like:\nRemind Eric to pick up pizza at 6pm :pizza:",
	# u"Empty day. Surely, there is something you need me to track? \U0001F62E",
	u"No tasks for today. Then, again Fridays should be free days. \U0001F61B",
	u"It might be the weekend but we still gotta keep moving. What can I do? \U0001F60E",
	u"Last day of the week to get stuff done! \U0001F636"
]

HELP_MESSAGES = [
	u":raising_hand: Hi! I'm an automated digital assistant here to help you get things done.",
	u"Send me what you need to get done (and when) and I'll txt you back at the right time.",
	u"Like 'Pay rent on the 1st' or 'Wish Dad happy birthday on Tuesday'",
	REMINDER_DIGEST_DONE_INSTRUCTIONS,
	REMINDER_DIGEST_SNOOZE_INSTRUCTIONS
]

HELP_MESSAGES_OLD = [
	u'There are a few things I can help you with. \U0001F4AA' + "\n" +
	u"I can remember lists \U0001F4DD of things for you, and I can send you reminders at a specific time \u23F0",
	u"What would you like to learn more about? Lists or reminders?"
]

KEEPER_PROD_PHONE_NUMBERS = ["+14792026561", "+14792086270", "3584573970819@s.whatsapp.net", "+19284851665", "+16462332164"]

WHATSAPP_NUMBER_SUFFIX = "@s.whatsapp.net"
WHATSAPP_LOCAL_PROXY_PORT = 8081
DELAY_SECONDS_PER_WORD = 0.2
MIN_DELAY_SECONDS = 1

CLASS_CREATE_TODO = "createtodo"
CLASS_COMPLETE_TODO_MOST_RECENT = "completetodo-most-recent"
CLASS_COMPLETE_TODO_SPECIFIC = "completetodo-specific"
CLASS_DELETE = "deletereminder"
CLASS_FETCH_DIGEST = "fetchdigest"
CLASS_NICETY = "nicety"
CLASS_SILENT_NICETY = "silentnicety"
# TODO(Derek): Move this over to snooze
CLASS_CORRECTION = "timecorrection"
CLASS_CHANGETIME_SPECIFIC = "changetime-specific"
CLASS_CHANGETIME_MOST_RECENT = "changetime-most-recent"
CLASS_HELP = "help"
CLASS_STOP = "stop"
CLASS_FETCH_WEATHER = "fetchweather"
CLASS_NONE = "nocategory"
CLASS_CHANGE_SETTING = "changesetting"
CLASS_QUESTION = "question"
CLASS_FRUSTRATION = "frustration"
CLASS_TIP_QUESTION_RESPONSE = "tip-question-response"
CLASS_JOKE = "joke"
CLASS_SHARED_REMINDER_RECIPIENT_UPSELL = 'shared-reminder-recipient-upsell'
CLASS_RESOLVE_HANDLE = "resolve-handle"
CLASS_UNKNOWN = "unknown"


CLASS_MENU_OPTIONS = ([
	{
		"text": "Create Todo",
		"value": CLASS_CREATE_TODO
	},
	{
		"text": "Done (most recent)",
		"value": CLASS_COMPLETE_TODO_MOST_RECENT
	},
	{
		"text": "Done (specific)",
		"value": CLASS_COMPLETE_TODO_SPECIFIC
	},
	{
		"text": "Delete/Cancel",
		"value": CLASS_DELETE
	},
	{
		"text": "Fetch Digest",
		"value": CLASS_FETCH_DIGEST
	},
	{
		"text": "Nicety",
		"value": CLASS_NICETY
	},
	{
		"text": "Nicety (Silent)",
		"value": CLASS_SILENT_NICETY
	},
	{
		"text": "Change time (most recent)",
		"value": CLASS_CHANGETIME_MOST_RECENT
	},
	{
		"text": "Change time (specific)",
		"value": CLASS_CHANGETIME_SPECIFIC
	},
	{
		"text": "Help",
		"value": CLASS_HELP
	},
	{
		"text": "Stop",
		"value": CLASS_STOP
	},
	{
		"text": "Get weather",
		"value": CLASS_FETCH_WEATHER
	},
	{
		"text": "Change Setting",
		"value": CLASS_CHANGE_SETTING
	},
	{
		"text": "Question",
		"value": CLASS_QUESTION
	},
	{
		"text": "Frustration",
		"value": CLASS_FRUSTRATION
	},
	{
		"text": "Tip question response",
		"value": CLASS_TIP_QUESTION_RESPONSE
	},
	{
		"text": "Joke request",
		"value": CLASS_JOKE
	},
	{
		"text": "Shared reminder recipient upsell",
		"value": CLASS_SHARED_REMINDER_RECIPIENT_UPSELL
	},
	{
		"text": "Resolve Handle",
		"value": CLASS_RESOLVE_HANDLE
	},
	{
		"text": "NoCategory",
		"value": CLASS_NONE
	},
])

OUTGOING_DIGEST = "digest"
OUTGOING_SURVEY = "survey"
OUTGOING_REMINDER = "reminder"
OUTGOING_JOKE = "joke"
OUTGOING_CHANGE_DIGEST_TIME = "change-digest-time"
OUTGOING_RESOLVE_HANDLE = "outgoing-resolve-handle"

RECUR_DEFAULT = "default"
RECUR_ONE_TIME = "one-time"
RECUR_WEEKLY = "weekly"
RECUR_WEEKDAYS = "weekdays"
RECUR_DAILY = "daily"
RECUR_EVERY_2_DAYS = "every-2-days"
RECUR_MONTHLY = "monthly"

RECUR_REGEXES = {
	RECUR_DAILY: r'(every|each) (day|morning|evening|afternoon)|everyday',
	RECUR_WEEKDAYS: r'(every|each) weekday|m[-]f|monday[-]friday|mon[-]fri',
	RECUR_WEEKLY: r'(every|each) (week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)|weekly',
	RECUR_MONTHLY: r'(every|each) month|once a month|monthly'
}

RECURRENCE_CHOICES = [
	RECUR_DEFAULT,
	RECUR_ONE_TIME,
	RECUR_WEEKLY,
	RECUR_WEEKDAYS,
	RECUR_DAILY,
	RECUR_MONTHLY,
	RECUR_EVERY_2_DAYS
]

WHATSAPP_STATUS = u"\U0001F64B Hi, I'm here to help!"

GOAL_DONE_COUNT = 3

SHARED_REMINDER_RECIPIENT_UPSELL = (
	"Btw, I can help you stay organized as well. "
	"Say 'tell me more' for more info on my free personal assistant services. :raising_hand:"
)
SHARED_REMINDER_RECIPIENT_INTRO = "I'm :NAME:'s personal assistant."
SHARED_REMINDER_VERB_WHITELIST_REGEX = r'remind|text|txt|tell'
