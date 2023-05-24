import wget
import fiona
import pandas as pd
import geopandas as gpd
from config import DB_CONN_STRING,DELETE_ON_IMPORT
from datetime import datetime
from fiona.errors import DriverError
import os
import glog


version = "gadm41"
base_url = "https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/"

filenames = [
     "gadm41_KEN.gpkg",
     "gadm41_RWA.gpkg",
     "gadm41_TZA.gpkg",
     "gadm41_UGA.gpkg",
]
from sqlalchemy import create_engine
db_engine = create_engine(DB_CONN_STRING)
print(db_engine)

def import_to_postgis(gdf,filename):
    glog.info(f"importing {filename} to {db_engine}")

    try:
        gdf.to_postgis(
            "regions",
            if_exists="append",
            con=db_engine,
            index_label="id",
            chunksize=100,
        )
        glog.info(f"Finished importing {filename} data")
    except Exception as e:
        glog.warn(e)
        pass


for filename in filenames:
    glog.info(os.path.exists(filename))

for filename in filenames:
    gdf_layers = []
    glog.info(f"Processing {filename}")
    # try:
    #     layers = fiona.listlayers(filename)
    # except DriverError:
    if not os.path.exists(filename):
        glog.info(f"Downloading {filename}")
        url = base_url + filename
        filename = wget.download(url)
    glog.info(f"Processing {filename} country level")
    layers = fiona.listlayers(filename)
    lev0 = gpd.read_file(filename,layer=layers[0]).rename(columns={"GID_0":"id","COUNTRY":"name"})
    lev0["region_type"] = "Country"
    gdf_layers.append(lev0)

    layers = layers[1:]

    for i in range(len(layers)):
        layer = layers[i]
        level = i + 1
        glog.info(f"Processing {filename} {layer} level")
        lev = gpd.read_file(filename,layer=layer)
        lev = lev.rename(columns={f"NAME_{level}": "name", f"GID_{level}": "id", f"TYPE_{level}": "region_type"})[["id", "name", "region_type", "geometry"]]
        gdf_layers.append(lev)
    
    merged_df = pd.concat(gdf_layers)
    merged_df["created_at"] = datetime.now()
    gdf = gpd.GeoDataFrame(merged_df)
    import_to_postgis(gdf,filename)
    if DELETE_ON_IMPORT:
        os.remove(filename)


glog.info("Finished importing all datasets")
with db_engine.connect() as conn:
    from sqlalchemy import text

    conn.execute(text('UPDATE regions set simplified_geometry = ST_SimplifyPreserveTopology(geometry,0.01)'))

glog.info("Finished simplifying geometries")


# glog.info(merged_df.shape)
# glog.info(merged_df.head())
