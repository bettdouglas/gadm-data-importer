import wget
import fiona
import pandas as pd
import geopandas as gpd
from config import DB_CONN_STRING
from datetime import datetime
from fiona.errors import DriverError
import os

version = "gadm41"
base_url = "https://geodata.ucdavis.edu/gadm/gadm01/gpkg/"

filenames = [
     "gadm41_KEN.gpkg",
     "gadm41_RWA.gpkg",
     "gadm41_TZA.gpkg",
     "gadm41_UGA.gpkg",
]
gdf_layers = []

for filename in filenames:
    print(f"Reading {filename}")
    try:
        layers = fiona.listlayers(filename)
    except DriverError:
        url = base_url + filename
        filename = wget.download(url)
        layers = fiona.listlayers(filename)
    lev0 = gpd.read_file(filename,layer=layers[0]).rename(columns={"GID_0":"id","COUNTRY":"name"})
    lev0["region_type"] = "Country"
    gdf_layers.append(lev0)

    layers = layers[1:]

    for i in range(len(layers)):
        layer = layers[i]
        level = i + 1
        lev = gpd.read_file(filename,layer=layer)
        lev = lev.rename(columns={f"NAME_{level}": "name", f"GID_{level}": "id", f"TYPE_{level}": "region_type"})[["id", "name", "region_type", "geometry"]]
        gdf_layers.append(lev)

    os.remove(filename)

merged_df = pd.concat(gdf_layers)
merged_df["created_at"] = datetime.now()

print(set(merged_df['region_type']))

print(merged_df[merged_df["id"].isna()])
print(merged_df[merged_df["name"].isna()])
print(merged_df[merged_df["region_type"].isna()])
print(merged_df[merged_df["geometry"].isna()])

# print(merged_df.head())

gdf = gpd.GeoDataFrame(merged_df)

# print(gdf.crs)

from sqlalchemy import create_engine

gdf.to_postgis(
    "regions",
    if_exists="append",
    con=create_engine(DB_CONN_STRING),
    index_label="id",
    chunksize=100,
)





# print(merged_df.shape)
# print(merged_df.head())
