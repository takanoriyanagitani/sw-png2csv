#!/bin/sh

input=~/Downloads/PNG_transparency_demonstration_1.png

export ENV_I_PNG_FILENAME="${input}"

file "${ENV_I_PNG_FILENAME}"

echo number of csv lines: $( ./PngToCsv | wc -l )

echo
printf 'number of csv columns: '
./PngToCsv |
	tail -1 |
	sed -e 's/,$//' |
	awk -F, '{print NF / 4}'
