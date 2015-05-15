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

PHOTO_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/gif']
PHOTO_LABEL = '#photo'
SCREENSHOT_LABEL = '#screenshot'
ATTACHMENTS_LABEL = '#attachment'
REMIND_LABEL = "#reminders"
GENERIC_ERROR_MESSAGE = u'\U0001F635 something went wrong.  My minions have been notified.'

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

UNKNOWN_COMMAND_PHRASES = [u"Sorry, I'm not sure what you mean \U0001F633\nIf you're trying to add something, try using a hashtag. To notify my minions, type 'report' now."]
REPORT_ISSUE_KEYWORD = "report"
REPORT_ISSUE_CONFIRMATION = "My minions have been notified."
