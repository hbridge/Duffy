import asyncore
import socket
import json
from smskeeper import keeper_constants
import logging
logger = logging.getLogger(__name__)


def phoneNumToWhatsappId(phoneNum):
	waid = phoneNum.replace("+", "") + keeper_constants.WHATSAPP_NUMBER_SUFFIX
	return waid


def whatsappIdToPhoneNum(whatsappId):
	phoneNum = "+" + whatsappId.replace(keeper_constants.WHATSAPP_NUMBER_SUFFIX, "")
	return phoneNum


def isWhatsappNumber(number):
	return keeper_constants.WHATSAPP_NUMBER_SUFFIX in number


def sendMessage(recipientPhone, msgText, mediaUrl, keeperNumber):
	recipientId = recipientPhone.replace("+", "")
	recipientId = recipientId + keeper_constants.WHATSAPP_NUMBER_SUFFIX

	logger.info("Sending whatsapp message to %s via local proxy: %s", recipientId, msgText)
	c = WhatsappProxyClient('127.0.0.1', keeper_constants.WHATSAPP_LOCAL_PROXY_PORT)
	c.send(json.dumps({"To": phoneNumToWhatsappId(recipientPhone), "Body": msgText}))
	c.close()


class WhatsappProxyClient(asyncore.dispatcher):
	def __init__(self, host, port):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.connect((host, port))
		logger.info("WhatsappProxyClient Start...")

	def handle_close(self):
		logger.info("WhatsappProxyClient Stop...")
		self.close()

	def handle_read(self):
		data = self.recv(1024)
		if data:
			logger.info("WhatsappProxyClient received: %s", data)
