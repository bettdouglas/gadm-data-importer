#!/bin/bash

# Set up environment variables
export PGHOST=${POSTGRES_HOST:-localhost}
export PGPORT=${POSTGRES_PORT:-5432}
export PGDATABASE=${POSTGRES_DB:-drift_test}
export PGUSER=${POSTGRES_USER:-doug}
export PGPASSWORD=${POSTGRES_PASSWORD:-doug123}

# Construct the DB_CONN_STRING
DB_CONN_STRING="postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE"

# Set other variables
VERSION="gadm41"
BASE_URL="https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/"
# FILENAMES=("gadm41_KEN.gpkg" "gadm41_RWA.gpkg" "gadm41_TZA.gpkg" "gadm41_UGA.gpkg")
FILENAMES=("gadm41_UGA.gpkg")

# Function to download file if not exists
download_if_not_exists() {
    local filename=$1
    if [ ! -f "$filename" ]; then
        echo "Downloading $filename"
        wget "$BASE_URL$filename"
    fi
}

# Function to simplify GeoJSON
simplify_geojson() {
    local input_file=$1
    local percentage=$2
    local output_file="simplified_${input_file}"
    mapshaper "$input_file" -simplify "$percentage" visvalingam -o format=geojson "$output_file"
    echo "$output_file"
}

# Main processing loop
for filename in "${FILENAMES[@]}"; do
    echo "Processing file: $filename"
    download_if_not_exists "$filename"

    # Process each layer
    # layers=$(ogrinfo -so "$filename" | grep -E '^\s*[0-9]+:' | cut -d: -f2)
    # layers=$(ogrinfo -so -q "$filename" | grep "1: " | cut -d' ' -f2- | tr -d ',')
    layers=$(ogrinfo -so -q "$filename" | grep -E '^[0-9]+:' | sed -E 's/^[0-9]+: ([^(]+) \(.+\)$/\1/' | tr -d ' ')

    for layer in $layers; do
        level=$(echo $layer | sed -E 's/ADM_ADM_(.+)/\1/')

        echo "Processing layer: $layer with level: $level"
        # Step 1: Convert from GPKG to PostGIS
        if [ "$level" = "0" ]; then
            sql_import="SELECT GID_0 AS id, COUNTRY AS name, 'Country' AS region_type, geom FROM \"$layer\""
        else
            sql_import="SELECT GID_$level AS id, NAME_$level AS name, TYPE_$level AS region_type, geom FROM \"$layer\""
        fi

        ogr2ogr -f "PostgreSQL" PG:"$DB_CONN_STRING" "$filename" \
            -nln "regions_temp" -nlt PROMOTE_TO_MULTI \
            -lco GEOMETRY_NAME=geometry -lco FID=id -lco PRECISION=NO \
            -sql "$sql_import" \
            -append
        
        break;

        # Step 2: Export to GeoJSON for simplification
        if [ "$level" = "0" ]; then
            sql_export="SELECT GID_0 AS id, geom FROM \"$layer\""
        else
            sql_export="SELECT GID_$level AS id, geom FROM \"$layer\""
        fi
        simplified_file_name="${filename%.*}_${layer}.geojson"
        ogr2ogr -f "GeoJSON" "$simplified_file_name" "$filename" -sql "$sql_export"

        # # Step 3: Simplify using mapshaper
        # echo "Simplifying layer: $layer"
        simplified_file_name=$(simplify_geojson "$simplified_file_name" "10%")
        echo "Simplified file: $simplified_file_name"

        echo "Importing simplified geometry to PostGIS"
        # sql_import="SELECT id, geometry AS simplified_geometry FROM ${simplified_file_name}"
        # sql_import = "SELECT id, geometry AS simplified_geometry FROM '$(basename "${simplified_file_name%.*}")'"
        # ogr2ogr -f "PostgreSQL" PG:"$DB_CONN_STRING" \
        #     -nln "regions" -nlt PROMOTE_TO_MULTI \
        #     -lco GEOMETRY_NAME=simplified_geometry -lco FID=id -lco PRECISION=NO \
        #      -sql "$sql_import" -update -append "${simplified_file_name}"
        ogr2ogr -f "PostgreSQL" PG:"$DB_CONN_STRING" "${simplified_file_name}" \
            -nln "regions" -nlt PROMOTE_TO_MULTI \
            -lco GEOMETRY_NAME=simplified_geometry -lco FID=id -lco PRECISION=NO \
            -sql "$sql_import" \
            -update
        

        echo "Imported layer: $layer"

        # # Simplify geometry
        # ogr2ogr -f "GeoJSON" "${filename%.*}_${layer}.geojson" "$filename" "$layer"
        # simplified_file=$(simplify_geojson "${filename%.*}_${layer}.geojson" "10%")

        # # Import simplified geometry
        # ogr2ogr -f "PostgreSQL" PG:"$DB_CONN_STRING" "$simplified_file" \
        #     -nln "regions" -update -append -sql "SELECT id, ST_SimplifyPreserveTopology(geometry, 0.01) AS simplified_geometry FROM '${simplified_file%.*}'"

        # # Clean up temporary files
        # rm "${filename%.*}_${layer}.geojson" "$simplified_file"
    done

    # Optional: Delete original file after import
    # rm "$filename"
done

echo "Finished importing all datasets"

# Update simplified geometries in the database
# psql "$DB_CONN_STRING" -c "UPDATE regions SET simplified_geometry = ST_SimplifyPreserveTopology(geometry, 0.01) WHERE simplified_geometry IS NULL;"

echo "Finished simplifying geometries"