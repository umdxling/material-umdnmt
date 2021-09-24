#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
Created on Tue Feb 25 14:04:31 2020

@author: Richburg
"""

import sentencepiece as spm
import argparse
import io

#Optionally trains and applies segmentation to data using SentencePiece

parser = argparse.ArgumentParser()
parser.add_argument('--in_file')
parser.add_argument('--seg_model', help="an already trained SentencePiece segmentation model")
parser.add_argument('--transform', help="enc(ode) or dec(ode); segment or unsegment data")
args = parser.parse_args()

def main():
    with open(args.in_file, 'r', encoding="utf-8") as f_in:
 
        
        #Applying SentencePiece segmentation to data
        data = f_in.read().splitlines()
        sp = spm.SentencePieceProcessor()
        sp.Load(args.seg_model)
        
        new_lines = []
        if args.transform == 'enc':
            for line in data:
                spm_line = sp.EncodeAsPieces(line)
                new_lines.append(spm_line)
        else:
            for line in data:
                spm_line = sp.DecodePieces(line.split())
                new_lines.append(spm_line)
            
        for line in new_lines:
            if args.transform == 'enc':
                print(' '.join(line))
            else:
                print(line)
            
if __name__ == "__main__":
    main()
