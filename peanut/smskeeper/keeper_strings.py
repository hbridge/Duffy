
# All user-visible string should go here.

from smskeeper import keeper_constants


######################
# INTRO/TUTORIAL MESSAGES
######################

# Intro messages for different types of users
INTRO_MESSAGES = [
	[
		u"\U0001F44B Hi, I'm Keeper! I'm here to help you remember small things that are easy to forget.",
		u"Hi, I'm Keeper :wave:! I'm here to help you remember anything and everything.",
		u"Hey, I'm Keeper! I can help you remember things any time."
	],
	[
		u"Let me show you how I can help you. First, what's your name?",
		u"First thing's first, what's your name?",
	],
]

# specifically for the medical use case that never went anywhere. Pls ignore
INTRO_MESSAGES_MEDICAL = [
	u"\U0001F44B Hi, I'm Keeper! I'm here to make sure you remember to take your medicine.",
	"Let's start your 7-day free trial. You can send CANCEL to cancel anytime.",
	"Let me show you how I can help you. First, what's your name?"
]

ASK_AGAIN_FOR_NAME = [
	u"We'll get to that, but first what's your name?",
	u"Whoa, whoa, slow down. What's your name first?"
]
GOT_NAME_RESPONSE = [
	u"Great, nice to meet you %s! \U0001F44B",
	u"Thanks, %s! Awesome to meet you. :wave:",
	u"Thanks! I'm sure we'll be great friends, %s!",
]


ASK_FOR_ZIPCODE_TEXT = u"What's your zipcode? It'll help me remind you of things at the right time \U0001F553"
ASK_FOR_POSTAL_CODE_TEXT = u"What's your postal/zip code? It'll help me remind you of things at the right time \U0001F553"  # used for non-US phone numbers

ZIPCODE_NOT_VALID_TEXT = [
	u"Sorry, I don't know that zipcode. Could you check that?",
	u"Hmm, that doesn't sound familiar. Mind sending your zip again?"
]

ASK_AGAIN_FOR_ZIPCODE_TEXT = "Got it, but first thing, what's your zipcode?"

# When a user sets their *first* reminder and don't give us time, we ask them to clarify
ASK_FOR_TIME_TEXT = [
	u"Great, and when would you like to be reminded?",
	u"Perfect, what time would you like to be reminded?",
	u"Cool, what time should I remind you?",
	u"Noted! What time would you like to be reminded?"
]

# Immediately follows one of the above lines
TUTORIAL_ADD_FIRST_REMINDER_TEXT = [
	u":thumbsup: What's an item on your todo list right now? You can say things like 'Buy flip flops tomorrow' or 'Pick up Susie at 2:30 Friday' and I'll remind you.",
]

# Student-only tutorial: Immediately follows one of the above lines in TUTORIAL_POST_NAME_AND_ZIPCODE_TEXT
TUTORIAL_STUDENT_ADD_FIRST_REMINDER_TEXT = [
	u":thumbsup: What's an item on your todo list right now? You can say things like 'Pay club dues on Friday' or 'Meet with advisor on Monday at 4pm' and I'll remind you.",
	u":thumbsup: What's on your todo list right now? Things like 'finish homework by 4pm' or 'walk the dog tonight' are some examples.",
]

TUTORIAL_DONE_TEXT = u"It's that easy. Just txt me when things pop in your head and I'll track them for you. \U0001F60E What else do you need to do?"

TUTORIAL_VCARD_AND_MORNING_DIGEST_TEXT = [
	u"Oh and here's my card. Tap it to save me to your address book. I'll also send you your tasks in the morning \U0001F304 with that day's weather \U0001F31E",
	u"BTW, here's my info. Tap it to save me to your address book :ok_hand:",
]
TUTORIAL_MORNING_DIGEST_ONLY_TEXT = u"I'll also send you a morning txt \U0001F304 with with weather forecast \U0001F31E and daily tasks."  # used for whatsapp users



######################
# MORNING DIGEST
######################

