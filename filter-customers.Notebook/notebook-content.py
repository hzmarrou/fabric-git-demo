# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "6caea328-2cd5-404a-95ef-a0a0b2155c2a",
# META       "default_lakehouse_name": "ToyLakehouse",
# META       "default_lakehouse_workspace_id": "8580cff2-a226-408e-a2bf-e26ba6f2a4b2",
# META       "known_lakehouses": [
# META         {
# META           "id": "6caea328-2cd5-404a-95ef-a0a0b2155c2a"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Welcome to your new notebook
# Type here in the cell editor to add code!
from pyspark.sql import functions as F

input_path = "Files/customers.csv"
output_table = "filtered_customers"

customers = (
    spark.read
    .option("header", True)
    .option("inferSchema", True)
    .csv(input_path)
)

france_customers = customers.filter(F.col("country") == "France")

(
    france_customers.write
    .mode("overwrite")
    .format("delta")
    .saveAsTable(output_table)
)

display(spark.table(output_table))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
