# from http://www.pythian.com/blog/logging-for-slackers/

from logging import Handler
from django.conf import settings
import requests, json, traceback


class SlackLogHandler(Handler):

    def __init__(self, logging_url="", stack_trace=False):
        Handler.__init__(self)
        self.logging_url = logging_url
        self.stack_trace = stack_trace

    def emit(self, record):
        print "slack logger called"
        if not hasattr(settings, "SLACK_LOGGING_URL"):
            return
        message = '%s' % (record.getMessage())
        if self.stack_trace:
            if record.exc_info:
                message += '\n'.join(traceback.format_exception(*record.exc_info))
                requests.post(
                    self.logging_url,
                    data=json.dumps({
                        "channel": "#errors",
                        "username": "webhookbot",
                        "icon_emoji": ":bomb:",
                        "text": message,
                    })
                )
