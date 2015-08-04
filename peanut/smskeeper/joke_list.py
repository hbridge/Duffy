import logging

from smskeeper import sms_util

logger = logging.getLogger(__name__)


class Joke():
	jokeType = None
	jokeData = None

	def __init__(self, jokeType, jokeData):
		self.jokeType = jokeType
		self.jokeData = jokeData

	def takesResponse(self):
		if self.jokeType == RESPONSE:
			return True
		return False

	def send(self, user, step=None, msg=None):
		if self.jokeType == ONE_LINER:
			sms_util.sendMsg(user, self.jokeData)
			return True
		elif self.jokeType == EQUAL_PAUSE:
			sms_util.sendMsgs(user, self.jokeData)
			return True
		elif self.jokeType == LONG_PAUSE:
			firstPart = self.jokeData[:-1]
			lastPart = self.jokeData[-1]

			secondsDelayed = sms_util.sendMsgs(user, firstPart)
			sms_util.sendDelayedMsg(user, lastPart, secondsDelayed + 5)
			return True
		elif self.jokeType == RESPONSE:
			if step == 0:
				sms_util.sendMsg(user, self.jokeData[0])
				return False  # Joke not done yet
			else:
				if msg and msg == self.jokeData[1]:
					sms_util.sendMsg(user, "Haha, yup!")
				else:
					sms_util.sendMsg(user, self.jokeData[1])
				return True

	def __str__(self):
		string = "%s %s" % (self.jokeType, self.jokeData)
		return string.encode('utf-8')


def getJoke(jokeNum):
	if jokeNum < len(JOKES):
		return JOKES[jokeNum]
	return None

ONE_LINER = 0
RESPONSE = 1
LONG_PAUSE = 2
EQUAL_PAUSE = 3

JOKES = [
	Joke(RESPONSE, ["What do you call a boomerang that doesn't come back?", "A stick"]),
	Joke(LONG_PAUSE, ["A blonde gets in her car and notices her steering wheel, dashboard, and windshield is missing.", "She calls the police and reports a theft. When the police officer comes, he looks at the blonde who is crying and and says:", "\"Ma'am...you're sitting in the backseat...\""]),
	Joke(LONG_PAUSE, ["A guy walks into a bar with a pet alligator by his side. He puts the alligator up on the bar and turns to the astonished patrons.", "\"I'll make you a deal. I'll open this alligator's mouth and place my genitals inside. Then the gator will close his mouth for one minute. He'll then open his mouth, and I'll remove my unit unscathed. In return for witnessing this spectacle, each of you will buy me a drink.\"", "The crowd murmurs their approval. The man stands up on the bar, drops his trousers, and places his privates in the alligator's open mouth. The gator closes his mouth as the crowd gasps. After a minute, the man grabs a beer bottle and raps the alligator hard on the top its head. The gator opens his mouth, and the man removes his genitals, unscathed, as promised. The crowd cheers, and he receives the first of his free drinks.", "The man stands up again and makes another offer: \"I'll pay anyone $100 who's willing to give it a try.\"", "A hush falls over the crowd. A moment later, a hand goes up in the back of the bar.", "\"I'll try,\" says a small woman, \"but you have to promise not to hit me on the head with the beer bottle.\""]),
	Joke(LONG_PAUSE, ["A guy walks into a bar with his pet monkey. He orders a drink, and while he's drinking, the monkey jumps all over the place, eating everything behind the bar. Then the monkey jumps on to the pool table and swallows a billiard ball.", "The bartender screams at the guy, \"Your monkey just ate the cue ball off my pool table -- whole!\"", "\"Sorry,\" replied the guy. \"He eats everything in sight, the little bastard. I'll pay for everything.\"", "The man finishes his drink, pays and leaves.", "Two weeks later, he's in the bar with his pet monkey, again. He orders a drink, and the monkey starts running around the bar. The monkey finds a maraschino cherry on the bar. He grabs it, sticks it up his ass, pulls it out and eats it.", "The bartender is disgusted. \"Did you see what your monkey did now?\" he asks.", "\"Yeah,\" replies the guy. \"He still eats everything in sight, but ever since he swallowed that cue ball, he measures stuff first.\""]),
	Joke(LONG_PAUSE, ["Did you hear about the man that was born with both sexes?", "He had a dick and a brain!"]),
	Joke(ONE_LINER, "Yo' Mama is so stupid, she climbed a glass wall to see what was on the other side."),
	Joke(EQUAL_PAUSE, ["A redneck family's only son returns home from college. The father asks, \"Well son, you done gone to college, so you must be perty smart. Why don't you speak some math fer' us?\"", "The son says, \"Pi R squared.\"", "The father yells, \"Why son, they ain't teached ya nothin'! Pies are round, cornbread are square.\""]),
	Joke(ONE_LINER, "Yo' Mama is so stupid, her favorite color is clear."),

]
