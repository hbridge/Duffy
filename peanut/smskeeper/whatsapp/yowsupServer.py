#!/usr/bin/env python

from yowsupLayer import KeeperLayer
from yowsup.layers.auth import YowAuthenticationProtocolLayer
from yowsup.layers.protocol_messages import YowMessagesProtocolLayer
from yowsup.layers.protocol_receipts import YowReceiptProtocolLayer
from yowsup.layers.protocol_acks import YowAckProtocolLayer
from yowsup.layers.network import YowNetworkLayer
from yowsup.layers.coder import YowCoderLayer
from yowsup.stacks import YowStack
from yowsup.common import YowConstants
from yowsup.layers import YowLayerEvent
from yowsup.stacks import YOWSUP_CORE_LAYERS
from yowsup import env


CREDENTIALS = ("3584573970584", "2Vqf6AGTedRERwMVm3WdnU0DCbs=")

if __name__ == "__main__":
	layers = (
		KeeperLayer,
		(YowAuthenticationProtocolLayer, YowMessagesProtocolLayer, YowReceiptProtocolLayer, YowAckProtocolLayer)
	) + YOWSUP_CORE_LAYERS

	stack = YowStack(layers)
	stack.setProp(KeeperLayer.KEEPER_NUMBER, "%s@s.whatsapp.net" % CREDENTIALS[0])
	stack.setProp(YowAuthenticationProtocolLayer.PROP_CREDENTIALS, CREDENTIALS)  # setting credentials
	stack.setProp(YowNetworkLayer.PROP_ENDPOINT, YowConstants.ENDPOINTS[0])  # whatsapp server address
	stack.setProp(YowCoderLayer.PROP_DOMAIN, YowConstants.DOMAIN)
	stack.setProp(YowCoderLayer.PROP_RESOURCE, env.CURRENT_ENV.getResource())  # info about us as WhatsApp client

	stack.broadcastEvent(YowLayerEvent(YowNetworkLayer.EVENT_STATE_CONNECT))  # sending the connect signal

	stack.loop()  # this is the program mainloop
