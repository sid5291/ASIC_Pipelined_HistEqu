A Highly pipelined histogram equalizer with minimum latency. 

Three main blocks 
	1. Histogram generater
	2. Equalizer (Uses Pipelined Div and Mul units)
	3. Output generator

Uses 3 SRAMS
	1. Input SRAM (Loaded with Image) RO
	2. Scratch SRAM R/W
	3. Output SRAM WO

Test is included for two images provided