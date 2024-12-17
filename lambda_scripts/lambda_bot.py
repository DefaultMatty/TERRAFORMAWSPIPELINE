import boto3
import os
import logging
import awswrangler as wr
from io import BytesIO, StringIO
import csv
import pandas as pd
import datetime 
from contextlib import redirect_stderr
from urllib import parse
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SRC_BKT = "#redacted-upload-raw-prd"

s3 = boto3.resource('s3')

schema_file_path = os.path.join(os.path.dirname(os.getcwd()), 'TERRAFORMAWSPIPELINE\\schemas.json')
print(schema_file_path)


# Open and read the JSON file
with open(schema_file_path, 'r') as file:
    schema_data = json.load(file)

def lambda_handler(event, context):
    status = {"Status": 200}
    try:
         # Filename for the uploaded file in the raw bucket
        filename = parse.unquote_plus(event['Records'][0]['s3']['object']['key'])
        
        ###Each Chunk has the same timestamp for SQL processing
        time = datetime.datetime.now()

        logger.info(f"New file uploaded to the source bucket: {filename}")
        if os.path.splitext(filename)[1].lower() != '.csv':
            msg = "Provided file is not the correct extension"
            logger.error(msg)
            raise ValueError(msg)
             
        # Load into a DataFrame (skip the first rows which are a summary table)
        logger.info("Loading dataframes...")
        
        f = StringIO()
        with redirect_stderr(f):
            for i, df in enumerate(wr.s3.read_csv(f"s3://{SRC_BKT}/{filename}", delimiter=",", encoding="latin-1", chunksize=50_000, on_bad_lines="warn")):
                logger.info(f'Loading chunk {i}')
                logger.info(f'Loaded DataFrame columns: {len(df.columns)}')
                logger.info(f'Loaded DataFrame rows: {df.shape[0]}')

                data = set(df.iloc[:,1].to_list())
                 
                for i in range(0,len(schema_data)):
                    if schema_data[i]['folder'] == 'aebot':
                        if schema_data[i]['subfolder'] == filename:
                            columns_sql = []
                            for column_name, column_type in data[0]['columns'].items():
                                columns_sql.append(f"{column_name}")
                            df.columns = columns_sql

                #time = datetime.datetime.now()

                # Add filename and ingestion time to dataframe
                logger.info(f'Adding Filename to dataframe: '+filename.split("/")[-1])
                logger.info(f'Adding Chunk {i}')

                df["filename"] = filename.split("/")[-1]
                df["ingestion_ts"] = time

                # Write to a json
                logger.info('Writing file to JSON.')
                new_file_key = filename.lower().replace('.csv', f'-{i}-{time.strftime("%d-%m-%y--%H-%M-%S")}.json')
                new_file_key = new_file_key.split("/")[-1]
                
                path="s3://#redacted-upload-etl-prd/data/aebot/"

                wr.s3.to_json(df=df, index=False, path=path + new_file_key, orient='records', lines=True, date_unit='s')
            
        if f.getvalue():
            logger.warn("Writing warn messages to s3://#redacted-upload-error-prd")
            bad_lines = f.getvalue()
            s3.Bucket("#redacted-upload-error-prd")\
                .Object("data/aebot/" + new_file_key.replace(".json", ".log"))\
                .put(Body=bad_lines)
            
    except Exception as e:
        status = {"Status": 400, "Message": str(e)}
        logger.info(f"Writing {filename} to #redacted-upload-error-prd")
        s3.Object("#redacted-upload-error-prd", filename).copy_from(f"{SRC_BKT}/{filename}")
    finally:
        s3.Object(SRC_BKT, filename).delete()
        if status["Status"] == 200:
            logger.info(f"Successfully moved file to {path}{new_file_key}")
        else:
            logger.error(f"Error raised: {status['Message']}")
            raise Exception(status['Message'])
     