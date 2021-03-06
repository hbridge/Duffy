# to run use ./manage.py test smskeeper.scripts.simulateClassifiedMessages
from smskeeper.scripts.simulate import simulation


# Use prod messages, but simulate and upload results locally
class SMSKeeperLocalSimulationCase(simulation.SMSKeeperSimulationCase):
	SIMULATION_CONFIGURATION = {
		'message_source': 'p',  # messages are from prod
		'sim_type': 'nl',  # this is a nightly run
		'classified_messages_url': "http://prod.strand.duffyapp.com/smskeeper/classified_messages_feed",
		'post_results_url': "http://dev.duffyapp.com/smskeeper/simulation_run/"
	}