# These is the first line of the digest, one per day of the week.
REMINDER_DIGEST_HEADERS = [
	[  # copy for Monday
		u":sunrise: G'morning sunshine",
		u"Rise 'n grind, Monday is here :sunny:",
		u"Good morning!",
		u"Morning, :NAME:! :coffee:",
		u"Monday got me like: :sleeping:",
		u"How is it already Monday again? :ghost:",
	],
	[  # copy for Tuesday
		u"Tuesday, it is \U000026F2",
		u"Happy Tuesday, :NAME:!",
		u":see_no_evil: Morning! :hear_no_evil:"
	],
	[  # copy for Wednesday
		u"Wednesday is here already!",
		u"How is it already Wednesday? :eyes:",
		u"Happy hump day",
		u"It's a brand new day! :sunny:",
		u"Mornin'! :dog:",
	],
	[  # copy for Thursday
		u"How did Thursday sneak up on us? :cat:",
		u"Happy Thursday :sunglasses:",
		u"How is it already Thursday? :eyes:",
		u"Happy Thursday, :NAME:! :punch:",
		u"Good morning :innocent:",
	],
	[  # copy for Friday
		u"Friday funday! :party_popper:",
		u"TGIF :tada:",
		u"Shout out to Friday :raised_hands:",
		u"Ahh, Friday. :ok_hand:",
	],
	[  # copy for Saturday
		u"It's sit-around-day \U0001F344",
		u":wavy_dash:Saturday vibes:wavy_dash:",
		u"Ahh, Saturday... The best day of the week.",
		u"So much yes to Saturday :open_hands:",
	],
	[  # copy for Sunday
		u"Sunday Sunday Sunday! \U0001F366",
		u"Sunday funday! :raised_hands:",
		u"Good morning!",
		u"Sunday is for :zzz:",
	],
]

# if there are tasks, begin with this header

DIGEST_HEADER_TODAY = u"Your tasks for today: \U0001F4DD"
DIGEST_HEADER_USER_REQUESTED = u"Your current tasks: \U0001F4DD"  # this means user asked for all tasks

# If there are no tasks, this line is shown. One per day of the week.
REMINDER_DIGEST_EMPTY = [
	[  # Monday
		u"Start the week off right. Tell me what you need to get done! \U0001F60E",
		u"Anything on your todo list for Monday? :pencil:",
	],
	[  # Tuesday
		u"No tasks today. I know it's hard to believe, but I'm really good at helping you get stuff done \U0001F4AD",
	],
	[  # Wednesday
		u"A day with nothing to do is the best. Unless you forgot your Mom's birthday. Don't be that kid \U0001F60E",
		u"No tasks today, but I'm sure you can think of something for me to help you with.",
	],
	[  # Thursday
		u"Empty day. Surely, there's something you need me help with? \U0001F62E",
		u"Don't forget to get stuff done before the weekend!",
	],
	[  # Friday
		u"No tasks for today. Then again, Fridays should be free days. \U0001F61B",
		u"Dang, Friday really is your funday. No tasks!",
	],
	[  # Saturday
		u"It might be the weekend but the hustle never sleeps. What can I do? \U0001F60E",
		u"What can I help you with? Surely you've got something you're forgetting :smirk:",
	],
	[  # Sunday
		u"Last day of the week to get stuff done! \U0001F636",
		u"Quick, before Monday rolls around. What can I help you get done?",
	],
]

USER_REQUESTED_DIGEST_EMPTY = [
	u"I don't have anything on record :eyeglasses: for you",
	u"Nothing on your list, need to add anything? :ear:",
	u"Your todo list :scroll: is clear right now",
]

# Goes out with a digest until a user has checked off three tasks
REMINDER_DIGEST_DONE_INSTRUCTIONS = ":white_check_mark: To check a task off, tell me what you're done with, like 'Done with calling Mom'"

# Goes out with a digest if a user has had a task for many days
REMINDER_DIGEST_SNOOZE_INSTRUCTIONS = ":sleeping_symbol: To snooze a task, just tell me when I should remind you, like 'Snooze buy flip flops to Saturday'"

CONFIRM_MORNING_DIGEST_LIMITED_STATE_TEXT = "Got it, I won't send you a morning txt when there are no tasks"

CHANGE_MORNING_DIGEST_TIME_TEXT = "Great, I'll send you a daily summary at %s for now on"

# When we move the old tasks off your daily list
SWEEP_MESSAGE_TEXT = "Btw, I moved these old tasks to %s to keep your list fresh:\n"

# when people manually request their tasks, we add this to the bottom to tell them how they can manage on the web
FETCH_DIGEST_FOOTER = "\nYou can also see and manage your tasks at %s"


#########################
# REMINDER MESSAGES
#########################

