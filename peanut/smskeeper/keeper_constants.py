# -*- coding: utf-8 -*-
import datetime
import re

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
# WHEN YOU ADD A STATE FOR THE *USER*, PUT IT IN THE ALL_STATES LIST BELOW
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

#
# WHEN YOU ADD A REMINDER STATE, PUT IN THE ALL_STATES LIST BELOW
#
REMINDER_STATE_NORMAL = 'normal'
REMINDER_STATE_SWEPT = 'swept'

ALL_REMINDER_STATES = [
	REMINDER_STATE_NORMAL,
	REMINDER_STATE_SWEPT
]

PHOTO_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/gif']
PHOTO_LABEL = '#photo'
SCREENSHOT_LABEL = '#screenshot'
ATTACHMENTS_LABEL = '#attachment'
REMIND_LABEL = "#reminders"

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


REPORT_ISSUE_KEYWORD = "report"
DEFAULT_TIP_FREQUENCY_DAYS = 3

LISTS_HELP_SUBJECT = "lists"
REMINDERS_HELP_SUBJECT = "reminders"

GENERAL_HELP_KEY = "general"
EXAMPLES_HELP_KEY = "examples"

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
KEEPER_STUDENT_VCARD_URL = "https://s3.amazonaws.com/smskeeper/Keeper_student.vcf"
PHOTOS_TIP_URL = "https://s3.amazonaws.com/smskeeper/PhotosTip.png"
KEEPER_BIRTHDAY = datetime.date(2015, 4, 29)

SHARE_UPSELL_FREQUENCY_DAYS = 3
SHARE_UPSELL_MIN_ACTIVATED_DAYS = 1
SHARE_UPSELL_WEBLINK = 'weblink'  # send weblink
SHARE_UPSELL_PHONE = 'phone'  # send phone number

FEEDBACK_FREQUENCY_DAYS = 45
FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS = 3

# Once a task is this old and still on the list, remove it from daily digest and task list
SWEEP_CUTOFF_TIME_FOR_OLD_TASKS_IN_DAYS = 4
SWEEP_CLEANUP_WEEKDAY = 1  # 1 is Monday, 2 is Tuesday, etc.

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
DIGEST_STATE_NEVER = "never"

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
CLASS_SHARE_REMINDER = "share-reminder"
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
		"text": "Share Reminder",
		"value": CLASS_SHARE_REMINDER
	},
	{
		"text": "NoCategory",
		"value": CLASS_NONE
	},
])

ALL_CLASS_OPTIONS = map(lambda option: option["value"], CLASS_MENU_OPTIONS)

OUTGOING_DIGEST = "digest"
OUTGOING_SURVEY = "survey"
OUTGOING_REMINDER = "reminder"
OUTGOING_JOKE = "joke"
OUTGOING_CHANGE_DIGEST_TIME = "change-digest-time"
OUTGOING_SHARE_PROMPT = "outgoing-share-prompt"

TEMP_FORMAT_METRIC = 'metric'
TEMP_FORMAT_IMPERIAL = 'imperial'

RECUR_DEFAULT = "default"
RECUR_ONE_TIME = "one-time"
RECUR_WEEKLY = "weekly"
RECUR_WEEKDAYS = "weekdays"
RECUR_DAILY = "daily"
RECUR_EVERY_2_DAYS = "every-2-days"
RECUR_EVERY_2_WEEKS = "every-2-weeks"
RECUR_MONTHLY = "monthly"

RECUR_REGEXES = {
	RECUR_DAILY: r'(every|each) (day|morning|evening|afternoon)|everyday|daily',
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
	RECUR_EVERY_2_DAYS,
	RECUR_EVERY_2_WEEKS
]

GOAL_DONE_COUNT = 3


SHARED_REMINDER_VERB_WHITELIST_REGEX = r'remind|text|txt|tell'

UNKNOWN_TYPE_ZERO_SCORE = "zeros"
UNKNOWN_TYPE_CHANGETIME = "changetime"
UNKNOWN_TYPE_DONE = "done"
UNKNOWN_TYPE_FRUSTRATION = "frustration"
UNKNOWN_TYPE_QUESTION = "question"


FOLLOWUP_TIME = "time"
FOLLOWUP_SHARE_RESOLVED = "share-resolved"
FOLLOWUP_SHARE_UNRESOLVED = "share-unresolved"

RELATIONSHIP_RE = re.compile(r'(mom|dad|wife|husband|boyfriend|girlfriend|spouse|partner|mother|father)', re.I)
