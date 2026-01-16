#!/bin/bash

font_url=https://file.openfont.org/archive/b612mono.zip

mkdir -p assets
wget $font_url -O assets/font.zip --no-check-certificate
unzip assets/font.zip b612mono/B612Mono-Regular.ttf -d assets/
mv assets/b612mono/B612Mono-Regular.ttf assets/B612Mono-Regular.ttf
rm -rf assets/font.zip assets/b612mono
