from smskeeper import async

SECONDS_BETWEEN_SEND = 3


def sendMsg(user, msg, mediaUrls, keeperNumber):
	async.sendMsg(user, msg, mediaUrls, keeperNumber)


def sendMsgs(user, msgList, keeperNumber):
	for message, i in msgList:
		async.sendMsg.apply_async((user, message, None, keeperNumber), coundown=i * SECONDS_BETWEEN_SEND)
