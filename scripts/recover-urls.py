import json
import sys

replace_table_file = sys.argv[1]

replace_tables = []
with open(replace_table_file, "r") as f:
	for line in f:
		replace_tables.append(json.loads(line))

line_no = 0
for line in sys.stdin:
	line = line.strip()
	replace_table = replace_tables[line_no]
	for item in replace_table:
		url = item["url"]
		tag = item["tag"]
		line = line.replace(tag, url, 1)
	line_no += 1
	print(line)
