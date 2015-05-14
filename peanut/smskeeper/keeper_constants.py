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

UNASSIGNED_LABEL = '#unassigned'
REMIND_LABEL = "#reminders"
GENERIC_ERROR_MESSAGE = '\xF0\x9F\x98\xB2 something went wrong.  My minions have been notified.'

UNRESOLVED_HANDLES_DATA_KEY = "unresolvedHandles"
ENTRY_IDS_DATA_KEY = "entryIDs"

ACKNOWLEDGEMENT_PHRASES = ["Got it.", "Roger." "Copy that.", "Sure thing.", u"\U0001F44D", "Noted.", u"\U0001F44C"]

INTRO_MESSAGES = [
	"I'm Keeper and I can help you remember those small things like a shopping list, movies to watch, or wines you liked.",
	"Instead of writing them down somewhere (or forgetting to), just txt me.",
	"I'll show you how I work. First, what's your name?"
]
