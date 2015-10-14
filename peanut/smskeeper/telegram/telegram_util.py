from smskeeper import keeper_constants
import telegram
from django.conf import settings
import logging

logger = logging.getLogger(__name__)


def isTelegramNumber(phoneNumber):
	return keeper_constants.TELEGRAM_NUMBER_SUFFIX in phoneNumber


def privateChatIdForUser(user):
	if not isTelegramNumber(user.phone_number):
		return None
	return user.phone_number.split("@")[0]


def sendMessage(user, msgText, mediaUrl, keeperNumber):
	bot = telegram.Bot(token=settings.TELEGRAM_TOKEN)
	chatId = privateChatIdForUser(user)
	try:
		if msgText and msgText != "":
			bot.sendMessage(chat_id=chatId, text=msgText)
		if mediaUrl:
			bot.sendPhoto(chat_id=chatId, photo=mediaUrl)
		logger.info("User %d: was sent telegram: %s", user.id, msgText)
	except telegram.error.TelegramError as telegramError:
		logger.error("User %d: error sending telegram: %s", user.id, telegramError)
