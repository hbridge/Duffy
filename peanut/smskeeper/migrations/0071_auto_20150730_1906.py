# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0070_auto_20150724_2311'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='stripe_data_json',
            field=models.TextField(null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AlterField(
            model_name='user',
            name='last_state',
            field=models.CharField(default=b'not-activated', max_length=100, choices=[(b'normal', b'normal'), (b'help', b'help'), (b'not-activated', b'not-activated'), (b'tutorial-list', b'tutorial-list'), (b'tutorial-remind', b'tutorial-remind'), (b'tutorial-todo', b'tutorial-todo'), (b'remind', b'remind'), (b'reminder-sent', b'reminder-sent'), (b'delete', b'delete'), (b'add', b'add'), (b'implicit-label', b'implicit-label'), (b'unresolved-handles', b'unresolved-handles'), (b'unknown-command', b'unknown-command'), (b'stopped', b'stopped'), (b'suspended', b'suspended'), (b'not-activated-from-reminder', b'not-activated-from-reminder'), (b'tutorial-medical', b'tutorial-medical')]),
        ),
        migrations.AlterField(
            model_name='user',
            name='state',
            field=models.CharField(default=b'not-activated', max_length=100, choices=[(b'normal', b'normal'), (b'help', b'help'), (b'not-activated', b'not-activated'), (b'tutorial-list', b'tutorial-list'), (b'tutorial-remind', b'tutorial-remind'), (b'tutorial-todo', b'tutorial-todo'), (b'remind', b'remind'), (b'reminder-sent', b'reminder-sent'), (b'delete', b'delete'), (b'add', b'add'), (b'implicit-label', b'implicit-label'), (b'unresolved-handles', b'unresolved-handles'), (b'unknown-command', b'unknown-command'), (b'stopped', b'stopped'), (b'suspended', b'suspended'), (b'not-activated-from-reminder', b'not-activated-from-reminder'), (b'tutorial-medical', b'tutorial-medical')]),
        ),
    ]
