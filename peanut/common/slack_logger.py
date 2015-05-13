import json
from logging import Handler
import traceback

from django.conf import settings
from peanut.settings import constants
import requests


class SlackLogHandler(Handler):
    # from http://www.pythian.com/blog/logging-for-slackers/
    def __init__(self, logging_url="", stack_trace=False):
        Handler.__init__(self)
        self.stack_trace = stack_trace

    def emit(self, record):
        # print "slack logger called"
        if not hasattr(settings, "SLACK_LOGGING_URL"):
            return
        message = '%s' % (record.getMessage())
        if self.stack_trace:
            attachments = []
            if record.exc_info:
                traceback_lines = traceback.format_exception(*record.exc_info)
                traceback_lines = traceback_lines[1:]
                traceback_lines.reverse()
                print "traceback_lines %s" % (traceback_lines)
                attachments = [{
                    "pretext": "Traceback (most recent first)",
                    "fallback": "traceback",
                    "text": '\n'.join(traceback_lines),
                    "color": "danger",
                }]
        payload = json.dumps(
            {
                "channel": "#errors",
                "username": "Error Bot",
                "icon_emoji": ":bomb:",
                "text": message,
                "attachments": attachments
            })
        # print "posting to %s: %s" % (settings.SLACK_LOGGING_URL, payload)
        requests.post(
            settings.SLACK_LOGGING_URL,
            data=payload
        )


def postMessage(message):
    msgContent = json.loads(message.msg_json)
    if ('To' in msgContent and msgContent['To'] in constants.KEEPER_PROD_PHONE_NUMBERS) or ('From' in msgContent and msgContent['From'] in constants.KEEPER_PROD_PHONE_NUMBERS):
        url = 'https://hooks.slack.com/services/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'
        channel = "#livesmskeeperfeed"
        params = dict()
        text = msgContent['Body']

        if message.incoming:
            userName = message.user.name + ' (' + message.user.phone_number + ')'

            numMedia = int(msgContent['NumMedia'])

            if numMedia > 0:
                for n in range(numMedia):
                    param = 'MediaUrl' + str(n)
                    text += "\n<" + msgContent[param] + "|" + param + ">"
            params['icon_emoji'] = ':raising_hand:'

        else:
            if message.user.name:
                name = message.user.name
            else:
                name = message.user.phone_number
            userName = "Keeper" + " (to: " + name + ")"
            if msgContent['MediaUrls']:
                text += " <" + str(msgContent['MediaUrls']) + "|Attachment>"
            params['icon_emoji'] = ':rabbit:'

        params['username'] = userName
        params['text'] = text
        params['channel'] = channel

        requests.post(url, data=json.dumps(params))
