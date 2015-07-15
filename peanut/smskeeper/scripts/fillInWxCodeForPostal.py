import csv
import sys
import os
import tarfile
import time

import urllib2
import urllib
import logging
from urllib2 import URLError

from xml.dom import minidom

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "../..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

"""
	This file takes in ukcodesdata-raw.csv and looks through each postalcode, looks up the
	town name at weather.com and fills in the wxcode (what you use to look up the weather for that postal code)
	It then writes out a csv with the full info

"""

def main(argv):
	fin = open(sys.argv[1], 'rt')
	fout = open(sys.argv[2], 'w')
	processFile(fin, fout)


def findCity(searchCity):
	searchTerm = searchCity + " United Kingdom"
	locData = get_loc_id_from_weather_com(searchTerm)

	locationIds = {}
	for i in xrange(locData['count']):
		locationIds[locData[i][0]] = locData[i][1]

	foundCode = None
	foundCity = None
	for code, city in locationIds.iteritems():
		firstCity = city.split(",")[0]
		if searchCity.lower() == firstCity.lower():
			foundCode = code
			foundCity = city

	return foundCode, foundCity


def processFile(fin, fout, silent=False):
	cityToWxCodeCache = dict()

	reader = csv.reader(fin)
	writer = csv.writer(fout)
	for row in reader:
		postalCode = row[0]
		searchCity = row[5].strip()
		wxCode = None

		if searchCity in cityToWxCodeCache:
			print "Found %s in cache. Assigning %s to %s" % (searchCity, postalCode, cityToWxCodeCache[searchCity])
			wxCode = cityToWxCodeCache[searchCity]
		else:
			foundCode, foundCity = findCity(searchCity)

			if foundCode is None:
				foundCode, foundCity = findCity(searchCity.replace('-', ' '))

			if foundCode is None:
				foundCode, foundCity = findCity(searchCity.replace(' ', '-'))

			if foundCode is None:
				foundCode, foundCity = findCity(searchCity.split('-')[0])

			if foundCode is None:
				print "Error when looking for %s" % searchCity
				wxCode = raw_input("Please enter manual: ")
				cityToWxCodeCache[searchCity] = wxCode
			else:
				print "For %s found: %s.  Matching %s to %s" % (searchCity, foundCity, postalCode, foundCode)
				cityToWxCodeCache[searchCity] = foundCode
				wxCode = foundCode

		if not wxCode:
			print "Don't have a wxCode for %s" % row
			time.sleep(110000)
		else:
			row.append(wxCode)
			writer.writerow(row)

	fin.close()
	fout.close()

LOCID_SEARCH_URL = 'http://xml.weather.com/search/search'


def get_loc_id_from_weather_com(search_string):
	"""Get location IDs for place names matching a specified string.
	Same as get_location_ids() but different return format.

	Parameters:
		search_string: Plaintext string to match to available place names.
		For example, a search for 'Los Angeles' will return matches for the
		city of that name in California, Chile, Cuba, Nicaragua, etc as well
		as 'East Los Angeles, CA', 'Lake Los Angeles, CA', etc.

	Returns:
		loc_id_data: A dictionary of tuples in the following format:
		{'count': 2, 0: (LOCID1, Placename1), 1: (LOCID2, Placename2)}

	"""

	params = {"where": search_string}

	weatherUrl = "%s?%s" % (LOCID_SEARCH_URL, urllib.urlencode(params))

	try:
		xml_response = urllib2.urlopen(weatherUrl).read()
	except URLError as e:
		print("Could not connect to Weather: %s" % (e.strerror))

	dom = minidom.parseString(xml_response)

	loc_id_data = {}
	try:
		num_locs = 0
		for loc in dom.getElementsByTagName('search')[0].getElementsByTagName('loc'):
			loc_id = loc.getAttribute('id')  # loc id
			place_name = loc.firstChild.data  # place name
			loc_id_data[num_locs] = (loc_id, place_name)
			num_locs += 1
		loc_id_data['count'] = num_locs
	except IndexError:
		error_data = {'error': 'No matching Location IDs found'}
		return error_data
	finally:
		dom.unlink()

	return loc_id_data

if __name__ == "__main__":
	main(sys.argv[1:])
