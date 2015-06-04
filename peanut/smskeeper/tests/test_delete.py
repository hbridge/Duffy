from mock import patch

from smskeeper import msg_util, cliMsg, keeper_constants

import test_base


class SMSKeeperDeleteCase(test_base.SMSKeeperBaseCase):
	def test_delete_parsing(self):
		self.assertTrue(msg_util.isDeleteCommand("delete 1"))
		self.assertTrue(msg_util.isDeleteCommand("delete 1 from groceries"))
		self.assertTrue(msg_util.isDeleteCommand("delete 1 #groceries"))

		label, indices = msg_util.parseDeleteCommand("delete 1")
		self.assertEqual(label, None)
		self.assertEqual(indices, set([1]))

		label, indices = msg_util.parseDeleteCommand("delete 1,2,3 from groceries")
		self.assertEqual(label, "#groceries")
		self.assertEqual(indices, set([1, 2, 3]))

	def test_freeform_absolute_delete(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
		cliMsg.msg(self.testPhoneNumber, "Delete 1 from groceries")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertNotIn("milk", self.getOutput(mock))

	def test_freeform_delete(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
		cliMsg.msg(self.testPhoneNumber, "Groceries")
		cliMsg.msg(self.testPhoneNumber, "Delete 1")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertNotIn("milk", self.getOutput(mock))

	def test_absolute_delete(self):
		self.setupUser(True, True)
		# ensure deleting from an empty list doesn't crash
		cliMsg.msg(self.testPhoneNumber, "delete 1 #test")
		cliMsg.msg(self.testPhoneNumber, "old fashioned #cocktail")

		# First make sure that the entry is there
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertIn("old fashioned", self.getOutput(mock))

		# Next make sure we delete and the list is clear
		cliMsg.msg(self.testPhoneNumber, "delete 1 #cocktail")   # test absolute delete
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertNotIn("old fashioned", self.getOutput(mock))

	def test_contextual_delete(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			cliMsg.msg(self.testPhoneNumber, "add foo%d to #bar" % (i))

		# ensure we don't delete when ambiguous
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertIn("Sorry, I'm not sure", self.getOutput(mock))

		# ensure deletes right item
		cliMsg.msg(self.testPhoneNumber, "#bar")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 2")
			self.assertNotIn("2. foo2", self.getOutput(mock))

		# ensure can chain deletes
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("1. foo1", self.getOutput(mock))

		# ensure deleting from empty doesn't crash
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("I deleted", self.getOutput(mock))

	def test_contextual_clear(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't clear this list when we use an absolute of another list
		cliMsg.msg(self.testPhoneNumber, "bar")
		cliMsg.msg(self.testPhoneNumber, "clear baz")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "bar")
			self.assertIn("foo", self.getOutput(mock))

		# clear now after we just listed bar
		cliMsg.msg(self.testPhoneNumber, "clear")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "bar")
			self.assertNotIn("foo", self.getOutput(mock))

	def test_multi_delete(self):
		self.setupUser(True, True)
		for i in range(1, 5):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we can delete with or without spaces
		cliMsg.msg(self.testPhoneNumber, "delete 3, 5,2 #bar")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#bar")

			self.assertNotIn("foo2", self.getOutput(mock))
			self.assertNotIn("foo3", self.getOutput(mock))
			self.assertNotIn("foo5", self.getOutput(mock))
