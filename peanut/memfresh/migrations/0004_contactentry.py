# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('memfresh', '0003_followup_for_email'),
    ]

    operations = [
        migrations.CreateModel(
            name='ContactEntry',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('name', models.CharField(max_length=100)),
                ('phone_number', models.CharField(max_length=128, db_index=True)),
                ('email', models.CharField(max_length=100)),
                ('added', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('updated', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(to='memfresh.User')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
