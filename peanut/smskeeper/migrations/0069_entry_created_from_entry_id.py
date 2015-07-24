# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0068_message_classification_scores_json'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='created_from_entry_id',
            field=models.IntegerField(null=True),
            preserve_default=True,
        ),
    ]
