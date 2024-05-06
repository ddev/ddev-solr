[![tests](https://github.com/ddev/ddev-solr/actions/workflows/tests.yml/badge.svg)](https://github.com/ddev/ddev-solr/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2024.svg)

# ddev-solr <!-- omit in toc -->

- [What is ddev-solr?](#what-is-ddev-solr)
- [Getting started](#getting-started)
- [Create a collection](#create-a-collection)
- [Solr command line client](#solr-command-line-client)
- [Add third party Solr modules and libraries](#add-third-party-solr-modules-and-libraries)
- [Solarium](#solarium-php-client)
- [Drupal and Search API Solr](#drupal-and-search-api-solr)
    - [Installation steps](#installation-steps)
- [What's the difference between this and ddev-drupal9-solr](#whats-the-difference-between-this-and-ddev-drupal9-solr)

## What is ddev-solr?

ddev-solr provides Solr (Cloud) using a single Solr node, which is sufficient
for local development requirements.

Note: existing applications that have been developed with Solr Standalone instead of
Cloud should still work with Cloud. They connect to a __collection__ instead a
__core__.

Solr Cloud provides a lot of APIs to manage your collections, cores, schemas
etc. Some of these APIs require a so-called "trusted" context. Solr therefore
supports different technologies for authentication and authorization. The
easiest one to configure is "Basic Authentication". This DDEV service comes with
a simple pre-configured `security.json` to provide such a trusted context based
on basic authentication. It creates a single administrative account having full
access rights:

- user: `solr`
- password: `SolrRocks`

## Getting started

1. Install the addon

    ```shell
    ddev get ddev/ddev-solr
    ```

1. Restart DDEV to start the addon.

   ```shell
   ddev restart
   ```

Once up and running, access Solr's admin UI within your browser by opening
`http://<projectname>.ddev.site:8983`. For example, if the project is named
"myproject" the hostname will be `http://myproject.ddev.site:8983`.

The admin UI is protected by basic authentication. The preconfigured admin
account in `security.json` is user `solr` using the password `SolrRocks`.

To access the Solr container from DDEV's web container, use  `http://solr:8983`.

## Create a collection

It is recommended to use Solr's API to manage your collections (and cores).
You could use the [Solr command line client](#solr-command-line-client), or the
Solr API via curl or any http client.
Or use Solr's admin UI.

Creating collections require that the configset to be used by this collection
has been uploaded within a "trusted context". This is ensured if you use the
admin UI with the predefined admin account `solr` or if you use the solr command
line client `ddev solr-zk`. If you use any other http client and the API, ensure
that you use basic authentocation with the prconfigured admin account
`solr:SolrRocks`.

The PHP solarium library provides all required methods as well.
Some frameworks like Drupal provide a full integration to manage your Solr
collections within the framework itself.

For backward compatibility to older ddev Solr integrations and legacy
applications that just provide a Solr configset (sometimes simply called
"Solr config"), there's a ddev specific convenient method, too:
Simply copy a configset directory to `.ddev/solr/configsets/` and restart ddev.
That configset will automatically be uploaded (or updated) to Solr using a
trusted context and a corresponding collection with the same name will be
created if it doesn't exist already.

__Note:__ Solr Cloud could be run on multiple nodes. Any node has it's own core
that holds your data. A collection is a set of cores distributed over several
nodes. If you read some old documentation or the usage instruction of an old PHP
application, it might talk about a "core". In that case you could simply replace
the word "core" with "collection". Connecting to a collection on Solr Cloud
behaves like connecting to a core on "Solr standalone".
Some documentations or applications talk about an "index". That's also just a
synonym for a collection.

__Note:__ For maximum compatibility with older applications that don't support
basic authentication when connecting Solr, reading/searching from and updating
documents within an "index" (collection) doesn't require basic authentication
using this ddev integration. For sure you can use basic authentication but it is
not a must. Just the admin UI requires it to ensure the "trusted context".

## Solr command line client

The `solr` command line client is available as ddev command:
```sh
ddev solr
```

The `zk` command is usually executed as `solr zk -z <HOST>:<PORT>`. To ease its
usage a convenient ddev command exists that uses preconfigured connection
settings. So the `-z` option can be omitted:
```sh
ddev solr-zk
```

Both commands are preconfigured to connect as user `solr` which is the admin
account.

## Add third party Solr modules and libraries

Copy third party Solr modules and libraries jar files into `.ddev/solr/lib/`.
To load and use them within a collection, add this line to your
collection's `solrconfig.xml`:
```xml
<lib dir="/opt/solr/modules/ddev/lib/" regex=".*\.jar" />
```

## Solarium PHP client

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
            'host' => 'solr',
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
"cores" in classic Solr installations. Actually, in a big Solr Cloud
installation a collection might consist of multiple cores across all Solr Cloud
nodes.)

Starting from Search API Solr module version 4.2.1 you don't need to deal with
configsets manually anymore. Just enable the `search_api_solr_admin` sub-module
which is part of Search API Solr. Now you create or update your "collections" at
any time by clicking the "Upload Configset" button on the Search API server
details page (see installation steps below), or use `drush` to do this with

```
ddev drush --numShards=1 search-api-solr:upload-configset SEARCH_API_SERVER_ID
```

Note: `SEARCH_API_SERVER_ID` is the machine name of your Search API server.
The number of "shards" should always be "1" as this local installation only
runs a single Solr node.

### Installation steps

1. Enable the `search_api_solr_admin` module. (This sub-module is included in Search API Solr >= 4.2.1)
2. Create a search server using the Solr backend and select `Solr Cloud with Basic Auth` as connector:
   - HTTP protocol: `http`
   - Solr node: `solr`
   - Solr port: `8983`
   - Solr path: `/`
   - Default Solr collection: `techproducts` (You can define any name here. The collection will be created automatically.)
   - Username: `solr`
   - Password: `SolrRocks`
3. On the server's "view" page click the `Upload Configset` button and check the "Upload (and overwrite) configset" checkbox.
    ![images](images/upload-configset.png)
4. Set the number of shards to `1`.
5. Press `Upload`.

## What's the difference between this and ddev-drupal9-solr

ddev-drupal9-solr provides Solr running in a the "classic standalone" mode using a single core. ddev-solr runs Solr in
the modern "cloud" mode (even if it just starts a single Solr node).

Running in cloud mode has several advantages. The biggest one from Drupal's perspective is that every time an update of
the search_api_solr module asks you to generate and deploy an updated configset, it is just a click in the UI or a
single drush command instead of downloading and extracting a zip, copying the files to the ddev folder and restarting
ddev. This is possible because of the Configset API Solr Cloud provides.

But there are also more and more APIs and features, which are only available in combination with Solr Cloud and which
are supported by solarium and search_api_solr:
   - [Streaming Expressions](https://solr.apache.org/guide/solr/latest/query-guide/streaming-expressions.html)
   - Collection API
   - Updating files like stop words, compound words, protected words, NLP models, LTR models, ... on the the fly using
     APIs
   - ...

Another important difference of ddev-solr compared to ddev-drupal9-solr is, that ddev-solr configures Solr to be able to
handle NLP models. So DDEV could be used with [search_api_solr_nlp](https://www.drupal.org/project/search_api_solr_nlp).

ddev-solr supports third party Solr plugins/modules/libraries.

**Contributed and maintained by [@mkalkbrenner](https://github.com/mkalkbrenner)**
