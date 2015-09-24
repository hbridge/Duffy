# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0099_remove_message_body'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='body',
            field=models.TextField(null=True),
            preserve_default=True,
        ),
    ]
