import datetime
import sys
import subprocess
import time

def main(argv):
	while True:
		dt = datetime.datetime.utcnow() - datetime.timedelta(seconds=300)
		timeStr = dt.strftime("%Y-%m-%dT%H:%M:%S")
		subprocess.call("python /home/derek/prod/Duffy/peanut/manage.py update_index --start=" + timeStr, shell=True)
		time.sleep(5)

if __name__ == "__main__":
	main(sys.argv[1:])