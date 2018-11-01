#!/bin/python3

import os
import sys
import argparse
import logging
import re
import platform

MONTHS = {
    "Jan": "01",
    "Feb": "02",
    "Mar": "03",
    "Apr": "04",
    "May": "05",
    "Jun": "06",
    "Jul": "07",
    "Aug": "08",
    "Sep": "09",
    "Oct": "10",
    "Nov": "11",
    "Dec": "12"
}

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='THOR Timestamp Converter')
    parser.add_argument('-f', help='Year to inject', metavar='year', default='')
    parser.add_argument('-l', help='Logfile', metavar='logfile', default='thor-ts-converter.log')
    parser.add_argument('-d', help='Directory to process', metavar='directory', default='')
    parser.add_argument('-e', help='Extension of target files', metavar='ext', default='.new')
    parser.add_argument('--debug', action='store_true', default=False, help='Debug output')

    args = parser.parse_args()

    # Logging
    logFormatter = logging.Formatter("[%(levelname)-5.5s] %(message)s")
    logFormatterRemote = logging.Formatter("{0} [%(levelname)-5.5s] %(message)s".format(platform.uname()[1]))
    Log = logging.getLogger()
    Log.setLevel(logging.INFO)
    # File Handler
    fileHandler = logging.FileHandler(args.l)
    fileHandler.setFormatter(logFormatter)
    Log.addHandler(fileHandler)
    # Console Handler
    consoleHandler = logging.StreamHandler()
    consoleHandler.setFormatter(logFormatter)
    Log.addHandler(consoleHandler)

    # Debug
    if args.debug:
        Log.setLevel(logging.DEBUG)

    # Error
    if not args.d or args.d == "":
        Log.error("No target directory given (-d)")
        sys.exit(1)
    if not args.f or args.f == "":
        Log.error("No target year set (-f) (use: %YYYY format)")
        sys.exit(1)

    for filename in os.listdir(args.d):
        # Full path input file
        file_path = os.path.join(args.d, filename)
        if not os.path.isfile(file_path):
            Log.debug("Skipping element %s (not a file)" % file_path)
            continue
        # Full path output file
        file_output = os.path.join(args.d, "%s%s" % (filename, args.e))
        Log.debug("Processing %s" % file_path)

        # Read file line by line
        lines = []
        with open(file_path, 'r') as fh:
            lines = fh.readlines()

        # Process lines
        new_lines = []
        processed_lines = 0
        for line in lines:
            m = re.search("^([A-Z][a-z][a-z])[\s]{1,2}([0-9]{1,2})\s([0-9]{2}:[0-9]{2}:[0-9]{2})", line)
            if m:
                new_ts = "%s-%s-%sT%sZ" % (args.f, MONTHS[m.group(1)], m.group(2).rjust(2, "0"), m.group(3))
                old_ts = m.group(0)
                line = line.replace(old_ts, new_ts)
                new_lines.append(line)
                processed_lines += 1

        # Warning - something is weird in file - no matches
        if processed_lines == 0:
            Log.warning("Not a single timestamp regex match in file %s" % file_path)
            continue

        # Write file
        Log.debug("Writing file %s" % file_output)
        with open(file_output, "w") as fh:
            fh.writelines(new_lines)
