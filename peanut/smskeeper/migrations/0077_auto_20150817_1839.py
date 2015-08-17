# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0076_user_signature_num_lines'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='create_todo_count',
            field=models.IntegerField(default=0),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='user',
            name='done_count',
            field=models.IntegerField(default=0),
            preserve_default=True,
        ),
    ]
