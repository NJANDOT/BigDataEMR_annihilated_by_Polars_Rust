#!/bin/bash

python3 -m pip install --upgrade --quiet pip
python3 -m pip install --quiet boto3
python3 -m pip install --quiet pytest
python3 -m pip install --quiet numpy
python3 -m pip install --quiet polars s3fs adlfs gcsfs 
