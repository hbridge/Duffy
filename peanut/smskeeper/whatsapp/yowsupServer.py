#!/usr/bin/env python

from yowsupLayer import KeeperLayer
from yowsup.layers.auth import YowAuthenticationProtocolLayer
from yowsup.layers.protocol_messages import YowMessagesProtocolLayer
from yowsup.layers.protocol_receipts import YowReceiptProtocolLayer
from yowsup.layers.protocol_acks import YowAckProtocolLayer
from yowsup.layers.protocol_media import YowMediaProtocolLayer
from yowsup.layers.protocol_iq import YowIqProtocolLayer
from yowsup.layers.protocol_calls import YowCallsProtocolLayer
from yowsup.layers.network import YowNetworkLayer
from yowsup.layers.coder import YowCoderLayer
from yowsup.layers.axolotl import YowAxolotlLayer
from yowsup.layers.logger import YowLoggerLayer
from yowsup.layers.auth import YowCryptLayer
from yowsup.layers.stanzaregulator import YowStanzaRegulator

from yowsup.stacks import YowStack
from yowsup.common import YowConstants
from yowsup.layers import YowLayerEvent
from yowsup import env

# import logging
# logging.basicConfig(level=logging.DEBUG)  # uncomment for debug info

from django.conf import settings

if __name__ == "__main__":
	layers = (
		KeeperLayer,
		(  # these protocol layers are parallel layers
			YowAuthenticationProtocolLayer,
			YowMessagesProtocolLayer,
			YowReceiptProtocolLayer,
			YowAckProtocolLayer,
			YowMediaProtocolLayer,
			YowIqProtocolLayer,
			YowCallsProtocolLayer
		),
		YowAxolotlLayer,  # we don't use basic layers because of disconnects, see https://github.com/tgalal/yowsup/issues/873
		YowLoggerLayer,
		YowCoderLayer,
		YowCryptLayer,
		YowStanzaRegulator,
		YowNetworkLayer
	)

	stack = YowStack(layers)
	stack.setProp(KeeperLayer.KEEPER_NUMBER, "%s@s.whatsapp.net" % settings.WHATSAPP_CREDENTIALS[0])
	stack.setProp(YowAuthenticationProtocolLayer.PROP_CREDENTIALS, settings.WHATSAPP_CREDENTIALS)  # setting credentials
	stack.setProp(YowNetworkLayer.PROP_ENDPOINT, YowConstants.ENDPOINTS[0])  # whatsapp server address
	stack.setProp(YowCoderLayer.PROP_DOMAIN, YowConstants.DOMAIN)
	stack.setProp(YowCoderLayer.PROP_RESOURCE, env.CURRENT_ENV.getResource())  # info about us as WhatsApp client

	stack.broadcastEvent(YowLayerEvent(YowNetworkLayer.EVENT_STATE_CONNECT))  # sending the connect signal

	stack.loop()  # this is the program mainloop
