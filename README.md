# Snoflake data ingestion

This project uses [Terraform](https://app.terraform.io/) for setting up the infrastructure.

Here is the workflow:
- Data files are uploaded to AWS Bucket (subfolders of biupload-raw-prd)
- Processing via lambda scripts which create JSON files in bucket subfolders of biupload-etl-prd
-

### Upload to AWS Bucket (subfolders of biupload-raw-prd)
Data has to be stored in the bucket biupload-raw-prd. Please take care of using the correct subfolder!

### Processing via lambda scripts
The lamdba scripts convert the data to JSON and add ingestion timestamp as well as filename to each dataset.

If the lambda script fails, a notification is sent by email. The processing log can be found in 
[Amazon Cloudwatch](https://eu-central-1.console.aws.amazon.com/cloudwatch/)


On import errors (no data in _staging), you have to check the copy_history of the _landing table.
```
select * from table(information_schema.copy_history(
    TABLE_NAME=>concat($tbl,'_landing'), 
    START_TIME=> DATEADD(hours, -24, CURRENT_TIMESTAMP())));
```