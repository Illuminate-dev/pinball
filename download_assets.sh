#!/bin/bash

mkdir -p assets
wget https://file.openfont.org/archive/42dotsans.zip -O assets/42dotsans.zip
unzip assets/42dotsans.zip 42dotsans/42dotSans.ttf -d assets/
mv assets/42dotsans/42dotSans.ttf assets/42dotSans.ttf
rm -rf assets/42dotsans.zip assets/42dotsans
