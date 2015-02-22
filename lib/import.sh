ENVIRONMENT=$1

echo " "
echo "..: Cleaning Up :.."
echo " "

rm -r boundary_lines
rm -r postcodes

echo " "
echo "..: Setting Up Postgres DB :.."
echo " "

echo "Drop postcode_lookup_$ENVIRONMENT"
psql -c "drop database if exists postcode_lookup_$ENVIRONMENT"

echo "Create postcode_lookup_$ENVIRONMENT"
createdb postcode_lookup_$ENVIRONMENT

echo "Add postGIS extension"
psql -d postcode_lookup_$ENVIRONMENT -c "CREATE EXTENSION POSTGIS"
echo " "
echo "..: Downloading Files :.."
echo " "

wget -O boundary_lines.zip "http://download.ordnancesurvey.co.uk/open/BDLINE/201410/ESRL/bdline_essh_gb.zip?sr=b&st=2015-02-22T11:38:24Z&se=2015-02-25T11:38:24Z&si=opendata_policy&sig=EdhC2M5okDktOCywfwOjCLuCMN%2BuTrttG3Lhc2imgKU%3D"
wget -O postcodes.zip  "http://download.ordnancesurvey.co.uk/open/CODEPO/201502/CSV/codepo_gb.zip?sr=b&st=2015-02-22T11:38:24Z&se=2015-02-25T11:38:24Z&si=opendata_policy&sig=%2BVFuBcr0waH55bRDDFkuZsMr0oAMP649k9oy37PfO0w%3D"

unzip -d boundary_lines boundary_lines.zip
unzip -d postcodes postcodes.zip 

echo " "
echo "..: Importing Boundaries :.."
echo " "

echo "Import tables"
find boundary_lines/Data/ -name "*.shp" | xargs -I % -n1 shp2pgsql -s 27700:4326 -G -I % | psql -d postcode_lookup_$ENVIRONMENT

echo " "
echo "..: Importing Postcodes :.."
echo " "

# Wipe the postcodes tables
psql -d postcode_lookup_$ENVIRONMENT -c "drop table if exists postcodes;";
psql -d postcode_lookup_$ENVIRONMENT -c "drop table if exists postcodes_raw;";

# Create Postcodes tables
psql -d postcode_lookup_$ENVIRONMENT -c "create table postcodes_raw (
    postcode varchar(10) primary key,
    positional_quality_indicator int,
    eastings int,
    northings int,
    country_code varchar(10),
    nhs_regional_ha_code varchar(10),
    nhs_ha_code varchar(10),
    admin_country_code varchar(10),
    admin_district_code varchar(10),
    admin_ward_code varchar(10)
);";


for csv in postcodes/Data/CSV/*.csv; do
    echo "Importing $csv into postcodes_raw";
    psql -d postcode_lookup_$ENVIRONMENT -c "\copy postcodes_raw from $csv with CSV;";
done

echo "Converting postcode northings/eastings into geo coordinates";

# Convert the raw database into a better formatted one
psql -d postcode_lookup_$ENVIRONMENT -c "
SELECT
  postcode,
  ST_TRANSFORM(ST_GEOMFROMEWKT('SRID=27700;POINT(' || eastings || ' ' || northings || ')'), 4326)::GEOGRAPHY(Point, 4326) AS location,
  country_code,
  admin_country_code,
  admin_district_code,
  admin_ward_code
INTO
  postcodes
FROM
  postcodes_raw;";

# Add an index
psql -d postcode_lookup_$ENVIRONMENT -c "CREATE INDEX postcodes_geog_idx ON postcodes USING GIST(location);";
psql -d postcode_lookup_$ENVIRONMENT -c "CREATE INDEX postcodes_postcode_idx ON postcodes(postcode);";

# Remove spacing from postcode column
psql -d postcode_lookup_$ENVIRONMENT -c "UPDATE postcodes SET postcode = replace(postcode, ' ', '');";

# Drop the raw table
psql -d postcode_lookup_$ENVIRONMENT -c "DROP TABLE postcodes_raw;";

#echo "..: Creating SQL Dump :.."
#pg_dump --no-owner postcode_lookup_$ENVIRONMENT > ../db/map_data.sql
#
#echo "Drop postcode_lookup_$ENVIRONMENT"
#psql -c "drop database if exists postcode_lookup_$ENVIRONMENT"

echo "All done! 🍺"
