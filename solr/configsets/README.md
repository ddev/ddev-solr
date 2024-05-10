#ddev-generated

It is recommended to use Solr's API to manage your collections (and cores).
For example the PHP solarium library provides all required methods.
Some frameworks like Drupal provide a full integration to manage your Solr collections within the framework itself.

But for backward compatibility to older ddev Solr integrations and legacy applications that just provide a Solr
configset (sometimes simply called "Solr config"), this folder exists.

Simply copy a configset directory here and restart ddev. The configset will automatically be uploaded (or updated) to
Solr and a corresponding collection with the same name will be created if it doesn't exist already.
