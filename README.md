[![tests](https://github.com/mkalkbrenner/ddev-solr/actions/workflows/tests.yml/badge.svg)](https://github.com/mkalkbrenner/ddev-solr/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2024.svg)

# ddev-solr <!-- omit in toc -->

- [What is ddev-solr?](#what-is-ddev-solr)
- [Solarium](#solarium)
- [Drupal and Search API Solr](#drupal-and-search-api-solr)
    - [Installation steps](#installation-steps)

## What is ddev-solr?

ddev-solr provides Solr (Cloud) using a single Solr node, which is sufficient
for local development requirements.

Solr Cloud provides a lot of APIs to manage your collections, cores, schemas
etc. Some of these APIs require a so-called "trusted" context. Solr therefore
supports different technologies for authentication and authorization. The
easiest one to configure is "Basic Authentication". This DDEV service comes with
a simple pre-configured `security.json` to provide such a trusted context based
on basic authentication. It creates a single administrative account having full
access rights:
* user: `solr`
* password: `SolrRocks`

Once up and running you can access Solr's UI within your browser by opening
`https://<projectname>.ddev.site:8983`. For example, if the project is named
"myproject" the hostname will be `https://myproject.ddev.site:8983`. To access
the Solr container from the web container use `https://ddev-<project>-solr:8983`.

Solr Cloud depends on Zookeeper to share configurations between the Solr nodes.
Therefore, this service starts a single Zookeeper server on port 2181, too.

## Solarium

[Solarium](https://github.com/solariumphp/solarium) is the leading Solr
integration library for PHP. It is used by the modules and integrations of many
PHP frameworks and CMS like Drupal, Typo3, Wordpress, Symfony, Laravel, ...
If you build your own PHP application and want to use Solarium directly, here is
an example of how to configure the connection in DDEV.

```php
use Solarium\Core\Client\Adapter\Curl;
use Symfony\Component\EventDispatcher\EventDispatcher;

$adapter = new Curl();
$eventDispatcher = new EventDispatcher();
$config = [
    'endpoint' => [
        'localhost' => [
            // Replace <project> by your project's name:
            'host' => 'ddev-<project>-solr',
            'port' => 8983,
            'path' => '/',
            // Use your collection name here:
            'collection' => 'techproducts',
            'username' => 'solr',
            'password' => 'SolrRocks',
        )
    )
);

$client = new Solarium\Client($adapter, $eventDispatcher, $config);
```

## Drupal and Search API Solr

For Drupal and Search API Solr you need to configure a Search API server using
Solr as backend and `Solr Cloud with Basic Auth` as its connector. As mentioned
above, username "solr" and password "SolrRocks" are the pre-configured
credentials for Basic Authentication in `.ddev/solr/security.json`.

Solr requires a Drupal-specific configset for any collection that should be used
to index Drupal's content. (In Solr Cloud "collections" are the equivalent to
"cores" in classic Solr installations. Actually, in a big Solr Cloud installation
a collection might consist of multiple cores across all Solr Cloud nodes.)

Starting from Search API Solr module version 4.2.1 you don't need to deal with
configsets manually anymore. Just enable the `search_api_solr_admin` sub-module
which is part of Search API Solr. Now you create or update your "collections" at
any time by clicking the "Upload Configset" button on the Search API server
details page (see instAllation steps below), or automate things using
```
ddev drush --numShards=1 search-api-solr:upload-configset SEARCH_API_SERVER_ID
```

Note: `SEARCH_API_SERVER_ID` is the machine name of your Search API server.
The number of "shards" should always be "1" as this local installation only
runs a single Solr node.

### Installation steps

1. Enable the `search_api_solr_admin` module. (This sub-module is included in Search API Solr >= 4.2.1)
2. Create a search server using the Solr backend and select `Solr Cloud with Basic Auth` as connector:
   * HTTP protocol: `http`
   * Solr node: `ddev-<project>-solr` (Replace <project> by your project's name.)
   * Solr port: `8983`
   * Solr path: `/`
   * Default Solr collection: `techproducts` (You can define any name here. The collection will be created automatically.)
   * Username: `solr`
   * Password: `SolrRocks`
3. Press the `Upload Configset` button on the server's view and check the "Upload (and overwrite) configset" checkbox.
4. Set the number of shards to `1.
5. Press `Upload`.


**Contributed and maintained by [@mkalkbrenner](https://github.com/mkalkbrenner)**
