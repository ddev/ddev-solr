#ddev-generated

Copy third party Solr modules and libraries jar files here. To load and use them
within a collection, add this line to your collection's `solrconfig.xml`:
```xml
<lib dir="/opt/solr/modules/ddev/lib/" regex=".*\.jar" />
```
