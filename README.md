# This imports GADM data into Postgis database.

We download the data from GADM.org as a Geopackage and read the layers into the database. 
The result of the data_importer is having all the layers unified in one table with the columns 
```python
["id", "name", "region_type", "geometry"]
```
In the database, the geometry attribute is used when we want to know where some specific issue lies. i.e Which County, Constituency, Ward, etc. 

# Rendering
When rendering the regions on the client, we want the data being sent to be as small as possible and not huge that the client will have a problem rendering it. 
For this reason, we have another Nullable column in the regions table which is called `simplified_geometry` which will contain the simplified version of the geometry that the client can render easily. 

## QGIS and PostGIS Simplification

