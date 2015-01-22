from __future__ import absolute_import

from peanut.celery import app

@app.task
def add(x, y):
	print "%s" % x
