import json
from logging import Handler
import traceback

from django.conf import settings
import requests
from peanut.settings import constants

import logging

logger = logging.getLogger(__name__)


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

SLACK_URL = 'https://hooks.slack.com/services/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'


def postManualAlert(user, msg, keeperNumber, channel):
    if (isProdNumber(keeperNumber)):
        params = dict()
        params['icon_emoji'] = ':raising_hand:'

        if user.name:
            name = user.name
        else:
            name = user.phone_number

        historyLink = "<http://prod.strand.duffyapp.com/smskeeper/history?user_id=" + str(user.id) + "|history>"

        params['username'] = name
        params['text'] = "%s | %s" % (msg, historyLink)
        params['channel'] = channel

        requests.post(SLACK_URL, data=json.dumps(params))


def postMessage(message, channel):
    msgContent = json.loads(message.msg_json)
    if (isProdMessage(message)):
        params = dict()
        text = msgContent['Body']

        if message.incoming:
            userName = message.user.name + ' (' + message.user.phone_number + ')'

            if "NumMedia" in msgContent:
                numMedia = int(msgContent['NumMedia'])
            else:
                numMedia = 0

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
        params['text'] = text + " | <http://prod.strand.duffyapp.com/smskeeper/history?user_id=" + str(message.user.id) + "|history>"
        params['channel'] = channel

        requests.post(SLACK_URL, data=json.dumps(params))


def isProdMessage(message):
    sender, recipient = message.getMessagePhoneNumbers()
    if (isProdNumber(sender) or isProdNumber(recipient)):
        return True
    return False


def isProdNumber(number):
    return number in constants.KEEPER_PROD_PHONE_NUMBERS


def postUserReport(uid, recentMessages):
    if (not hasattr(settings, "SLACK_LOGGING_URL") or
            not isProdMessage(recentMessages[0])):
        logger.info("postUserReport: no slack URL, most likely debug env")
        return

    recentMessagesText = ""
    for message in recentMessages:
        mediaStr = ""
        if message.NumMedia() > 0:
            mediaStr = "(%d attachments)" % (message.NumMedia())
        recentMessagesText += "%s: %s %s\n" % (message.getSenderName(), message.getBody(), mediaStr)

    attachments = [{
        "pretext": "Recent messages (newest first)",
        "fallback": "recent messages",
        "text": recentMessagesText,
        "color": "warning",
    }]
    payload = json.dumps({
        "channel": "#errors",
        "username": "User Report",
        "icon_emoji": ":raising_hand:",
        "text": "Report from user (history: %s%d)" % (settings.USER_HISTORY_PATH, uid),
        "attachments": attachments
    })
    # print "posting to %s: %s" % (settings.SLACK_LOGGING_URL, payload)
    requests.post(
        settings.SLACK_LOGGING_URL,
        data=payload
    )