# Prefixes when a reminder goes out. Note these have to singular Ex: "Hi there: Wanted to remind you: take out trash"
REMINDER_PHRASES = [
	u"Reminder for you:",
	u"Reminder:",
	u"Hi there! Wanted to remind you:",
	u"Hello. Friendly reminder:",
	u"Hi! Don't forget:",
	u":NAME:, reminder for you:",
	u"Quick thing!",
]

# When you set a reminder, we ask you if you prefer another time.
FOLLOWUP_TIME_TEXT = [
	u"If there's a better time, just tell me.",
	u"Need this reminder at another time? Just let me know.",
	u"If there's a better time to remind you, just let me know.",
]

# Used when you say "Done with mom" and we can't tell which entry you mean
ENTRY_NOT_FOUND_TEXT = [
	u"Sorry, I'm not sure what entry you mean. Could you rephrase?"
	u"Didn't catch that, mind rephrasing?"
]



#########################
# SHARED REMINDERS
#########################

# When someone gets a shared reminder, we send this out as a teaser
SHARED_REMINDER_RECIPIENT_UPSELL = (
	"I can help you stay organized as well :innocent:. "
	"Say 'tell me more' for more info on my free personal assistant services. :raising_hand:"
)

# Our intro to someone who gets a shared reminder
SHARED_REMINDER_RECIPIENT_INTRO = "I'm :NAME:'s personal assistant."

# Used with shared reminders
FOLLOWUP_SHARE_RESOLVED_TEXT = ":information_desk_person: I'll also remind them directly!"
FOLLOWUP_SHARE_UNRESOLVED_TEXT = u":information_desk_person: I can also txt them for you -- just send me their phone number."

SHARED_REMINDER_SENT_CONFIRMATION_TEXT = "Hi there :wave: Just letting you know that I sent %s a reminder for you."
SHARED_REMINDER_TEXT_TO_UNACTIVATED_USER = "Hi :wave: I'm %s's digital assistant. %s wanted me to remind you: %s"
SHARED_REMINDER_TEXT_TO_ACTIVATED_USER = "Hi! Friendly reminder from %s: %s"



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



#############################
# ERROR/STOP/START MESSAGES
############################

# When you say something that we don't understand, we send these back
UNKNOWN_COMMAND_PHRASES = [
	u"Mmm...say again?",
	u"Hmmm...I'm not sure what you mean :hatching_chick:.",
	u"Err... Not sure what you mean.",
	u"Not sure what that means :grimacing:",
	u"Mind saying that again? I didn't get it :pensive:",
]

# When someone says 'report' to let us know something went wrong
REPORT_ISSUE_CONFIRMATION = "My minions have been notified."

WEATHER_NOT_FOUND = "I'm sorry, I don't know the weather right now"

STOP_RESPONSE = u"I won't txt you anymore \U0001F61E. If you didn't mean to do this, just type 'start'\n\nI hate to see you go. Is there something I can do better? \U0001F423"

START_RESPONSE = u"\U0001F44B Welcome back!"



###################################
# UPDATE INFORMATION: NAME, ZIPCODE
###################################

NAME_CHANGE_CONFIRMATION_TEXT = "Great, I'll call you %s from now on."
NAME_CHANGE_ERROR_TEXT = "Sorry, I didn't catch that, try saying something like 'My name is Keeper'"
ZIPCODE_CHANGE_ERROR_TEXT = "I'm sorry, I don't know that postal code"



###############
# TIPS
################

# Full tips: these go out every 1, 3, 7 or 30 days, depending on user preference

