#!/usr/bin/env python3
# encoding: utf-8
#
# Florian Roth

import sys
import json
import argparse

# Select the CSV fields you want to extract and show up in the output (file)
CSV_FIELDS = ['md5', 'file', 'score', 'created', 'modified', 'accessed']
# Modules to include
MODULES = ['filescan', 'archivescan']
# Levels to include
LEVEL = ['alert', 'warning', 'notice']
# Field values to prepend to each other (special handling of archive matches)
PREPEND = {
    'archive': 'file'
}

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='THOR JSON to CSV Converter')
    parser.add_argument('-i', help='JSON file produced by a THOR scan', metavar='input', default='')
    parser.add_argument('-o', help='Output file name of the CSV (default: output to command line only)', metavar='output', default='')
    parser.add_argument('--showheader', action='store_true', default=False, help='Show/print CSV header line')
    
    args = parser.parse_args()

    # No input file given, print help
    if not args.i:
        parser.print_help()
        sys.exit(1)

    # Output the header line
    if args.showheader:
        if args.o: 
            with open(args.o, 'w') as out_file:
                out_file.write("%s\n" % ",".join(CSV_FIELDS))
        else:
            print(",".join(CSV_FIELDS))

    # Open the JSON log
    with open(args.i) as json_file:
        # Read the lines from the file
        lines = json_file.readlines()
        # Process each line
        for line in lines:
            
            # Load each line as JSON object
            json_line = json.loads(line)

            # Skip all non-relevant modules 
            if 'module' in json_line:
                skip_line = True
                for module in MODULES:
                    if module == json_line['module'].lower():
                        skip_line = False 
                if skip_line:
                    continue
            else:
                continue

            # Skip all non-relevant modules 
            if 'level' in json_line:
                skip_line = True
                for level in LEVEL:
                    if level == json_line['level'].lower():
                        skip_line = False 
                if skip_line:
                    continue
            else:
                continue

            # Special: prepend fields to other fields (e.g. Archive scan matches)
            for pfield, field in PREPEND.items():
                if pfield in json_line and field in json_line:
                    json_line[field] = "%s|%s" % (json_line[pfield], json_line[field])
            
            # List of output values
            output_values = []
            # Loop over elements to extract from the JSON object
            for field in CSV_FIELDS:
                if field in json_line:
                    output_values.append(json_line[field])
                else:
                    output_values.append('-')
            
            # Output the CSV line
            if args.o:
                with open(args.o, "a+") as out_file:
                    out_file.write("%s\n" % ",".join(output_values))
            else: 
                print(",".join(output_values))
