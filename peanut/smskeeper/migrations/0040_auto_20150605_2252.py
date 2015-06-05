# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0039_auto_20150604_1856'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='state',
            field=models.CharField(default=b'not-activated', max_length=100, choices=[(b'normal', b'normal'), (b'help', b'help'), (b'not-activated', b'not-activated'), (b'tutorial', b'tutorial'), (b'tutorial-remind', b'tutorial-remind'), (b'tutorial-todo', b'tutorial-todo'), (b'remind', b'remind'), (b'reminder-sent', b'reminder-sent'), (b'delete', b'delete'), (b'add', b'add'), (b'implicit-label', b'implicit-label'), (b'unresolved-handles', b'unresolved-handles'), (b'unknown-command', b'unknown-command'), (b'stopped', b'stopped'), (b'not-activated-from-reminder', b'not-activated-from-reminder')]),
        ),
    ]
