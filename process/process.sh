#!/bin/bash



source /burg/opt/anaconda3-2020.11/anaconda3/bin/activate ginsnburg_env

python -c'import func_process; \
func_process.flt_process(6048,
"/burg/abernathey/users/csj2114/agulhas-offline/time_1")'
