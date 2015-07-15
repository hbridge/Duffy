from yowsup.layers.interface import YowInterfaceLayer, ProtocolEntityCallback
from yowsup.layers.protocol_receipts.protocolentities import OutgoingReceiptProtocolEntity
from yowsup.layers.protocol_acks.protocolentities import OutgoingAckProtocolEntity
from yowsup.layers.protocol_messages.protocolentities import TextMessageProtocolEntity
from yowsup.layers.protocol_chatstate.protocolentities import ChatstateProtocolEntity
from yowsup.layers.protocol_chatstate.protocolentities import OutgoingChatstateProtocolEntity
from yowsup.layers.protocol_presence.protocolentities import SubscribePresenceProtocolEntity

from yowsup.layers.network.layer import YowNetworkLayer
import asyncore
import socket
import json
import urllib
import urllib2
from time import sleep

from django.conf import settings

import os
import sys
parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from smskeeper import keeper_constants

import logging
logger = logging.getLogger(__name__)

INCOMING_SMS_URL = settings.WHATSAPP_SMS_URL


class KeeperLayer(YowInterfaceLayer, asyncore.dispatcher_with_send):
	KEEPER_NUMBER = "com.duffyapp.keeper.phonenumber"

	def __init__(self):
		YowInterfaceLayer.__init__(self)
		asyncore.dispatcher.__init__(self)

	@ProtocolEntityCallback("message")
	def onMessage(self, messageProtocolEntity):
		# send receipt otherwise we keep receiving the same message over and over
		receipt = OutgoingReceiptProtocolEntity(
			messageProtocolEntity.getId(),
			messageProtocolEntity.getFrom(),
			'read',
			messageProtocolEntity.getParticipant()
		)

		logger.info("Whatsapp incoming message: %s", messageProtocolEntity)
		self.toLower(receipt)

		data = urllib.urlencode(self.createRequestDictForMessage(messageProtocolEntity))
		try:
			urllib2.urlopen(url=INCOMING_SMS_URL, data=data).read()
			logger.info("Posted whatsapp incoming message for processing: %s", messageProtocolEntity)
		except urllib2.URLError as e:
			logger.error("Could not connect to incoming_sms: %s" % (e.strerror))

	def createRequestDictForMessage(self, messageProtocolEntity):
		return {
			"From": messageProtocolEntity.getFrom(),
			"To": self.getProp(KeeperLayer.KEEPER_NUMBER),
			"id": messageProtocolEntity.getId(),
			"Body": messageProtocolEntity.getBody(),
			"NumMedia": 0,
			"Timestamp": messageProtocolEntity.getTimestamp()
		}

	@ProtocolEntityCallback("receipt")
	def onReceipt(self, entity):
		ack = OutgoingAckProtocolEntity(entity.getId(), "receipt", entity.getType(), entity.getFrom())
		self.toLower(ack)

	def onEvent(self, ev):
		if ev.getName() == YowNetworkLayer.EVENT_STATE_CONNECT:
			# open up socket
			self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
			self.set_reuse_addr()
			self.bind(('localhost', keeper_constants.WHATSAPP_LOCAL_PROXY_PORT))
			self.listen(5)

		elif ev.getName() == YowNetworkLayer.EVENT_STATE_DISCONNECT:
			# close socket
			self.handle_close("Network Layer Disconnected")

	def handle_accept(self):
		pair = self.accept()
		if pair is not None:
			sock, addr = pair
			logger.info("WhatsappLocalProxyServer local connection from: %s", repr(addr))
			handler = LocalNetworkHandler(sock, self)

	def handle_close(self, reason="Connection Closed"):
		logger.debug("Disconnected, reason: %s" % reason)
		self.close()

	def handle_error(self):
		raise

	def handle_read(self):
		readSize = self.getProp(self.__class__.PROP_NET_READSIZE, 1024)
		data = self.recv(readSize)
		print "%s received local data %s" % ("KeeperLayer", data)
		# self.receive(data)


class LocalNetworkHandler(asyncore.dispatcher_with_send):
	keeperLayer = None

	def __init__(self, sock, keeperLayer):
		asyncore.dispatcher_with_send.__init__(self, sock)
		self.keeperLayer = keeperLayer

	def handle_read(self):
		# set typing indicator
		data = self.recv(8192)
		logger.info("WhatsappLocalProxyServer received message: %s, len(data):%d", data, len(data))
		if len(data) == 0:
			return
		try:
			message = json.loads(data)
			if type(message["Body"]) == unicode:
				message["Body"] = message["Body"].encode("utf-8")
		except Exception as e:
			logger.error("Error parsing json: %s, data: %s" % (e, data))
			return

		# set typing state
		entity = SubscribePresenceProtocolEntity(message["To"])  # todo this may not be necessary
		self.keeperLayer.toLower(entity)

		typingState = OutgoingChatstateProtocolEntity(ChatstateProtocolEntity.STATE_TYPING, message["To"])
		self.keeperLayer.toLower(typingState)

		# wait for 200ms /word
		wordcount = len(message["Body"].split(" "))
		seconds_delay = max(wordcount * keeper_constants.DELAY_SECONDS_PER_WORD, keeper_constants.MIN_DELAY_SECONDS)
		sleep(seconds_delay)

		# send outgoing message
		outgoingMessageProtocolEntity = TextMessageProtocolEntity(
			message["Body"],
			to=message["To"]
		)
		self.keeperLayer.toLower(outgoingMessageProtocolEntity)
