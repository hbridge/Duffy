# from http://www.pythian.com/blog/logging-for-slackers/

from logging import Handler
from django.conf import settings
import requests, json, traceback, re


class SlackLogHandler(Handler):

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
