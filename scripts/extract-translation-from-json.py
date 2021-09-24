import json
import sys

if __name__ == '__main__':
    for line in sys.stdin:
        translation_data = json.loads(line)
        if translation_data:
            print(translation_data['translation'])
        else:
            print()
