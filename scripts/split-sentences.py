import re
import sys

sentence_id_file = sys.argv[1]
max_length = 30

line_no = 0
with open(sentence_id_file, "w") as fsid:
	for line in sys.stdin:
		line = line.strip()
		if len(line.split()) <= max_length:
			print(line)
			print(line_no, file=fsid)
		else:
			sents = re.split("(?<=(?<!\d)[,.?!\r\n](?!\d)) +", line)
			for sent in sents:
				sent = sent.strip()
				print(sent)
				print(line_no, file=fsid)
		line_no += 1
