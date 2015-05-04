# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0015_user_timezone'),
    ]

    operations = [
        migrations.CreateModel(
            name='Contact',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('handle', models.CharField(max_length=30, db_index=True)),
                ('target', models.ForeignKey(related_name=b'contact_target', to='smskeeper.User')),
                ('user', models.ForeignKey(to='smskeeper.User')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='Entry',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('text', models.TextField(null=True)),
                ('img_url', models.TextField(null=True)),
                ('remind_timestamp', models.DateTimeField(null=True)),
                ('hidden', models.BooleanField(default=False)),
                ('keeper_number', models.CharField(max_length=100, null=True)),
                ('added', models.DateTimeField(db_index=True, auto_now_add=True, null=True)),
                ('updated', models.DateTimeField(db_index=True, auto_now=True, null=True)),
                ('creator', models.ForeignKey(to='smskeeper.User')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='EntryLink',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('label', models.CharField(max_length=100, db_index=True)),
                ('added', models.DateTimeField(db_index=True, auto_now_add=True, null=True)),
                ('updated', models.DateTimeField(db_index=True, auto_now=True, null=True)),
                ('entry', models.ForeignKey(to='smskeeper.Entry')),
                ('users', models.ManyToManyField(to='smskeeper.User', db_index=True)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
