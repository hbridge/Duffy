# All user-visible string should go here.

from smskeeper import keeper_constants


######################
# INTRO MESSAGES
######################

# Intro messages for different types of users
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

######################
# MORNING DIGEST
######################

# These is the first line of the digest, one per day of the week.
REMINDER_DIGEST_HEADERS = [
	u":sunrise: G'morning sunshine",
	u"Tuesday, it is \U000026F2",
	u"Wednesday is here already!",
	u"How did Thursday sneak up on us? :cat:",
	u"Friday funday! :party_popper:",
	u"It's sit-around-day \U0001F344",
	u"Sunday Sunday Sunday! \U0001F366"
]

# If there are no tasks, this line is shown. One per day of the week.
REMINDER_DIGEST_EMPTY = [
	u"Start the week off right. Tell me what you need to get done this week! \U0001F60E",
	u"No tasks today. I know it's hard to believe, but I'm really good at helping you get stuff done \U0001F4AD",
	u"A day with nothing to do is the best. Unless you forgot your Mom's birthday. Don't be that kid \U0001F60E",
	u"Empty day. Surely, there is something you need me to track? \U0001F62E",
	u"No tasks for today. Then, again Fridays should be free days. \U0001F61B",
	u"It might be the weekend but we still gotta keep moving. What can I do? \U0001F60E",
	u"Last day of the week to get stuff done! \U0001F636"
]

# Goes out with a digest until a user has checked off three tasks
REMINDER_DIGEST_DONE_INSTRUCTIONS = ":white_check_mark: To check a task off, tell me what you're done with, like 'Done with calling Mom'"

# Goes out with a digest if a user has had a task for many days
REMINDER_DIGEST_SNOOZE_INSTRUCTIONS = ":sleeping_symbol: To snooze a task, just tell me when I should remind you, like 'Snooze buy flip flops to Saturday'"


#########################
# REMINDER MESSAGES
#########################

# Prefixes when reminders go out. Ex: "Hi there: Wanted to remind you: take out trash"
REMINDER_PHRASES = [
	u"Reminder for you:",
	u"Reminder:",
	u"Hi there! Wanted to remind you: ",
	u"Hello. Friendly reminder: ",
	u"Hi! You wanted me to remind you:",
	u"Hi! Don't forget:",
]

# When you set a reminder, we ask you if you prefer another time.
FOLLOWUP_TIME_TEXT = "If there's a better time, just tell me."

# When someone gets a shared reminder, we send this out as a teaser
SHARED_REMINDER_RECIPIENT_UPSELL = (
	"Btw, I can help you stay organized as well. "
	"Say 'tell me more' for more info on my free personal assistant services. :raising_hand:"
)

# Our intro to someone who gets a shared reminder
SHARED_REMINDER_RECIPIENT_INTRO = "I'm :NAME:'s personal assistant."

# Used with shared reminders
FOLLOWUP_SHARE_RESOLVED_TEXT = ":information_desk_person: I'll also remind them directly!"
FOLLOWUP_SHARE_UNRESOLVED_TEXT = u":information_desk_person: I can also txt them for you -- just send me their phone number."


#####################
# HELP MESSAGES
#####################

# Shown when someone types help
HELP_MESSAGES = [
	u":raising_hand: Hi! I'm an automated digital assistant to help you remember things.",
	u"Just say what you need to get done and I'll remind you at the right time.",
	u"Like 'Pay rent on the 1st' or 'Wish Dad happy birthday on Tuesday'",
	REMINDER_DIGEST_DONE_INSTRUCTIONS,
]


##################
# ERROR/STOP MESSAGES
##################

# When you say something that we don't understand, we send these back
UNKNOWN_COMMAND_PHRASES = [
	u"Hmmm, I need my minions for that that and they're sleeping. I'll get back to you in the morning :sunrise:",
	u"I'm not sure what you mean :hatching_chick:. I'll ask my minions :smile_cat::smile_cat: to help me out when they wake up.",
	u"Err... Not sure what you mean. Don't worry, my minions :smile_cat::smile_cat: will straighten things out in the morning",
]

# When someone says 'report' to let us know something went wrong
REPORT_ISSUE_CONFIRMATION = "My minions have been notified."

WEATHER_NOT_FOUND = "I'm sorry, I don't know the weather right now"

STOP_RESPONSE = u"I won't txt you anymore \U0001F61E. If you didn't mean to do this, just type 'start'\n\nI hate to see you go. Is there something I can do better? \U0001F423"

#################
# OTHER MESSAGES
#################

# Used for acknowledging when someone gives us a new reminder or changes time
ACKNOWLEDGEMENT_PHRASES = ["Got it.", "Roger that.", "Copy that.", "Sure thing.", u"\U0001F44D", "Noted.", u"\U0001F44C"]

# When someone says "Done" for a task
DONE_PHRASES = ["Nice!", "Sweet!", ":+1:", "Well done!", "Woohoo!"]

# Phrases used to ask the user to share us with other people
# Note, second parameter is whether to send out a website link or phone number
SHARE_UPSELL_PHRASES = [
	[u"Btw, I'm great for anyone who forgets things \U0001F433. Know anyone who could use my help? Send them to", keeper_constants.SHARE_UPSELL_WEBLINK],
	[u"Think any of your friends would want to try me? I like making new friends \U0001F38E. Tell them say 'hi' to me at", keeper_constants.SHARE_UPSELL_PHONE],
	[u"Is there anyone you know who can use a little more sanity \U0001F0CF in their life? Just send them to \U00002615", keeper_constants.SHARE_UPSELL_PHONE],
	[u"And if you have anyone else who needs help, just ask them to say 'hello' to me at", keeper_constants.SHARE_UPSELL_PHONE],
]

# Every now and then we'll ask you whether you want to talk to us directly to give us feedback
FEEDBACK_PHRASE = u"Btw, Would you be ok if one of my minions \U0001F638 contacted you to get more info on your experience with me?"

# Our status when you look at us on Whatsapp
WHATSAPP_STATUS = u"\U0001F64B Hi, I'm here to help!"
