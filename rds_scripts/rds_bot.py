import pymysql
import os
import json

file_path = os.path.join(os.path.dirname(os.getcwd()), 'TERRAFORMAWSPIPELINE\\schemas.json')
print(file_path)


# Open and read the JSON file
with open(file_path, 'r') as file:
    data = json.load(file)


for i in range(0,len(data)):
    if data[i]['folder'] == 'aebot':
        table_name = data[i]['folder']+'.'+data[i]['subfolder'] # Specify your table name
        columns_sql = []

        for column_name, column_type in data[i]['columns'].items():
            columns_sql.append(f"{column_name} {column_type}")

                # Join the column definitions with commas
            # columns_sql_str = ",\n    ".join(columns_sql)
                # Final CREATE TABLE SQL statement
            
        columns_sql.append("filename VARCHAR(255)")
        columns_sql.append("ingestion_ts TIMESTAMP_NTZ(9)")
        columns_sql_str = ",\n    ".join(columns_sql)
        create_table_sql = f"CREATE TABLE {table_name} (\n    {columns_sql_str}\n);"
        print (create_table_sql)


        
def lambda_handler(event, context):
    # Connect to the RDS instance
    connection = pymysql.connect(
        host='terraform-20240919124438328600000001.c368soioq85e.eu-west-2.rds.amazonaws.com:3306',
        user=#redacted,
        password=#redacted,
        database=#redacted
    )
    try:
       for i in range(0,len(data)):
          if data[i]['folder'] == 'aebot':
            table_name = data[i]['folder']+'.'+data[i]['subfolder'] # Specify your table name
            columns_sql = []

            for column_name, column_type in data[i]['columns'].items():
                columns_sql.append(f"{column_name} {column_type}")

# Final CREATE TABLE SQL statement
            
            columns_sql.append("filename VARCHAR(255)")
            columns_sql.append("ingestion_ts TIMESTAMP_NTZ(9)")
            columns_sql_str = ",\n    ".join(columns_sql)
            create_table_sql = f"CREATE TABLE {table_name} (\n    {columns_sql_str}\n);"
            print (create_table_sql)
            with connection.cursor() as cursor:
            # SQL to create a table
                
                cursor.execute(create_table_sql)
                connection.commit()
    finally:
        print('fail')
        connection.close()
