FROM --platform=$TARGETPLATFORM solr:8

EXPOSE 8983

ARG CKAN_BRANCH="dev-v2.10"

ENV SOLR_INSTALL="/opt/solr"
ENV SOLR_CONFIG_DIR="$SOLR_INSTALL/server/solr/configsets"
ENV SOLR_SCHEMA_FILE="$SOLR_CONFIG_DIR/ckan/conf/managed-schema"

ARG JTS_VERSION="1.19.0"
ARG JTS_JAR_FILE="$SOLR_INSTALL/server/solr-webapp/webapp/WEB-INF/lib/jts-core-$JTS_VERSION.jar"

USER root

# Create a CKAN configset by copying the default one
RUN cp -R $SOLR_CONFIG_DIR/_default $SOLR_CONFIG_DIR/ckan

# Update the schema
ADD https://raw.githubusercontent.com/ckan/ckan/$CKAN_BRANCH/ckan/config/solr/schema.xml $SOLR_SCHEMA_FILE

# Install JTS JAR file
ADD https://repo1.maven.org/maven2/org/locationtech/jts/jts-core/$JTS_VERSION/jts-core-$JTS_VERSION.jar \
    $JTS_JAR_FILE
RUN chmod 644 $JTS_JAR_FILE

# Add the spatial field type definitions and fields

## RPT
ENV SOLR_RPT_FIELD_DEFINITION '<fieldType name="location_rpt"   class="solr.SpatialRecursivePrefixTreeFieldType" \
    spatialContextFactory="JTS"     \
    autoIndex="true"                \
    validationRule="repairBuffer0"  \
    distErrPct="0.025"              \
    maxDistErr="0.001"              \
    distanceUnits="kilometers" />'

ENV SOLR_RPT_FIELD='<field name="spatial_geom" type="location_rpt" indexed="true" multiValued="true" />'

RUN sed -i "/<types>/a $SOLR_RPT_FIELD_DEFINITION" $SOLR_SCHEMA_FILE
RUN sed -i "/<fields>/a $SOLR_RPT_FIELD" $SOLR_SCHEMA_FILE

## BBox
ENV SOLR_BBOX_FIELDS='<field name="bbox_area" type="float" indexed="true" stored="true" /> \
    <field name="maxx" type="float" indexed="true" stored="true" /> \
    <field name="maxy" type="float" indexed="true" stored="true" /> \
    <field name="minx" type="float" indexed="true" stored="true" /> \
    <field name="miny" type="float" indexed="true" stored="true" />'

RUN sed -i "/<fields>/a $SOLR_BBOX_FIELDS" $SOLR_SCHEMA_FILE
RUN chmod 644 $SOLR_SCHEMA_FILE

USER solr

CMD ["sh", "-c", "solr-precreate ckan $SOLR_CONFIG_DIR/ckan"]

# Enviroment
ENV SOLR_CORE=ckan

# Giving ownership to Solr
USER root

# Add harvest field to schema
RUN sed -z 's/<field name="urls" type="text" indexed="true" stored="false" multiValued="true"\/>/<field name="urls" type="text" indexed="true" stored="false" multiValued="true"\/>\n    <field name="harvest" type="text" indexed="true" stored="true" multiValued="true"\/>/' -i $SOLR_SCHEMA_FILE

# Set to restricted User
USER $SOLR_USER:$SOLR_USER
