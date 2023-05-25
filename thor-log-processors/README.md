**You can now use [thor-util's logconvert](https://thor-util-manual.nextron-systems.com/en/latest/usage/log-conversion.html)
to convert logs from one format to another.**

# THOR Log Processor Scripts

Scripts that help you process the different THOR output files

## thor-json-to-csv.py

Converts a JSON output file into a CSV with a custom fields.

### Requirements

- Start THOR with the flag `--json` to create a `.json` file with all log entries
- Python 3

### Usage

```help
usage: thor-json-to-csv.py [-h] [-i input] [-o output] [--showheader]

THOR JSON to CSV Converter

optional arguments:
  -h, --help    show this help message and exit
  -i input      JSON file produced by a THOR scan
  -o output     Output file name of the CSV (default: output to command line only)
  --showheader  Show/print CSV header line
```

### Examples

Write CSV output to command line and print a header with all fields

```bash
python thor-json-to-csv.py -i prometheus.local_thor_2021-02-18_1804.json --showheader
```

Write CSV output to a file named `my_custom.csv`

```bash
python thor-json-to-csv.py -i prometheus.local_thor_2021-02-18_1804.json -o my_custom.csv
```

### Adjust Field Values

The Python script contains a header section in which you can define the values that you'd like to see in your CSV file.

```python
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
```