PILLS_TIP_TEXT = "Pro tip: I can remind you to take your medicine and other frequent tasks. :pill: Just say 'Remind me to take my medicine every day' etc."
WEATHER_TIP_TEXT = "Handy tip for you :NAME:, I can give you weather forecasts for tomorrow and this weekend. :sunny: :cloud: :umbrella: Try saying 'what's the weather tomorrow?'"
BIRTHDAY_TIP_TEXT = "Hey :NAME:, if you've got a friend's birthday :birthday: coming up and don't want to forget, just let me know with 'Julie's birthday is next Sunday'"
JOKE_TIP_TEXT = "Hey :NAME:, I'm the funniest digital assistant around! Just ask me to tell you a joke - guaranteed laughs or you get a pony :sunglasses:"
PAY_BILLS_TIP_TEXT = "Hey :NAME:, I can also track bills for you. :page_with_curl: Just let me know when you need to pay them. Like 'Pay credit card on the 15th of every month' :postbox:"
GROCERY_TIP_TEXT = "Hey :NAME:, Want any help remembering grocery list? You can say 'Buy pasta, cheese and sauce later today' :spaghetti:"
TRASH_TIP_TEXT = "Hey :NAME:, do you have trouble remembering trash day? Just say 'Trash day every Tuesday' and I'll make sure you never forget. :pushpin:"
APPOINTMENT_TIP_TEXT = "Btw, I'm great at reminding you about appointments. Just txt me when you need to go to the doctor, dentist, hair salon, DMV, etc. :mask:"
TICKET_TIP_TEXT = "Want to remember to buy that show's tickets as soon as they go on sale? I can remind you at the exact time. Just txt me :ticket:"
SHARED_REMINDER_TIP1_TEXT = "I can now remind other people on your behalf. Just say 'Remind Anne about lunch tomorrow at 12pm'"
TVSHOW_TIP_TEXT = "Want me to remind you when your favorite show is on TV? Just say 'Remind me to watch Law & Order SVU at 9pm every Wednesday'"
GET_TASKS_TIP_TEXT = "Btw, you can see a list of all your tasks anytime. Just say 'What are my tasks?'"
SHARED_REMINDER_TIP2_TEXT = "I can directly remind your other half for you. Just say 'Remind my boyfriend (or girlfriend) to get groceries tmrw at 7pm'"
WORKOUT_SCHEDULE_TEXT = "Hey :NAME:, having trouble going to the gym? Just let me know when you want to go and I'll remind you. :muscle:"

# Mini tips: these go out at specific instances. Like when a user takes an action

DONE_ALL_MINITIP_TEXT = "Pro tip: You can also say 'Done with everything' to mark all items as done."
DONE_TIP1_MINITIP_TEXT = "Just let me know when you're done and I'll check it off your list"
DONE_TIP2_MINITIP_TEXT = "Let me know when you're done and I'll check it off for you"
DONE_TIP3_MINITIP_TEXT = "Let me know when you're done!"
SNOOZE_MINITIP_TEXT = "Also, you can always snooze a reminder by saying 'snooze for 5 mins' or 'snooze till 9pm'"
DIGEST_QUESTION_MINITIP_TEXT = "btw, how useful do you find these morning txts? 1 (not useful) - 5 (very useful)"
DIGEST_CHANGE_TIME_MINITIP_TEXT = "btw, when do you wake up? I can send this to you earlier or later in the day, just let me know what time is best"
SHARED_REMINDER_MINITIP_TEXT = "FYI - I can remind other people directly for you!"
DIGEST_QUESTION_NPS_MINITIP_TEXT = "Quick q! How likely are you to recommend me to a friend?  1 (not likely) - 10 (extremely likely)"
REFERRAL_ASK_MINITIP_TEXT = "Also, I'm curious, how did you hear about me?"

# This footer is appended only to the full tips
SMSKEEPER_TIP_FOOTER = "Want fewer tips? Type 'send me tips weekly/monthly/never'"

# Tip frequency change confirmation
TIP_STOP_CONFIRMATION_TEXT = "Ok, I'll stop sending you tips."
TIP_DAILY_CONFIRMATION_TEXT = "Ok, I'll send you tips daily."
TIP_WEEKLY_CONFIRMATION_TEXT = "Ok, I'll send you tips weekly."
TIP_MONTHLY_CONFIRMATION_TEXT = "Ok, I'll send you tips monthly."

# if we didn't understand what you said
TIP_FREQUENCY_CHANGE_ERROR_TEXT = "Sorry, I didn't get that. You can type 'send me tips weekly/monthly/never' to change how often I send you tips."



#################
# JOKES
#################

