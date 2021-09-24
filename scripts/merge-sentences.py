import sys
from collections import defaultdict

sentence_id_file = sys.argv[1]

sids = []
with open(sentence_id_file, "r") as f:
	for line in f:
		sid = int(line.strip())
		sids.append(sid)

line_no = 0
output_sents = defaultdict(list)
for line in sys.stdin:
	sid = sids[line_no]
	line_no += 1
	output_sents[sid].append(line.strip())
	line = line.strip()

output_sents = sorted(list(output_sents.items()))
for sid, sents in output_sents:
	print(" ".join(sents))