JOKE1 = ["What do you call a boomerang that doesn't come back?", "A stick"]
JOKE2 = ["What do you call two banana peels?", "A pair of slippers"]
JOKE3 = ["How do you make a tissue dance?", "Put a little boogie in it"]
JOKE4 = ["What do you call cheese that's not yours?", "Nacho cheese"]
JOKE5 = ["Why did the belt get locked up?", "It held up a pair of pants"]
JOKE6 = ["Where do animals go when their tails fall off?", "The retail store"]
JOKE7 = ["Why can't you hear a pterodactyl going to the bathroom?", "Because the \"P\" is silent"]
JOKE8 = ["How does a train eat?", "It goes chew chew"]
JOKE9 = ["Did you hear about the constipated mathematician?", "He worked his problem out with a pencil"]
JOKE10 = ["What did the buffalo say to his son when he left for college?", "Bison"]
JOKE11 = ["What did the pirate say when he turned 80?", "Aye Matey"]
JOKE12 = ["Did you hear about the ATM that got addicted to money?", "It suffered from withdrawals"]
JOKE13 = ["Why do cows wear bells?", "Because their horns don't work"]
JOKE14 = ["Why couldn't the bicycle stand up?", "Because it was two tired!"]
JOKE15 = ["What word becomes shorter when you add two letters to it?", "Short"]
JOKE16 = ["What time does Sean Connery show up to Wimbledon?", "Tennish"]
JOKE17 = ["What happens to a frog's car when it breaks down?", "It gets toad away"]
JOKE18 = ["Why did the tomato blush?", "It saw the salad dressing"]
JOKE19 = ["What did Jay-Z call his girlfriend before they got married?", u"Feyonc\U000000E9"]
JOKE20 = ["How many kids with ADHD does it take to change a light bulb?", "Let's go play on our bikes"]
JOKE21 = ["How do you communicate with a fish?", "Drop it a line"]
JOKE22 = ["What goes ha ha bonk?", "A man laughing his head off"]
JOKE23 = ["What did the egg say to the frying pan?", "You crack me up"]
JOKE24 = ["What is smarter than a talking bird?", "A spelling bee"]
JOKE25 = ["Why did Jon Snow wait in line for 6 hours at the Apple store?", "For the watch"]

JOKES_NO_MORE_TEXT = "Shoot, all out of jokes! I'll go work on some new ones, ask me again tomorrow"
JOKES_MAX_SENT_TODAY_TEXT = "Let me go write another, ask me again tomorrow"
JOKE_USER_GUESSED_IT_RIGHT = "Haha, yup!"
JOKE_LAST_STEP = ":sunglasses:"

################
# DONE COMMAND
###############

# When someone says "Done" for a task
DONE_RESPONSE = "%s Checked :ARTICLE: off :white_check_mark:" # uses DONE_PHRASES for the first part
DONE_SHORT_PHRASES = ["Nice!", "Sweet!", ":+1:", "Well done!", "Woohoo!"]

DELETE_RESPONSE = "Ok. Removed :ARTICLE: :cross_mark:" # replaces :ARTICLE: with 'that' or 'those'


#################
# OTHER MESSAGES
#################

# Used for acknowledging when someone gives us a new reminder or changes time
ACKNOWLEDGEMENT_PHRASES = ["Got it.", "Roger that.", "Copy that.", "Sure thing.", u"\U0001F44D", "Noted.", u"\U0001F44C"]


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


QUESTION_ACKNOWLEDGE_OK_RESPONSE_TEXT = "Got it, thanks."
QUESTION_ACKNOWLEDGE_GREAT_RESPONSE_TEXT = "Great to hear!"

RESPONSE_FOR_WHO_REFERRED_YOU = 'Great, thanks!'


####################
# NICETIES
####################

# Format
# [ input detection regex,
#	response
#  ]
# If more than one response, then it picks at random
# None means we won't respond to it.
PONY_RESPONSE = "Fine. Here's your pony :horse:"
NICETIES_LIST = [
	[
		"(hi|hello|hey|heya) ?(keeper|there)?$",
		["Hi there."]
	],
	[
		"no thanks|not now|maybe later|great to meet you too|nice to meet you too",
		None
	],
	[
		"yes( [\w]+)?$|no$|y$|n$|nope$",
		None
	],
	[
		u"cool$|ok$|great$|k+$|sweet$|hah(a)?|lol$|okay$|(thats )?awesome|\U0001F44D",
		None
	],
	[
		"me too|i agree|agreed|i have a question",
		None
	],
	[
		".*how are you( today)?|how're you|hows it going",
		[u"I'm good, thanks for asking! \U0001F603", u"Can't complain! \U0001F603"]
	],
	[
		"i hate you|you suck|this is stupid|you[\S]{0,2} (stupid|fat|dumb|ugly)",
		["Well that's not very nice. :pouting_face:", "I'm doing my best. :disappointed_face:", ":broken_heart:"]
	],
	[
		"whats your name|who are you|what do you call yourself",
		["Keeper!"]
	],
	[
		"i love you|.*you[\S]{0,2} ((pretty|so) )?(cool|neat|smart|(the (best|greatest)))|you rock",
		[u"You're pretty cool too! :sunglasses:"]
	],
	[
		"I(m| am) sorry|apologies|I apologize|sry",
		[u"That's ok.", u"Don't worry about it.", u"No worries.", u"I'm over it.", u"All good :ok_hand:"]
	],
	[
		"see you later|i have to go$",
		[u"Ok, I'm here if you need me! \U0001F603", u"Sounds good! I'll be here. :sparkles:"]
	],
	[
		"thats (all|it)( for (right )?now)?|(nothing|not) ((right|for) now|at the moment)",
		None
	],
	[
		"are you( a)? real( person)?|are you human|are you an? (computer|machine)|are you an ai",
		["I'm an automated digital assistant, but I have human minions to help me. :smile_cat:"]
	],
	[
		"(is this|are you).* (human|ai|a machine|automated|computer|person)",
		["I'm an automated digital assistant, but I have human minions to help me. :smile_cat:"]
	],
	[
		"whats the meaning of life",
		[u"42 \U0001F433"]
	],
	[
		"where (are you from|do you live)",
		[u"I was created is NYC \U0001f34e"]
	],
	[
		"is this (a scam|for real)",
		[u"I'm just a friendly digital assistant here to help you remember things."]
	],
	[
		"(is this|are you)( kind of|kinda)? like siri",
		[u"We're distantly related. I text and throw better parties though! \U0001f389"]
	],
	[
		"what do you think of siri",
		[u"She's a nice lady, but she needs to loosen up! \U0001f60e"]
	],
	[
		"why.* my zip( )?code",
		[u"Knowing your zip code allows me to send you reminders in the right time zone."]
	],
	[
		"will do|I will|sure",
		[u"\U0001F44F", u"\U0001F44D"]
	],
	[
		"bye(bye)?|keep in touch",
		[u":wave: See ya! Lmk if you need anything!"]
	],
	[
		"have a(n)? [\w]+ day",
		["Thanks, you too! :smile:"]
	],
	[
		"(can you |please )?call me\b|can i call you",
		["Sorry, I can only txt at the moment.", "Txt only :bow:"]
	],
	[
		"are we friends|can we be friends",
		["I like to think so! :smiling_face_with_smiling_eyes:", "BFFs :nail_care:"]
	],
	[
		"will you be my friend",
		["Certainly! But I'm not very smart yet. :hatching_chick:"]
	],
	[
		"can .* motivational support",
		["Go go go! :chequered_flag:", "You can do it! :face_with_ok_gesture:", "To infinity, and beyond! :rocket:"]
	],
	[
		"do you (like|love) me",
		["I think you're pretty cool! :sunglasses:"]
	],
	[
		"do you like .+",
		["I love it! ", "Sometimes, it depends on the day.", "It's ok.", "Meh."]
	],
	[
		"whats (up|going on|new)",
		["Chillin :sunglasses:", "Workin hard. :information_desk_person:", "Nothing much. :bath:"]
	],
	[
		"this is (weird|strange|odd|different)",
		["You're telling me!"]
	],
	[
		"can i call you .+|i('m| am) going to call you .+",
		["You can call me whatever you'd like! :information_desk_person:"]
	],
	[
		"(will you )?marry me|can we be together|will you go out with me|be mine$",
		["Sorry, I'm already taken! :bride_with_veil: I'm here to help you remember stuff though!"]
	],
	[
		"good ?(morning|evening|night|afternoon|day) ?(keeper)?$",
		["Thanks, same to you! :smiling_face_with_smiling_eyes:"]
	],
	[
		"how much .* cost|is .+ free",
		["My help is free! :person_raising_both_hands_in_celebration: Msg and data rates may apply."]
	],
	[
		"that was(nt| not) funny|that(s| was) a (terrible|bad|awful) joke|i did(nt| not) laugh|.*wheres my pony|thats not funny",
		[PONY_RESPONSE]
	],
	[
		"(today is|its) my (birthday|bday)",
		["Happy Birthday! :birthday:"]
	],
]


THANKYOU_RESPONSES = ["You're welcome.", "Happy to help.", "No problem.", "Sure thing."]
AGE_RESPONSE = u"I was born on April 29th, 2015. That makes me about %s old! \U0001F423"
HOW_DO_I_SHARE_KEEPER_RESPONSE = ":clapping_hands_sign: Please send them to %s and thanks!"
MY_NAME_IS_NOT_ROGER_RESPONSE = "I know, it's just an expression %s!"
